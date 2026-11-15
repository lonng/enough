import Foundation

public enum PermissionKind: String, Codable, CaseIterable {
    case documents = "Documents"
    case desktop = "Desktop"
    case downloads = "Downloads"
    case removableVolumes = "Removable volumes"
    case appData = "App data"
}

public struct PermissionRequest: Equatable {
    public let requester: String
    public let kind: PermissionKind
    public let title: String
}

public enum PermissionRules {
    public static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first text must be the system headline. App-supplied purpose text cannot authorize a click.
    public static func match(texts: [String], buttons: [String]) -> PermissionRequest? {
        let labels = buttons.map(normalize).filter { !$0.isEmpty && $0 != "Help" }
        guard labels.count == 2, Set(labels) == ["Allow", "Don't Allow"] else { return nil }
        guard let headline = texts.first.map(normalize), !headline.isEmpty else { return nil }
        let titles = Set(texts.map(normalize))
        var matches: [PermissionRequest] = []
        for title in titles {
            if let groups = captures(#"^"([^"\r\n]{1,180})" (?:would like|wants) to access files in your (Documents|Desktop|Downloads) folder\.?$"#, title),
               let kind = PermissionKind(rawValue: groups[1]) {
                matches.append(PermissionRequest(requester: groups[0], kind: kind, title: title))
            } else if let groups = captures(#"^"([^"\r\n]{1,180})" (?:would like|wants) to access files on (?:a |the )?removable (?:volume|volumes|disk|disks|drive|drives)\.?$"#, title) {
                matches.append(PermissionRequest(requester: groups[0], kind: .removableVolumes, title: title))
            } else if let groups = captures(#"^"([^"\r\n]{1,180})" (?:would like|wants) to access data from other apps\.?$"#, title) {
                matches.append(PermissionRequest(requester: groups[0], kind: .appData, title: title))
            }
        }
        // Multiple distinct request titles in one window are ambiguous.
        return matches.count == 1 && matches[0].title == headline ? matches[0] : nil
    }

    private static func captures(_ pattern: String, _ value: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return nil }
        return (1..<match.numberOfRanges).compactMap {
            Range(match.range(at: $0), in: value).map { String(value[$0]) }
        }
    }
}

public struct ApprovalEvent: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let app: String
    public let permission: String
    public let result: String

    public init(app: String, permission: String, result: String) {
        self.id = UUID()
        self.date = Date()
        self.app = app
        self.permission = permission
        self.result = result
    }
}
