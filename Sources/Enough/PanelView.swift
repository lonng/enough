import SwiftUI
import EnoughCore

final class PanelModel: ObservableObject {
    @Published var enabled = true
    @Published var state: PermissionEngine.State = .needsAccess
    @Published var hasAccessibility = false
    @Published var launchAtLogin = false
    @Published var loginNeedsApproval = false
    @Published var policy = PermissionPolicy()
    @Published var events: [ApprovalEvent] = []
}

struct PanelActions {
    let setEnabled: (Bool) -> Void
    let setRule: (PermissionKind, PermissionAction) -> Void
    let setLaunchAtLogin: (Bool) -> Void
    let grantAccess: () -> Void
    let openLoginSettings: () -> Void
    let openLog: () -> Void
    let openGitHub: () -> Void
    let quit: () -> Void
}

/// Compact menu bar popover: header, toggles, permission cards, and the latest activity.
struct PanelView: View {
    @ObservedObject var model: PanelModel
    let actions: PanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 12)
            Divider()
            toggles
                .padding(.vertical, 12)
            Divider()
            rules
                .padding(.vertical, 12)
            Divider()
            activity
                .padding(.vertical, 12)
            Divider()
            footer
                .padding(.top, 10)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(nsImage: MenuBarIcon.appIcon)
                .resizable().scaledToFit()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Enough").font(.system(size: 15, weight: .semibold, design: .rounded))
                    accessBadge
                }
                Text(L10n.text(statusDescription))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            if !model.hasAccessibility {
                Button(L10n.text("Open Settings"), action: actions.grantAccess)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    private var accessBadge: some View {
        Label(L10n.text(model.hasAccessibility ? "Accessibility Granted" : "Needs Accessibility"),
              systemImage: model.hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(model.hasAccessibility ? Color.green : Color.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((model.hasAccessibility ? Color.green : Color.orange).opacity(0.14), in: Capsule())
            .accessibilityLabel(L10n.text(model.hasAccessibility ? "Accessibility Granted" : "Needs Accessibility"))
    }

    // MARK: Toggles

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.text("Automation")).font(.callout)
                Spacer()
                Toggle(L10n.text("Automation"), isOn: Binding(get: { model.enabled }, set: actions.setEnabled))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            HStack {
                Text(L10n.text("Launch at Login")).font(.callout)
                Spacer()
                Toggle(L10n.text("Launch at Login"), isOn: Binding(get: { model.launchAtLogin }, set: actions.setLaunchAtLogin))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            if model.loginNeedsApproval {
                HStack {
                    Text(L10n.text("Allow Enough in Login Items to finish setup."))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.text("Open Login Items"), action: actions.openLoginSettings)
                        .controlSize(.small)
                }
            }
        }
    }

    // MARK: Rules

    private var rules: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("Permission rules")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(PermissionKind.allCases, id: \.self) { kind in
                    permissionCard(kind)
                }
            }
        }
    }

    private func permissionCard(_ kind: PermissionKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(L10n.text(kind.rawValue))
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Picker(L10n.text(kind.rawValue), selection: Binding(get: { model.policy[kind] }, set: { actions.setRule(kind, $0) })) {
                Text(L10n.text("Allow")).tag(PermissionAction.allow)
                Text(L10n.text("Deny")).tag(PermissionAction.deny)
                Text(L10n.text("Ignore")).tag(PermissionAction.ignore)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .help(L10n.text(kind.detail))
        .accessibilityLabel(L10n.text(kind.rawValue))
    }

    // MARK: Activity

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.text("Recent activity")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("Open Activity Log"), action: actions.openLog)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .font(.caption)
            }
            if model.events.isEmpty {
                Text(L10n.text("No activity yet"))
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(model.events.suffix(5).reversed())) { event in
                        activityRow(event)
                    }
                }
            }
        }
    }

    private func activityRow(_ event: ApprovalEvent) -> some View {
        HStack(spacing: 8) {
            Text(event.app).font(.callout.weight(.medium)).lineLimit(1)
            Spacer(minLength: 4)
            Text("\(L10n.text(event.permission)) · \(L10n.text(event.result))")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(event.date, style: .time)
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .textSelection(.enabled)
        .padding(.vertical, 3)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("GitHub", action: actions.openGitHub)
                .buttonStyle(.borderless)
                .controlSize(.small)
            Spacer()
            Button(action: actions.quit) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help(L10n.text("Quit Enough"))
            .accessibilityLabel(L10n.text("Quit Enough"))
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private var statusDescription: String {
        if !model.enabled { return "Paused. You can still edit your rules." }
        if !model.hasAccessibility { return "Grant Accessibility access to start." }
        if model.state == .sleeping { return "Waiting for your session to become active." }
        return model.policy.hasAutomaticActions ? "Watching for requests that match your rules." : "All requests are ignored. Choose a rule below to start."
    }
}

private extension PermissionKind {
    var symbol: String {
        switch self {
        case .documents: return "doc.text"
        case .desktop: return "desktopcomputer"
        case .downloads: return "arrow.down.circle"
        case .musicFolder: return "music.note"
        case .moviesFolder: return "film"
        case .picturesFolder: return "photo"
        case .removableVolumes: return "externaldrive"
        case .appData: return "square.stack.3d.up"
        }
    }

    var detail: String {
        switch self {
        case .documents: return "Files in Documents"
        case .desktop: return "Files on your Desktop"
        case .downloads: return "Files in Downloads"
        case .musicFolder: return "Files in your Music folder"
        case .moviesFolder: return "Files in your Movies folder"
        case .picturesFolder: return "Files in your Pictures folder"
        case .removableVolumes: return "External disks and USB drives"
        case .appData: return "Other apps’ data · Experimental"
        }
    }
}
