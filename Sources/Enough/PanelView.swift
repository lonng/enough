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
            VStack(alignment: .leading, spacing: 10) {
                controlPanel
                launchRow
            }
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

    // MARK: Rules

    /// The master Automation switch and the auto-allow / auto-deny lists in one card.
    /// A kind picked in one list leaves the other; picked in neither, it stays ignored.
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.text("Automation")).font(.headline)
                Spacer()
                Toggle(L10n.text("Automation"), isOn: Binding(get: { model.enabled }, set: actions.setEnabled))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            Divider()
            actionMenu(titleKey: "Auto allow", action: .allow)
            actionMenu(titleKey: "Auto deny", action: .deny)
            Text(L10n.text("Allow grants access. Deny refuses it. Ignore leaves the dialog for you. Rules apply to any app; English system dialogs only."))
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func actionMenu(titleKey: String, action: PermissionAction) -> some View {
        let selected = PermissionKind.allCases.filter { model.policy[$0] == action }
        let summary = selected.isEmpty ? L10n.text("None")
            : selected.map { L10n.text($0.rawValue) }.joined(separator: ", ")
        return HStack {
            Text(L10n.text(titleKey)).font(.callout)
            Spacer()
            Menu {
                ForEach(PermissionKind.allCases, id: \.self) { kind in
                    Toggle(isOn: Binding(
                        get: { model.policy[kind] == action },
                        set: { actions.setRule(kind, $0 ? action : .ignore) }
                    )) {
                        Text(L10n.text(kind.rawValue))
                    }
                }
            } label: {
                Text(summary)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 180, alignment: .trailing)
            }
            .fixedSize()
            .frame(maxWidth: 190)
        }
    }

    private var launchRow: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(.horizontal, 2)
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
