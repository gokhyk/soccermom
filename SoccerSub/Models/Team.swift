import SwiftData
import Foundation

@Model
final class Team {
    var id: UUID
    var name: String
    var leagueName: String
    var ageGroup: String
    var defaultPlayersOnField: Int
    var defaultNumberOfPeriods: Int
    var defaultPeriodDurationSeconds: Int
    var defaultBreakDurationSeconds: Int
    var colorThemeId: String

    @Relationship(deleteRule: .cascade, inverse: \Player.team)
    var players: [Player]

    @Relationship(deleteRule: .cascade, inverse: \Game.team)
    var games: [Game]

    init(
        id: UUID = UUID(),
        name: String,
        leagueName: String = "",
        ageGroup: String = "",
        defaultPlayersOnField: Int = 7,
        defaultNumberOfPeriods: Int = 2,
        defaultPeriodDurationSeconds: Int = 1500,
        defaultBreakDurationSeconds: Int = 300,
        colorThemeId: String = "default"
    ) {
        self.id = id
        self.name = name
        self.leagueName = leagueName
        self.ageGroup = ageGroup
        self.defaultPlayersOnField = defaultPlayersOnField
        self.defaultNumberOfPeriods = defaultNumberOfPeriods
        self.defaultPeriodDurationSeconds = defaultPeriodDurationSeconds
        self.defaultBreakDurationSeconds = defaultBreakDurationSeconds
        self.colorThemeId = colorThemeId
        self.players = []
        self.games = []
    }
}
