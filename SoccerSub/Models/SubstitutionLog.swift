import SwiftData
import Foundation

@Model
final class SubstitutionLog {
    var id: UUID
    var elapsedPeriodSeconds: Int
    var period: Int
    var reason: SubstitutionReason

    var game: Game?
    var playerOut: Player?
    var playerIn: Player?

    init(
        id: UUID = UUID(),
        elapsedPeriodSeconds: Int,
        period: Int,
        reason: SubstitutionReason = .scheduled
    ) {
        self.id = id
        self.elapsedPeriodSeconds = elapsedPeriodSeconds
        self.period = period
        self.reason = reason
    }
}
