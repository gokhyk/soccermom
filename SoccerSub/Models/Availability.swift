import SwiftData
import Foundation

@Model
final class Availability {
    var id: UUID
    var status: AvailabilityStatus

    // Inverse of Game.availabilities
    var game: Game?
    // Plain reference — nullify (default) when player is deleted
    var player: Player?

    init(
        id: UUID = UUID(),
        status: AvailabilityStatus = .available
    ) {
        self.id = id
        self.status = status
    }
}
