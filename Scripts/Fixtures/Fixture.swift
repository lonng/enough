import AppKit
import Foundation

// Disposable integration fixture. Reports success and counts, never names or file contents.
final class FixtureDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.global(qos: .utility).async {
            let role = Bundle.main.object(forInfoDictionaryKey: "FixtureRole") as? String ?? "documents"
            let ownerID = "com.adore.enough.fixture.owner-signed"
            var result: [String: Any] = ["role": role, "time": ISO8601DateFormatter().string(from: Date())]
            do {
                let manager = FileManager.default
                switch role {
                case "owner":
                    let target = manager.homeDirectoryForCurrentUser.appendingPathComponent("enough-test.txt")
                    guard target.path.contains("/Library/Containers/\(ownerID)/Data/") else {
                        throw NSError(domain: "EnoughFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Owner must run in its own sandbox"])
                    }
                    if CommandLine.arguments.contains("--cleanup") {
                        if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
                    } else {
                        try Data("Enough disposable test data".utf8).write(to: target)
                    }
                    result["success"] = true
                case "reader":
                    let target = manager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/\(ownerID)/Data/enough-test.txt")
                    result["success"] = try String(contentsOf: target, encoding: .utf8) == "Enough disposable test data"
                default:
                    let folders: [String: FileManager.SearchPathDirectory] = ["documents": .documentDirectory, "desktop": .desktopDirectory, "downloads": .downloadsDirectory]
                    guard let folder = folders[role], let target = manager.urls(for: folder, in: .userDomainMask).first else {
                        throw NSError(domain: "EnoughFixture", code: 2)
                    }
                    result["count"] = try manager.contentsOfDirectory(at: target, includingPropertiesForKeys: nil).count
                    result["success"] = true
                }
            } catch {
                result["success"] = false
                result["error"] = String(describing: error)
            }
            let data = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            FileHandle.standardOutput.write(data + Data("\n".utf8))
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
let application = NSApplication.shared
let delegate = FixtureDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
