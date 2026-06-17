import Foundation
import Observation
import SwiftData

@Observable
final class AvailabilityViewModel {

    struct PlayerRow: Identifiable {
        let player: Player
        var status: AvailabilityStatus
        var id: UUID { player.id }
    }

    var rows: [PlayerRow]
    var substitutionFrequency: SubstitutionFrequency

    @ObservationIgnored let game: Game
    @ObservationIgnored private let clock: () -> Date

    var availableCount: Int {
        rows.filter { $0.status == .available }.count
    }

    var targetSecondsPerPlayer: Int {
        GameStartLogic.targetSeconds(
            periodDurationSeconds: game.periodDurationSeconds,
            numberOfPeriods: game.numberOfPeriods,
            playersOnField: game.playersOnField,
            availableCount: availableCount
        )
    }

    var isMismatch: Bool {
        GameStartLogic.isDateMismatch(scheduledDate: game.dateTime, now: clock())
    }

    /// True only when the game has not yet been started.
    var canStart: Bool { game.status == .scheduled }

    // MARK: Init

    /// `clock` is injectable for testing. Defaults to the system clock.
    init(game: Game, clock: @escaping () -> Date = { .now }) {
        self.game = game
        self.substitutionFrequency = game.substitutionFrequency
        self.clock = clock

        // Seed from any Availability records already persisted for this game.
        let existing: [UUID: AvailabilityStatus] = Dictionary(
            uniqueKeysWithValues: game.availabilities.compactMap { avail in
                guard let player = avail.player else { return nil }
                return (player.id, avail.status)
            }
        )

        let players = (game.team?.players ?? []).sorted { $0.jerseyNumber < $1.jerseyNumber }
        self.rows = players.map { player in
            PlayerRow(player: player, status: existing[player.id] ?? .available)
        }
    }

    // MARK: Start game

    func startGame(context: ModelContext) {
        guard canStart else { return }

        // Snapshot target before saving (availableCount may shift during the loop).
        let target = targetSecondsPerPlayer
        game.substitutionFrequency = substitutionFrequency

        for row in rows {
            // Upsert Availability
            if let existing = game.availabilities.first(where: { $0.player?.id == row.player.id }) {
                existing.status = row.status
            } else {
                let avail = Availability(status: row.status)
                avail.player = row.player
                avail.game = game
                context.insert(avail)
            }

            // Upsert PlayerGameAppearance
            // Absent players: secondsCredited fixed at target; available: starts at 0 (updates live).
            let creditedSeconds = row.status == .available ? 0 : target
            let fieldStatus: OnFieldStatus = row.status == .available ? .bench : .absent

            if let existing = game.appearances.first(where: { $0.player?.id == row.player.id }) {
                existing.secondsCredited = creditedSeconds
                existing.onFieldStatus = fieldStatus
            } else {
                let appearance = PlayerGameAppearance(
                    secondsPlayed: 0,
                    secondsCredited: creditedSeconds,
                    onFieldStatus: fieldStatus
                )
                appearance.player = row.player
                appearance.game = game
                context.insert(appearance)
            }
        }

        game.status = .inProgress
        try? context.save()
    }
}
