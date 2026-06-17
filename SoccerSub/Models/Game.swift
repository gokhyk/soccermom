import SwiftData
import Foundation

@Model
final class Game {
    var id: UUID
    var opponent: String
    var field: String
    var address: String?
    var dateTime: Date
    var playersOnField: Int
    var numberOfPeriods: Int
    var periodDurationSeconds: Int
    var breakDurationSeconds: Int
    var substitutionFrequency: SubstitutionFrequency
    var status: GameStatus

    // Inverse of Team.games
    var team: Team?

    @Relationship(deleteRule: .cascade, inverse: \Availability.game)
    var availabilities: [Availability]

    @Relationship(deleteRule: .cascade, inverse: \PlayerGameAppearance.game)
    var appearances: [PlayerGameAppearance]

    @Relationship(deleteRule: .cascade, inverse: \SubstitutionLog.game)
    var substitutionLogs: [SubstitutionLog]

    init(
        id: UUID = UUID(),
        opponent: String,
        field: String = "",
        address: String? = nil,
        dateTime: Date = .now,
        playersOnField: Int = 7,
        numberOfPeriods: Int = 2,
        periodDurationSeconds: Int = 1500,
        breakDurationSeconds: Int = 300,
        substitutionFrequency: SubstitutionFrequency = .normal,
        status: GameStatus = .scheduled
    ) {
        self.id = id
        self.opponent = opponent
        self.field = field
        self.address = address
        self.dateTime = dateTime
        self.playersOnField = playersOnField
        self.numberOfPeriods = numberOfPeriods
        self.periodDurationSeconds = periodDurationSeconds
        self.breakDurationSeconds = breakDurationSeconds
        self.substitutionFrequency = substitutionFrequency
        self.status = status
        self.availabilities = []
        self.appearances = []
        self.substitutionLogs = []
    }
}
