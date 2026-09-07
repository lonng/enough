import AppKit
import ApplicationServices
import ServiceManagement
import EnoughCore

final class EnoughAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let engine = PermissionEngine()
    private let defaults = UserDefaults.standard
    private let history = HistoryStore()
    private var item: NSStatusItem!
    private var window: NSWindow?
    private var state: PermissionEngine.State = .needsAccess
    private var statusLabel: NSTextField?
    private var toggle: NSButton?
    private var accessButton: NSButton?
    private var activity: NSTextView?
    private var setupTimer: Timer?
    private var enabled: Bool { defaults.bool(forKey: "enabled") }
    private let green = NSColor(srgbRed: 0.10, green: 0.35, blue: 0.23, alpha: 1)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LaunchServices normally reuses the running app. Also handle `open -n`.
        if NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }) { NSApp.terminate(nil); return }
        defaults.register(defaults: ["enabled": true])
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.toolTip = "Enough"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        engine.onState = { [weak self] state in self?.state = state; self?.updateUI() }
        engine.onEvent = { [weak self] event in self?.history.append(event); self?.updateActivity() }
        engine.start(enabled: enabled)
        if !defaults.bool(forKey: "hasOpened") || !AXIsProcessTrusted() {
            defaults.set(true, forKey: "hasOpened")
            showWindow(nil)
        }
        updateUI()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        setupTimer?.invalidate()
        engine.stop()
        history.flush()
    }

    func menuWillOpen(_ menu: NSMenu) {
        engine.refresh()
        menu.removeAllItems()
        let status = NSMenuItem(title: "Enough: \(state.rawValue)", action: nil, keyEquivalent: "")
        menu.addItem(status)
        menu.addItem(.separator())
        add(menu, enabled ? "Pause" : "Turn On", #selector(toggleEnabled(_:)))
        add(menu, "Open Enough", #selector(showWindow(_:)))
        add(menu, "Open Activity Log", #selector(openLog(_:)))
        let login = add(menu, "Launch at Login", #selector(toggleLogin(_:)))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        add(menu, "GitHub", #selector(openGitHub(_:)))
        add(menu, "Buy Me a Coffee", #selector(openCoffee(_:)))
        menu.addItem(.separator())
        add(menu, "Quit Enough", #selector(quit(_:)), "q")
    }

    @discardableResult private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        menu.addItem(entry)
        return entry
    }

    @objc private func toggleEnabled(_ sender: Any?) {
        defaults.set(!enabled, forKey: "enabled")
        engine.setEnabled(enabled)
        updateUI()
    }

    @objc private func grantAccess(_ sender: Any?) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        startSetupCheck()
    }

    private func startSetupCheck() {
        setupTimer?.invalidate()
        // A temporary trust check while setup is visible. Dialog watching itself has no polling timer.
        setupTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self, self.window?.isVisible == true else { timer.invalidate(); return }
            if AXIsProcessTrusted() { timer.invalidate(); self.engine.refresh(); self.updateUI() }
        }
        setupTimer?.tolerance = 0.5
    }

    @objc private func showWindow(_ sender: Any?) {
        if window == nil { buildWindow() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        engine.refresh()
        updateUI()
        if !AXIsProcessTrusted() { startSetupCheck() }
    }

    func windowWillClose(_ notification: Notification) { setupTimer?.invalidate() }

    private func buildWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 570), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Enough"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        let content = NSView()
        window.contentView = content
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24)
        ])
        let title = label("Enough.", size: 36, weight: .bold)
        title.textColor = green
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(label("Automatic approval for macOS file and app-data popups.", size: 15))
        let status = label("Checking Accessibility access…", size: 15, weight: .semibold)
        stack.addArrangedSubview(status)
        statusLabel = status
        let access = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(grantAccess(_:)))
        access.bezelStyle = .rounded
        stack.addArrangedSubview(access)
        accessButton = access
        let checkbox = NSButton(checkboxWithTitle: "Automatically approve supported requests", target: self, action: #selector(toggleEnabled(_:)))
        stack.addArrangedSubview(checkbox)
        toggle = checkbox
        let explanation = label("When on, Enough clicks Allow for file and app-data requests from any app. It grants real access. English dialogs only in this release.", size: 12)
        explanation.textColor = .secondaryLabelColor
        stack.addArrangedSubview(explanation)
        stack.addArrangedSubview(label("Recent activity", size: 13, weight: .semibold))
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let text = NSTextView()
        text.isEditable = false
        text.isSelectable = true
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.textContainerInset = NSSize(width: 10, height: 10)
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        scroll.documentView = text
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        activity = text
        let links = NSStackView()
        links.orientation = .horizontal
        links.spacing = 12
        for (name, action) in [("GitHub", #selector(openGitHub(_:))), ("Buy Me a Coffee", #selector(openCoffee(_:)))] {
            let button = NSButton(title: name, target: self, action: action)
            button.bezelStyle = .rounded
            links.addArrangedSubview(button)
        }
        stack.addArrangedSubview(links)
        for view in stack.arrangedSubviews where view is NSTextField {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        updateActivity()
    }

    private func label(_ value: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    private func updateUI() {
        let symbol = state == .running ? "checkmark.rectangle.fill" : (state == .needsAccess ? "exclamationmark.rectangle" : "pause.rectangle")
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Enough: \(state.rawValue)")
        image?.isTemplate = true
        item?.button?.image = image
        item?.button?.toolTip = "Enough: \(state.rawValue)"
        statusLabel?.stringValue = state == .needsAccess ? "Allow Enough in Accessibility to start." : "Enough is \(state.rawValue.lowercased())."
        accessButton?.isHidden = AXIsProcessTrusted()
        toggle?.state = enabled ? .on : .off
    }

    private func updateActivity() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        activity?.string = history.events.isEmpty ? "No activity yet. Enough is waiting for a supported request." : history.events.suffix(80).reversed().map {
            "\(formatter.string(from: $0.date))  \($0.app) · \($0.permission)\n\($0.result)"
        }.joined(separator: "\n\n")
    }

    @objc private func toggleLogin(_ sender: Any?) {
        guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") else {
            showError("Move Enough to Applications first.")
            return
        }
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { showError("Could not change Launch at Login: \(error.localizedDescription)") }
    }
    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    @objc private func openLog(_ sender: Any?) { history.flush(); NSWorkspace.shared.activateFileViewerSelecting([history.url]) }
    @objc private func openGitHub(_ sender: Any?) { NSWorkspace.shared.open(URL(string: "https://github.com/jtc268/enough")!) }
    @objc private func openCoffee(_ sender: Any?) { NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/refresh1")!) }
    @objc private func quit(_ sender: Any?) { NSApp.terminate(nil) }
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
