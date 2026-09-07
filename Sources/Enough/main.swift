import AppKit
import EnoughCore

let arguments = CommandLine.arguments
if arguments.contains("--probe") {
    func argument(_ name: String) -> String? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
    let engine = PermissionEngine()
    engine.requesterPrefix = argument("--requester-prefix")
    engine.observeOnly = arguments.contains("--observe-only")
    engine.onState = { state in print("state: \(state.rawValue)"); fflush(stdout) }
    engine.onEvent = { event in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(event), let line = String(data: data, encoding: .utf8) { print(line); fflush(stdout) }
    }
    engine.start(enabled: true)
    let duration = min(60, max(1, Double(argument("--seconds") ?? "30") ?? 30))
    RunLoop.current.run(until: Date().addingTimeInterval(duration))
    engine.stop()
} else {
    let application = NSApplication.shared
    let delegate = EnoughAppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
}
