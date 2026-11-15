import Foundation

public enum PermissionAction: String, Codable, CaseIterable {
    case allow, deny, ignore

    public var buttonTitle: String? {
        switch self {
        case .allow: return "Allow"
        case .deny: return "Don't Allow"
        case .ignore: return nil
        }
    }
}

public struct PermissionPolicy: Equatable {
    private var actions: [PermissionKind: PermissionAction] = [:]

    public init(storedValues: [String: String] = [:]) {
        for (key, value) in storedValues {
            guard let kind = PermissionKind(rawValue: key), let action = PermissionAction(rawValue: value) else { continue }
            actions[kind] = action
        }
    }

    public subscript(kind: PermissionKind) -> PermissionAction {
        get { actions[kind] ?? .ignore }
        set { actions[kind] = newValue }
    }

    public var storedValues: [String: String] {
        Dictionary(uniqueKeysWithValues: actions.map { ($0.key.rawValue, $0.value.rawValue) })
    }

    public var hasAutomaticActions: Bool { actions.values.contains { $0 != .ignore } }
}
