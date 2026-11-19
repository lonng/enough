import AppKit
import ApplicationServices
import Security

public final class PermissionEngine {
    public enum State: String { case running = "On", paused = "Paused", needsAccess = "Needs Accessibility", sleeping = "Session inactive" }
    public var onState: ((State) -> Void)?
    public var onEvent: ((ApprovalEvent) -> Void)?
    /// Used by the test harness. The app leaves this nil to handle all requesters.
    public var requesterPrefix: String?
    public var observeOnly = false
    /// Keep watching and clicking while only the screen is locked (the session stays active).
    /// System sleep and other users' sessions always suspend the observer. Set on the main thread.
    public var workWhileLocked = false

    private let queue = DispatchQueue(label: "com.adore.enough.observer", qos: .utility)
    private let hostID = "com.apple.UserNotificationCenter"
    private var observers: [pid_t: AXObserver] = [:]
    private var pending: [pid_t: DispatchWorkItem] = [:]
    private var handled: [WindowID: String] = [:]
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var wanted = true
    private var inactive = false
    private var epoch = 0
    private var lastState: State?
    private let intentLock = NSLock()
    private var requestedEnabled = false
    private var requestedInactive = false
    private var requestedPolicy = PermissionPolicy()

    private struct WindowID: Hashable { let pid: pid_t; let hash: CFHashCode }
    private struct Button { let title: String; let element: AXUIElement; let enabled: Bool }
    private struct Snapshot { let texts: [String]; let buttons: [Button]; let complete: Bool }

    public init() {}

