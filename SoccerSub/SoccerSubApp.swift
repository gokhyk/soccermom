import SwiftUI
import SwiftData

@main
struct SoccerSubApp: App {
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
    }
}
