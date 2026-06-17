import SwiftUI
import SwiftData

@main
struct SoccerSubApp: App {
    @State private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Team.self,
            Player.self,
            Game.self,
            Availability.self,
            PlayerGameAppearance.self
        ])
        .environment(\.themeManager, themeManager)
    }
}
