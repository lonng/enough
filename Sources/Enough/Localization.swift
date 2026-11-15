import Foundation

enum L10n {
    // SwiftPM's executable resource lookup needs an explicit resource path inside a packaged Mac app.
    private static let bundle: Bundle = {
        let resources: Bundle
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Enough_Enough.bundle"),
           let packaged = Bundle(url: url) { resources = packaged }
        else { resources = .module }
        let languages = ["en"] + resources.localizations.filter { $0 != "en" }
        let preferred = Bundle.preferredLocalizations(from: languages, forPreferences: Locale.preferredLanguages).first ?? "en"
        if let url = resources.url(forResource: preferred, withExtension: "lproj"),
           let localized = Bundle(url: url) { return localized }
        return resources
    }()

    static func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func result(_ value: String) -> String {
        if value.hasPrefix("Click failed (") {
            return text("Click failed") + " " + value.dropFirst("Click failed ".count)
        }
        return text(value)
    }
}
