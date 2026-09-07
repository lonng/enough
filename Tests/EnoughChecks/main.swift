import Foundation
import EnoughCore

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
    checks += 1
    if !condition() { fputs("FAIL: \(description)\n", stderr); exit(1) }
}
let buttons = ["Don’t Allow", "Allow"]
for (folder, kind) in [("Documents", PermissionKind.documents), ("Desktop", .desktop), ("Downloads", .downloads)] {
    let match = PermissionRules.match(texts: ["“Python” would like to access files in your \(folder) folder."], buttons: buttons)
    expect(match?.requester == "Python" && match?.kind == kind, "Match \(folder) request")
}
for verb in ["wants", "would like"] {
    expect(PermissionRules.match(texts: ["“Python” \(verb) to access data from other apps."], buttons: buttons)?.kind == .appData, "Match app data using \(verb)")
}
let title = "“Python” would like to access files in your Documents folder."
expect(PermissionRules.match(texts: [title, title], buttons: buttons) != nil, "Deduplicate AX text")
expect(PermissionRules.match(texts: ["“Python” would like to access your microphone.", title], buttons: buttons) == nil, "Reject a supported title injected into a microphone purpose string")
expect(PermissionRules.match(texts: ["", title], buttons: buttons) == nil, "An unreadable headline cannot be replaced by a purpose string")
expect(PermissionRules.match(texts: [title, "Read the disposable test file."], buttons: buttons) != nil, "Allow an ordinary purpose string")
for rejected in [
    "“Python” would like to access your microphone.",
    "“Python” would like to record this computer's screen.",
    "“Python” is an app downloaded from the Internet. Are you sure you want to open it?",
    "“Python” would like to control “System Events”.",
    "Allow access to all passwords?", "Delete your Documents folder?",
    "Help: “Python” would like to access files in your Documents folder.",
    "“Python” would like to access files in your Documents folder. Delete them now.",
    "“Python” would like to access files in your Documents folder.\nAnd delete them.",
    "“Python” would like to access files in your Documents folder.\u{202e}"
] { expect(PermissionRules.match(texts: [rejected], buttons: buttons) == nil, "Reject unrelated or altered title: \(rejected)") }
for labels in [["OK", "Cancel"], ["Allow"], ["Allow", "Don't Allow", "Delete"], ["Allow", "Allow", "Don't Allow"], ["Don't Allow", "Always Allow"]] {
    expect(PermissionRules.match(texts: [title], buttons: labels) == nil, "Reject nonstandard button set")
}
expect(PermissionRules.match(texts: [title, "“Other App” would like to access files in your Documents folder."], buttons: buttons) == nil, "Reject ambiguous requester")
expect(PermissionRules.match(texts: ["Python möchte auf Dateien zugreifen."], buttons: ["Erlauben", "Nicht erlauben"]) == nil, "Leave untranslated dialogs alone")
expect(PermissionRules.match(texts: ["“工具” would like to access data from other apps."], buttons: buttons)?.requester == "工具", "Unicode app name in English system prompt")
expect(PermissionRules.match(texts: [title], buttons: buttons + ["Help", ""]) != nil, "Permit help control")
print("PASS: \(checks) permission matching checks")
