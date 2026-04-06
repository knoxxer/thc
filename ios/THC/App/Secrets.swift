import Foundation

/// Loads runtime secrets from `Secrets.plist` bundled with the app.
///
/// `Secrets.plist` is excluded from version control (see `.gitignore`).
/// Copy `Secrets.plist.example` → `Secrets.plist` and fill in real values
/// before building. The file must be added to the Xcode target so it lands
/// in the main bundle.
///
/// Usage:
/// ```swift
/// let client = SupabaseClient(
///     supabaseURL: URL(string: Secrets.supabaseURL)!,
///     supabaseKey: Secrets.supabaseAnonKey
/// )
/// ```
enum Secrets {

    // MARK: - Public API

    /// Supabase project URL string, e.g. `"https://abcdefghijkl.supabase.co"`.
    static var supabaseURL: String {
        value(forKey: "SUPABASE_URL")
    }

    /// Supabase anonymous (public) API key.
    static var supabaseAnonKey: String {
        value(forKey: "SUPABASE_ANON_KEY")
    }

    // MARK: - Private

    /// Lazily loaded plist dictionary. Crashes at startup (not silently at
    /// call-site) if the file is missing or malformed so the problem is
    /// immediately obvious during development.
    nonisolated(unsafe) private static let plist: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else {
            fatalError(
                "[Secrets] Secrets.plist not found in main bundle. " +
                "Copy ios/Secrets.plist.example → ios/Secrets.plist, " +
                "fill in real values, and add the file to the Xcode target."
            )
        }

        guard
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            fatalError("[Secrets] Secrets.plist exists but could not be parsed as a dictionary plist.")
        }

        return dict
    }()

    private static func value(forKey key: String) -> String {
        guard let value = plist[key] as? String, !value.isEmpty else {
            fatalError("[Secrets] Missing or empty value for key '\(key)' in Secrets.plist.")
        }
        return value
    }
}
