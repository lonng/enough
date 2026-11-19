import Foundation
import EnoughCore

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
    checks += 1
    if !condition() { fputs("FAIL: \(description)\n", stderr); exit(1) }
}
let buttons = ["Don’t Allow", "Allow"]
for (folder, kind) in [("Documents", PermissionKind.documents), ("Desktop", .desktop), ("Downloads", .downloads), ("Music", .musicFolder), ("Movies", .moviesFolder), ("Pictures", .picturesFolder)] {
    let match = PermissionRules.match(texts: ["“Python” would like to access files in your \(folder) folder."], buttons: buttons)
    expect(match?.requester == "Python" && match?.kind == kind, "Match \(folder) request")
}
for verb in ["wants", "would like"] {
    expect(PermissionRules.match(texts: ["“Python” \(verb) to access data from other apps."], buttons: buttons)?.kind == .appData, "Match app data using \(verb)")
    for punctuation in ["", "."] {
        for (openQuote, closeQuote) in [("“", "”"), ("\"", "\"")] {
            let removable = "\(openQuote)Python\(closeQuote) \(verb) to access files on a removable volume\(punctuation)"
            let match = PermissionRules.match(texts: [removable], buttons: buttons)
            expect(match?.requester == "Python" && match?.kind == .removableVolumes && match?.title == PermissionRules.normalize(removable), "Match removable volume using \(verb), quotes \(openQuote)\(closeQuote), and punctuation '\(punctuation)'")
        }
    }
}
for wording in [
    "access files on a removable volume.",
    "access files on a removable volume",
    "access files on the removable volume.",
    "access files on removable volumes.",
    "access files on a removable disk.",
    "access files on a removable drive."
] {
    let removable = "“Python” would like to \(wording)"
    expect(PermissionRules.match(texts: [removable], buttons: buttons)?.kind == .removableVolumes,
           "Match removable-volume wording: \(wording)")
}
let title = "“Python” would like to access files in your Documents folder."
let removableTitle = "“Python” would like to access files on a removable volume."
expect(PermissionRules.match(texts: [removableTitle, removableTitle], buttons: buttons)?.kind == .removableVolumes, "Deduplicate removable volume AX text")
expect(PermissionRules.match(texts: [removableTitle, "Read files from the connected drive."], buttons: buttons)?.kind == .removableVolumes, "Allow a removable volume request with ordinary purpose text")
expect(PermissionRules.match(texts: ["“Python” would like to access your microphone.", removableTitle], buttons: buttons) == nil, "Reject a removable volume title injected into a microphone purpose string")
expect(PermissionRules.match(texts: ["", removableTitle], buttons: buttons) == nil, "An unreadable headline cannot be replaced by a removable volume purpose string")
expect(PermissionRules.match(texts: [title, removableTitle], buttons: buttons) == nil, "Reject ambiguous folder and removable volume requests")
expect(PermissionRules.match(texts: [removableTitle, "“Other App” would like to access files on a removable volume."], buttons: buttons) == nil, "Reject ambiguous removable volume requesters")
expect(PermissionRules.match(texts: [title, title], buttons: buttons) != nil, "Deduplicate AX text")
expect(PermissionRules.match(texts: ["“Python” would like to access your microphone.", title], buttons: buttons) == nil, "Reject a supported title injected into a microphone purpose string")
expect(PermissionRules.match(texts: ["", title], buttons: buttons) == nil, "An unreadable headline cannot be replaced by a purpose string")
expect(PermissionRules.match(texts: [title, "Read the disposable test file."], buttons: buttons) != nil, "Allow an ordinary purpose string")
for rejected in [
    "“Python” would like to access your microphone.",
    "“Python” would like to record this computer's screen.",
    "“Python” is an app downloaded from the Internet. Are you sure you want to open it?",
    "“Python” would like to control “System Events”.",
    "“Python” would like to access files on a network volume.",
    "“Python” would like to access files in your Public folder.",
    "“Python” would like to access files in your music folder.",
    "“Python” would like to erase files on a removable volume.",
    "Help: \(removableTitle)",
    "\(removableTitle) Delete them now.",
    "\(removableTitle)\nAnd delete them.",
    "\(removableTitle)\u{202e}",
    "Allow access to all passwords?", "Delete your Documents folder?",
    "Help: “Python” would like to access files in your Documents folder.",
    "“Python” would like to access files in your Documents folder. Delete them now.",
    "“Python” would like to access files in your Documents folder.\nAnd delete them.",
    "“Python” would like to access files in your Documents folder.\u{202e}"
] { expect(PermissionRules.match(texts: [rejected], buttons: buttons) == nil, "Reject unrelated or altered title: \(rejected)") }
for labels in [["OK", "Cancel"], ["Allow"], ["Allow", "Don't Allow", "Delete"], ["Allow", "Allow", "Don't Allow"], ["Don't Allow", "Always Allow"]] {
    expect(PermissionRules.match(texts: [title], buttons: labels) == nil, "Reject nonstandard button set")
    expect(PermissionRules.match(texts: [removableTitle], buttons: labels) == nil, "Reject nonstandard buttons on removable volume requests")
}
expect(PermissionRules.match(texts: [title, "“Other App” would like to access files in your Documents folder."], buttons: buttons) == nil, "Reject ambiguous requester")
expect(PermissionRules.match(texts: ["Python möchte auf Dateien zugreifen."], buttons: ["Erlauben", "Nicht erlauben"]) == nil, "Leave untranslated dialogs alone")
expect(PermissionRules.match(texts: ["“工具” would like to access data from other apps."], buttons: buttons)?.requester == "工具", "Unicode app name in English system prompt")
expect(PermissionRules.match(texts: [title], buttons: buttons + ["Help", ""]) != nil, "Permit help control")
let defaultPolicy = PermissionPolicy()
for kind in PermissionKind.allCases {
    expect(defaultPolicy[kind] == .ignore, "Unconfigured \(kind.rawValue) requests are ignored")
}
expect(!defaultPolicy.hasAutomaticActions, "A default policy never clicks a button")
var policy = PermissionPolicy(storedValues: ["Documents": "allow", "Removable volumes": "deny", "App data": "ignore", "Music": "deny", "Desktop": "unknown", "Camera": "allow"])
expect(policy[.documents] == .allow && policy[.removableVolumes] == .deny && policy[.appData] == .ignore, "Restore independent allow, deny, and ignore rules")
expect(policy[.musicFolder] == .deny && policy[.moviesFolder] == .ignore && policy[.picturesFolder] == .ignore, "Restore new media folder rules")
expect(policy[.desktop] == .ignore && policy[.downloads] == .ignore, "Invalid and missing rules default to ignore")
expect(policy.storedValues["Camera"] == nil, "Unknown permission types cannot become automatic rules")
expect(policy.hasAutomaticActions, "An allow or deny rule enables automatic handling")
expect(policy[.documents].buttonTitle == "Allow", "Allow targets the affirmative button")
expect(policy[.removableVolumes].buttonTitle == PermissionRules.normalize("Don’t Allow"), "Deny targets the normalized negative button")
expect(policy[.appData].buttonTitle == nil, "Ignore never selects a button")
expect(PermissionPolicy(storedValues: policy.storedValues) == policy, "Mixed rules survive persistence")
policy[.documents] = .ignore
expect(policy[.documents].buttonTitle == nil && policy[.removableVolumes] == .deny, "Changing one rule leaves other rules intact")
policy[.removableVolumes] = .allow
expect(policy[.removableVolumes].buttonTitle == "Allow", "A changed rule selects the new response")
policy[.removableVolumes] = .ignore
policy[.musicFolder] = .ignore
expect(!policy.hasAutomaticActions, "Returning every rule to ignore disables all automatic responses")
print("PASS: \(checks) permission matching and policy checks")
