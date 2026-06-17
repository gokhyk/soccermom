import Testing
import Foundation
@testable import SoccerSub

struct ThemeManagerTests {

    // Each test gets its own isolated UserDefaults suite so nothing bleeds between runs.
    private func freshDefaults() -> UserDefaults {
        let name = "test.ThemeManager.\(UUID().uuidString)"
        return UserDefaults(suiteName: name) ?? .standard
    }

    // MARK: – First-launch behaviour

    @Test("Default theme loads when no preference has been saved")
    func defaultThemeOnFirstLaunch() {
        let manager = ThemeManager(defaults: freshDefaults())
        #expect(manager.current.id == AppTheme.defaultTheme.id)
    }

    @Test("Default theme is 'fieldAndSun'")
    func defaultThemeIsFieldAndSun() {
        let manager = ThemeManager(defaults: freshDefaults())
        #expect(manager.current.id == "fieldAndSun")
    }

    // MARK: – Selecting a theme

    @Test("Selecting a theme updates current immediately")
    func selectUpdatesCurrent() {
        let manager = ThemeManager(defaults: freshDefaults())
        manager.select(.nightMatch)
        #expect(manager.current.id == "nightMatch")
    }

    @Test("Selecting a theme writes its ID to UserDefaults")
    func selectWritesToDefaults() {
        let defaults = freshDefaults()
        let manager = ThemeManager(defaults: defaults)
        manager.select(.nightMatch)
        #expect(defaults.string(forKey: "activeThemeId") == "nightMatch")
    }

    @Test("Selecting the default theme writes its ID to UserDefaults")
    func selectDefaultWritesToDefaults() {
        let defaults = freshDefaults()
        let manager = ThemeManager(defaults: defaults)
        manager.select(.fieldAndSun)
        #expect(defaults.string(forKey: "activeThemeId") == "fieldAndSun")
    }

    // MARK: – Persistence across relaunch

    @Test("A new ThemeManager re-reads the persisted theme (simulates relaunch)")
    func themeReloadsOnRelaunch() {
        let defaults = freshDefaults()

        // "First launch" — pick nightMatch
        let first = ThemeManager(defaults: defaults)
        first.select(.nightMatch)

        // "Relaunch" — new manager, same defaults store
        let second = ThemeManager(defaults: defaults)
        #expect(second.current.id == "nightMatch")
        #expect(second.current.name == "Night Match")
    }

    @Test("Selecting field-and-sun then relaunching restores field-and-sun")
    func relaunchRestoresFieldAndSun() {
        let defaults = freshDefaults()
        let first = ThemeManager(defaults: defaults)
        first.select(.fieldAndSun)

        let second = ThemeManager(defaults: defaults)
        #expect(second.current.id == "fieldAndSun")
    }

    // MARK: – Resilience

    @Test("Unknown persisted theme ID falls back to the default theme")
    func unknownPersistedIdFallsBack() {
        let defaults = freshDefaults()
        defaults.set("nonExistentTheme", forKey: "activeThemeId")
        let manager = ThemeManager(defaults: defaults)
        #expect(manager.current.id == AppTheme.defaultTheme.id)
    }

    // MARK: – Theme catalog invariants

    @Test("All themes have unique IDs")
    func allThemesHaveUniqueIds() {
        let ids = AppTheme.allThemes.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test("All themes have unique display names")
    func allThemesHaveUniqueNames() {
        let names = AppTheme.allThemes.map(\.name)
        #expect(names.count == Set(names).count)
    }

    @Test("The default theme is included in allThemes")
    func defaultThemeInCatalog() {
        #expect(AppTheme.allThemes.contains(where: { $0.id == AppTheme.defaultTheme.id }))
    }

    @Test("allThemes has at least two entries (extensibility baseline)")
    func catalogHasMultipleThemes() {
        #expect(AppTheme.allThemes.count >= 2)
    }

    @Test("fieldAndSun and nightMatch are both present in allThemes")
    func namedThemesPresent() {
        let ids = Set(AppTheme.allThemes.map(\.id))
        #expect(ids.contains("fieldAndSun"))
        #expect(ids.contains("nightMatch"))
    }

    // MARK: – Switching back and forth

    @Test("Switching themes multiple times always reflects the latest selection")
    func multipleSelections() {
        let manager = ThemeManager(defaults: freshDefaults())
        manager.select(.nightMatch)
        #expect(manager.current.id == "nightMatch")
        manager.select(.fieldAndSun)
        #expect(manager.current.id == "fieldAndSun")
        manager.select(.nightMatch)
        #expect(manager.current.id == "nightMatch")
    }
}
