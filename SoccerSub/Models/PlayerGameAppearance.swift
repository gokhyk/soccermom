import SwiftData
import Foundation

@Model
final class PlayerGameAppearance {
    var id: UUID
    var secondsPlayed: Int
    var secondsCredited: Int
    var onFieldStatus: OnFieldStatus
    var positionAssigned: Position?

    // Inverse of Game.appearances
    var game: Game?
    // Inverse of Player.appearances
    var player: Player?

    init(
        id: UUID = UUID(),
        secondsPlayed: Int = 0,
        secondsCredited: Int = 0,
        onFieldStatus: OnFieldStatus = .bench,
        positionAssigned: Position? = nil
    ) {
        self.id = id
        self.secondsPlayed = secondsPlayed
        self.secondsCredited = secondsCredited
        self.onFieldStatus = onFieldStatus
        self.positionAssigned = positionAssigned
    }
}
