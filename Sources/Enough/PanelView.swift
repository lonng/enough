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

struct PanelView: View {
    @ObservedObject var model: PanelModel
    let actions: PanelActions
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Picker(L10n.text("View"), selection: $selectedTab) {
                Text(L10n.text("Configuration")).tag(0)
                Text(L10n.text("Activity")).tag(1)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 220)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            Group {
                if selectedTab == 0 { configuration }
                else { activity }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Button("GitHub", action: actions.openGitHub)
                    .buttonStyle(.borderless)
                Spacer()
                Button(action: actions.quit) {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help(L10n.text("Quit Enough"))
                .accessibilityLabel(L10n.text("Quit Enough"))
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var configuration: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.text("Automation")).font(.headline)
                            Text(L10n.text(statusDescription)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle(L10n.text("Automation"), isOn: Binding(get: { model.enabled }, set: actions.setEnabled))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    HStack {
                        Text(L10n.text("Launch at Login"))
                        Spacer()
                        Toggle(L10n.text("Launch at Login"), isOn: Binding(get: { model.launchAtLogin }, set: actions.setLaunchAtLogin))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    if model.loginNeedsApproval {
                        HStack {
                            Text(L10n.text("Allow Enough in Login Items to finish setup."))
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(L10n.text("Open Login Items"), action: actions.openLoginSettings)
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("Permission rules")).font(.headline)
                    VStack(spacing: 0) {
                        ForEach(PermissionKind.allCases, id: \.self) { kind in
                            permissionRow(kind)
                                .padding(.vertical, 10)
                            if kind != PermissionKind.allCases.last {
                                Divider().padding(.leading, 36)
                            }
                        }
                    }
                    Text(L10n.text("Allow grants access. Deny refuses it. Ignore leaves the dialog for you. Rules apply to any app; English system dialogs only."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }

    private var activity: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.text("Recent activity")).font(.headline)
                Spacer()
                Button(L10n.text("Open Activity Log"), action: actions.openLog)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 16)
            Divider().padding(.horizontal, 24)
            if model.events.isEmpty {
                Spacer()
                Image(systemName: "clock")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 12)
                Text(L10n.text("No activity yet")).font(.headline)
                Text(L10n.text("Automatic responses will appear here."))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.events.reversed()) { event in
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.app).lineLimit(1)
                                    Text("\(L10n.text(event.permission)) · \(L10n.result(event.result))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(event.date, style: .time)
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            .textSelection(.enabled)
                            .padding(.vertical, 12)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: MenuBarIcon.appIcon)
                .resizable().scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Enough").font(.system(size: 23, weight: .semibold, design: .rounded))
                    if !model.hasAccessibility {
                        Text(L10n.text("Needs Accessibility"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.14), in: Capsule())
                            .accessibilityLabel(L10n.text("Needs Accessibility"))
                    }
                }
                Text(L10n.text("Your permissions. Your rules."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if !model.hasAccessibility {
                Button(L10n.text("Open Settings"), action: actions.grantAccess)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(minWidth: 128)
            } else {
                Label(L10n.text(model.state.rawValue), systemImage: statusSymbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    private func permissionRow(_ kind: PermissionKind) -> some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text(kind.rawValue))
                Text(L10n.text(kind.detail)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Picker(L10n.text(kind.rawValue), selection: Binding(get: { model.policy[kind] }, set: { actions.setRule(kind, $0) })) {
                Text(L10n.text("Allow")).tag(PermissionAction.allow)
                Text(L10n.text("Deny")).tag(PermissionAction.deny)
                Text(L10n.text("Ignore")).tag(PermissionAction.ignore)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 210)
            .accessibilityLabel(L10n.text(kind.rawValue))
        }
    }

    private var statusDescription: String {
        if !model.enabled { return "Paused. You can still edit your rules." }
        if !model.hasAccessibility { return "Grant Accessibility access to start." }
        if model.state == .sleeping { return "Waiting for your session to become active." }
        return model.policy.hasAutomaticActions ? "Watching for requests that match your rules." : "All requests are ignored. Choose a rule below to start."
    }

    private var statusSymbol: String {
        switch model.state {
        case .running: return "checkmark.circle.fill"
        case .needsAccess: return "exclamationmark.circle"
        case .paused, .sleeping: return "pause.circle"
        }
    }
}

private extension PermissionKind {
    var symbol: String {
        switch self {
        case .documents: return "doc.text"
        case .desktop: return "desktopcomputer"
        case .downloads: return "arrow.down.circle"
        case .removableVolumes: return "externaldrive"
        case .appData: return "square.stack.3d.up"
        }
    }

    var detail: String {
        switch self {
        case .documents: return "Files in Documents"
        case .desktop: return "Files on your Desktop"
        case .downloads: return "Files in Downloads"
        case .removableVolumes: return "External disks and USB drives"
        case .appData: return "Other apps’ data · Experimental"
        }
    }
}
