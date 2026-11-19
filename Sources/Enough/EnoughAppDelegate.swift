import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI
import EnoughCore

final class EnoughAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let engine = PermissionEngine()
    private let defaults = UserDefaults.standard
    private let history = HistoryStore()
    private let panel = PanelModel()
    private var item: NSStatusItem!
    private var popover: NSPopover?
    private var setupTimer: Timer?
    private var enabled: Bool { defaults.bool(forKey: "enabled") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LaunchServices normally reuses the running app. Also handle an explicit new instance.
        if NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }) { NSApp.terminate(nil); return }
        defaults.register(defaults: ["enabled": true])
        panel.policy = PermissionPolicy(storedValues: defaults.dictionary(forKey: "permissionActions") as? [String: String] ?? [:])
        panel.events = history.events
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        engine.onState = { [weak self] state in self?.panel.state = state; self?.updateUI() }
        engine.onEvent = { [weak self] event in
            guard let self = self else { return }
            self.history.append(event)
            self.panel.events = self.history.events
        }
        engine.setPolicy(panel.policy)
        engine.start(enabled: enabled)
        if !defaults.bool(forKey: "hasOpened") || !AXIsProcessTrusted() || CommandLine.arguments.contains("--show") {
            defaults.set(true, forKey: "hasOpened")
            showPopover()
        }
        updateUI()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updateUI()
        if popover?.isShown == true && !AXIsProcessTrusted() { startSetupCheck() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        setupTimer?.invalidate()
        engine.stop()
        history.flush()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover?.isShown == true { popover?.performClose(sender) } else { showPopover() }
    }

    private func showPopover() {
        if popover == nil {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true
            popover.contentViewController = NSHostingController(rootView: PanelView(model: panel, actions: makeActions()))
            popover.delegate = self
            self.popover = popover
        }
        guard let button = item.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        engine.refresh()
        updateUI()
        if !AXIsProcessTrusted() { startSetupCheck() }
    }

    func popoverDidClose(_ notification: Notification) { setupTimer?.invalidate() }

    private func setEnabled(_ value: Bool) {
        defaults.set(value, forKey: "enabled")
        engine.setEnabled(value)
        updateUI()
    }

    private func setRule(_ kind: PermissionKind, _ action: PermissionAction) {
        panel.policy[kind] = action
        engine.setPolicy(panel.policy)
        defaults.set(panel.policy.storedValues, forKey: "permissionActions")
    }

    private func grantAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        startSetupCheck()
    }

    private func startSetupCheck() {
        setupTimer?.invalidate()
        // A temporary trust check while the popover is visible. Dialog watching itself has no polling timer.
        setupTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self, self.popover?.isShown == true else { timer.invalidate(); return }
            if AXIsProcessTrusted() { timer.invalidate(); self.engine.refresh(); self.updateUI() }
        }
        setupTimer?.tolerance = 0.5
    }

    private func makeActions() -> PanelActions {
        PanelActions(
            setEnabled: { [weak self] in self?.setEnabled($0) },
            setRule: { [weak self] in self?.setRule($0, $1) },
            setLaunchAtLogin: { [weak self] in self?.setLaunchAtLogin($0) },
            grantAccess: { [weak self] in self?.grantAccess() },
            openLoginSettings: { SMAppService.openSystemSettingsLoginItems() },
            openLog: { [weak self] in self?.openLog() },
            openGitHub: { NSWorkspace.shared.open(URL(string: "https://github.com/jtc268/enough")!) },
            quit: { NSApp.terminate(nil) }
        )
    }

    private func updateUI() {
        let state = panel.state
        item?.button?.image = MenuBarIcon.automaticApproval
        item?.button?.toolTip = "Enough: \(L10n.text(state.rawValue))"
        item?.button?.setAccessibilityLabel("Enough: \(L10n.text(state.rawValue))")
        panel.enabled = enabled
        panel.hasAccessibility = AXIsProcessTrusted()
        let loginStatus = SMAppService.mainApp.status
        panel.launchAtLogin = loginStatus == .enabled || loginStatus == .requiresApproval
        panel.loginNeedsApproval = loginStatus == .requiresApproval
    }

    private func setLaunchAtLogin(_ value: Bool) {
        defer { updateUI() }
        guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") else {
            showError(L10n.text("Move Enough to Applications first."))
            return
        }
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { showError(L10n.text("Could not change Launch at Login:") + " " + error.localizedDescription) }
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.addButton(withTitle: L10n.text("OK"))
        if let window = popover?.contentViewController?.view.window { alert.beginSheetModal(for: window) }
        else { alert.runModal() }
    }

    private func openLog() {
        history.flush()
        NSWorkspace.shared.activateFileViewerSelecting([history.url])
    }
}

private final class HistoryStore {
    private(set) var events: [ApprovalEvent] = []
    let url: URL
    private var save: DispatchWorkItem?
    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Enough")
        url = directory.appendingPathComponent("activity.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: url), data.count <= 1_000_000 {
            events = Array(((try? JSONDecoder().decode([ApprovalEvent].self, from: data)) ?? []).suffix(500))
        }
    }
    func append(_ event: ApprovalEvent) {
        events.append(event)
        events = Array(events.suffix(500))
        save?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.flush() }
        save = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }
    func flush() {
        save?.cancel()
        save = nil
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
