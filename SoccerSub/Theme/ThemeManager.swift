import Observation
import SwiftUI

// MARK: – Manager

@Observable
final class ThemeManager {
    private(set) var current: AppTheme

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private static let defaultsKey = "activeThemeId"

    /// Shared singleton used by the app.  Inject a different `defaults`
    /// in unit tests to get an isolated, reproducible environment.
    static let shared = ThemeManager()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let savedId = defaults.string(forKey: Self.defaultsKey),
           let match = AppTheme.allThemes.first(where: { $0.id == savedId }) {
            current = match
        } else {
            current = .defaultTheme
        }
    }

    func select(_ theme: AppTheme) {
        current = theme
        defaults.set(theme.id, forKey: Self.defaultsKey)
    }
}

// MARK: – SwiftUI environment plumbing

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue: ThemeManager = .shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