    /// Call once on the main thread. No event tap, screen capture, or polling timer is installed.
    public func start(enabled: Bool) {
        guard tokens.isEmpty else { setEnabled(enabled); return }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didLaunchApplicationNotification) { [weak self] _ in self?.refresh() }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] _ in self?.refresh() }
        observe(workspace, NSWorkspace.didTerminateApplicationNotification) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.queue.async { [weak self] in self?.detach(app.processIdentifier) }
        }
        observe(workspace, NSWorkspace.willSleepNotification) { [weak self] _ in self?.setInactive(true) }
        observe(workspace, NSWorkspace.didWakeNotification) { [weak self] _ in self?.setInactive(false) }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] _ in self?.setInactive(true) }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] _ in self?.setInactive(false) }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { [weak self] _ in self?.screenStateChanged(locked: true) }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { [weak self] _ in self?.screenStateChanged(locked: false) }
        setEnabled(enabled)
    }

    /// A locked screen with an active session can stay under watch; anything else suspends it.
    private func screenStateChanged(locked: Bool) {
        if locked && workWhileLocked { refresh(); return }
        setInactive(locked)
    }

    public func stop() {
        intentLock.lock()
        requestedEnabled = false
        intentLock.unlock()
        tokens.forEach { $0.0.removeObserver($0.1) }
        tokens.removeAll()
        queue.sync { wanted = false; reset(); publish(.paused) }
    }

    public func setEnabled(_ value: Bool) {
        // The main thread can interrupt a long scan before its queued state update runs.
        intentLock.lock()
        requestedEnabled = value
        intentLock.unlock()
        queue.async { [weak self] in
            guard let self = self else { return }
            self.wanted = value
            self.reset()
            self.reconcile()
        }
    }

    public func refresh() { queue.async { [weak self] in self?.reconcile() } }

    public func setPolicy(_ policy: PermissionPolicy) {
        intentLock.lock()
        requestedPolicy = policy
        intentLock.unlock()
        // Revisit ignored windows, but never press a second button on an already handled request.
        refresh()
    }

    private func action(for kind: PermissionKind) -> PermissionAction {
        intentLock.lock()
        defer { intentLock.unlock() }
        return requestedPolicy[kind]
    }

    private func setInactive(_ value: Bool) {
        intentLock.lock()
        requestedInactive = value
        intentLock.unlock()
        queue.async { [weak self] in
            guard let self = self else { return }
            self.inactive = value
            self.reset()
            self.reconcile()
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ callback: @escaping (Notification) -> Void) {
        tokens.append((center, center.addObserver(forName: name, object: nil, queue: .main, using: callback)))
    }

    private func publish(_ state: State) {
        guard lastState != state else { return }
        lastState = state
        DispatchQueue.main.async { [weak self] in self?.onState?(state) }
    }

    private func emit(_ request: PermissionRequest, _ result: String) {
        let event = ApprovalEvent(app: request.requester, permission: request.kind.rawValue, result: result)
        DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
    }

    private var mayAct: Bool {
        intentLock.lock()
        let allowed = requestedEnabled && !requestedInactive
        intentLock.unlock()
        return allowed && AXIsProcessTrusted()
    }

    private func reconcile() {
        guard wanted else { publish(.paused); return }
        guard !inactive else { publish(.sleeping); return }
        guard AXIsProcessTrusted() else { reset(); publish(.needsAccess); return }
        publish(.running)
        let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == hostID }
        let live = Set(apps.map(\.processIdentifier))
        for pid in Array(observers.keys) where !live.contains(pid) { detach(pid) }
        for app in apps {
            if observers[app.processIdentifier] == nil { attach(app.processIdentifier) }
            schedule(app.processIdentifier)
        }
    }

    private func trustedHost(_ pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid), app.bundleIdentifier == hostID else { return false }
        var code: SecCode?
        let attributes = [kSecGuestAttributePid: NSNumber(value: pid)] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess, let code = code else { return false }
        var requirement: SecRequirement?
        let rule = "anchor apple and identifier \"\(hostID)\"" as CFString
        guard SecRequirementCreateWithString(rule, [], &requirement) == errSecSuccess else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }

    private func attach(_ pid: pid_t) {
        guard trustedHost(pid) else { return }
        var value: AXObserver?
        let callback: AXObserverCallback = { _, element, _, context in
            guard let context = context else { return }
            let engine = Unmanaged<PermissionEngine>.fromOpaque(context).takeUnretainedValue()
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            engine.queue.async { [weak engine] in engine?.schedule(pid) }
        }
        guard AXObserverCreate(pid, callback, &value) == .success, let observer = value else { return }
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.15)
        let context = Unmanaged.passUnretained(self).toOpaque()
        var subscriptions = 0
        for name in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, "AXSheetCreated", "AXLayoutChanged"] {
            if AXObserverAddNotification(observer, root, name as CFString, context) == .success { subscriptions += 1 }
        }
        guard subscriptions > 0 else { return }
        observers[pid] = observer
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func detach(_ pid: pid_t) {
        pending.removeValue(forKey: pid)?.cancel()
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        handled = handled.filter { $0.key.pid != pid }
    }

    private func reset() {
        epoch += 1
        for pid in Array(observers.keys) { detach(pid) }
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
        handled.removeAll()
    }

    private func schedule(_ pid: pid_t) {
        guard mayAct, observers[pid] != nil, pending[pid] == nil else { return }
        let generation = epoch
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.epoch == generation else { return }
            self.pending[pid] = nil
            self.scan(pid)
        }
        pending[pid] = item
        queue.asyncAfter(deadline: .now() + 0.08, execute: item)
    }

    private func scan(_ pid: pid_t) {
        guard mayAct, trustedHost(pid) else { reconcile(); return }
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.15)
        guard let windows = attribute(root, kAXWindowsAttribute) as? [AXUIElement] else { return }
        let live = Set(windows.map { WindowID(pid: pid, hash: CFHash($0)) })
        handled = handled.filter { $0.key.pid != pid || live.contains($0.key) }
        for window in windows.prefix(128) {
            guard mayAct else { return }
            let id = WindowID(pid: pid, hash: CFHash(window))
            guard let request = request(in: snapshot(window)) else { continue }
            if let prefix = requesterPrefix, !request.requester.hasPrefix(prefix) { continue }
            guard handled[id] != request.title else { continue }
            if observeOnly { handled[id] = request.title; emit(request, "Observed"); continue }
            let action = action(for: request.kind)
            guard let buttonTitle = action.buttonTitle else { continue }
            // Re-read the same window immediately before acting. Never search a different window for a button.
            let fresh = snapshot(window)
            guard mayAct, trustedHost(pid), self.request(in: fresh) == request,
                  let button = fresh.buttons.first(where: { PermissionRules.normalize($0.title) == buttonTitle && $0.enabled }) else { continue }
            var actions: CFArray?
            guard AXUIElementCopyActionNames(button.element, &actions) == .success,
                  (actions as? [String])?.contains(kAXPressAction) == true else { emit(request, "Button unavailable"); continue }
            guard mayAct, self.action(for: request.kind) == action else { continue }
            handled[id] = request.title
            let result = AXUIElementPerformAction(button.element, kAXPressAction as CFString)
            guard result == .success else { emit(request, "Click failed (\(result.rawValue))"); continue }
            emit(request, "Clicked \(buttonTitle)")
            verify(window, pid: pid, request: request, generation: epoch, final: false)
        }
    }

    private func verify(_ window: AXUIElement, pid: pid_t, request: PermissionRequest, generation: Int, final: Bool) {
        queue.asyncAfter(deadline: .now() + (final ? 0.9 : 0.3)) { [weak self] in
            guard let self = self, self.epoch == generation, self.mayAct else { return }
            let root = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(root, 0.15)
            guard let windows = self.attribute(root, kAXWindowsAttribute) as? [AXUIElement] else {
                self.emit(request, "Closure unverified")
                return
            }
            let present = windows.contains { CFEqual($0, window) }
            if !present {
                self.handled.removeValue(forKey: WindowID(pid: pid, hash: CFHash(window)))
                self.emit(request, "Dialog closed")
                self.schedule(pid)
            } else if final {
                self.emit(request, "Dialog still visible")
            } else {
                self.verify(window, pid: pid, request: request, generation: generation, final: true)
            }
        }
    }

    private func request(in snapshot: Snapshot) -> PermissionRequest? {
        guard snapshot.complete else { return nil }
        return PermissionRules.match(texts: snapshot.texts, buttons: snapshot.buttons.map(\.title))
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private func snapshot(_ window: AXUIElement) -> Snapshot {
        AXUIElementSetMessagingTimeout(window, 0.10)
        guard attribute(window, kAXRoleAttribute) as? String == kAXWindowRole else {
            return Snapshot(texts: [], buttons: [], complete: false)
        }
        var texts: [String] = []
        var buttons: [Button] = []
        var seen = Set<CFHashCode>()
        var complete = true
        let deadline = ProcessInfo.processInfo.systemUptime + 0.5
        func walk(_ element: AXUIElement, _ depth: Int) {
            guard complete else { return }
            guard depth <= 16, seen.count < 500, ProcessInfo.processInfo.systemUptime < deadline else { complete = false; return }
            guard seen.insert(CFHash(element)).inserted else { return }
            guard let role = attribute(element, kAXRoleAttribute) as? String else { complete = false; return }
            if role == kAXStaticTextRole {
                let title = attribute(element, kAXTitleAttribute) as? String ?? ""
                let value = title.isEmpty ? (attribute(element, kAXValueAttribute) as? String ?? "") : title
                // Preserve the first static text even if unreadable. Never promote a purpose string to headline.
                texts.append(value)
            }
            if role == kAXButtonRole {
                let title = attribute(element, kAXTitleAttribute) as? String ?? ""
                let enabled = attribute(element, kAXEnabledAttribute) as? Bool ?? false
                buttons.append(Button(title: title, element: element, enabled: enabled))
            }
            var children: CFTypeRef?
            let childrenResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
            if childrenResult == .success {
                guard let elements = children as? [AXUIElement] else { complete = false; return }
                for child in elements { walk(child, depth + 1) }
            } else if childrenResult != .attributeUnsupported && childrenResult != .noValue {
                complete = false
            }
        }
        walk(window, 0)
        return Snapshot(texts: texts, buttons: buttons, complete: complete)
    }
}
