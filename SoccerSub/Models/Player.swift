import SwiftData
import Foundation

@Model
final class Player {
    var id: UUID
    var name: String
    var jerseyNumber: Int
    var canPlayGoalkeeper: Bool
    var canPlayDefender: Bool
    var canPlayMidfielder: Bool
    var canPlayAttacker: Bool
    var seasonPlayedSeconds: Int
    var seasonCreditedSeconds: Int

    // Inverse of Team.players; SwiftData infers the back-link from @Relationship on Team.
    var team: Team?

    @Relationship(deleteRule: .cascade, inverse: \PlayerGameAppearance.player)
    var appearances: [PlayerGameAppearance]

    init(
        id: UUID = UUID(),
        name: String,
        jerseyNumber: Int,
        canPlayGoalkeeper: Bool = true,
        canPlayDefender: Bool = true,
        canPlayMidfielder: Bool = true,
        canPlayAttacker: Bool = true,
        seasonPlayedSeconds: Int = 0,
        seasonCreditedSeconds: Int = 0
    ) {
        self.id = id
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.canPlayGoalkeeper = canPlayGoalkeeper
        self.canPlayDefender = canPlayDefender
        self.canPlayMidfielder = canPlayMidfielder
        self.canPlayAttacker = canPlayAttacker
        self.seasonPlayedSeconds = seasonPlayedSeconds
        self.seasonCreditedSeconds = seasonCreditedSeconds
        self.appearances = []
    }
}
