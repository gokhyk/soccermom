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

        // Auto-select starters from available players, ranked by least season credited time.
        let candidates = rows
            .filter { $0.status == .available }
            .map { GameStartLogic.StarterCandidate(
                id: $0.player.id,
                seasonCreditedSeconds: $0.player.seasonCreditedSeconds,
                eligiblePositions: $0.player.eligiblePositions
            )}
        let assignments = GameStartLogic.autoSelectStarters(from: candidates, count: game.playersOnField)
        let starterPositions = Dictionary(uniqueKeysWithValues: assignments)

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

            // Upsert PlayerGameAppearance.
            // Absent: credited at target. Starters: on field. Remaining available: bench.
            let creditedSeconds = row.status == .available ? 0 : target
            let positionAssigned = starterPositions[row.player.id]
            let fieldStatus: OnFieldStatus = row.status == .available
                ? (positionAssigned != nil ? .onField : .bench)
                : .absent

            if let existing = game.appearances.first(where: { $0.player?.id == row.player.id }) {
                existing.secondsCredited   = creditedSeconds
                existing.onFieldStatus     = fieldStatus
                existing.positionAssigned  = positionAssigned
            } else {
                let appearance = PlayerGameAppearance(
                    secondsPlayed: 0,
                    secondsCredited: creditedSeconds,
                    onFieldStatus: fieldStatus,
                    positionAssigned: positionAssigned
                )
                appearance.player = row.player
                appearance.game   = game
                context.insert(appearance)
            }
        }

        game.status = .inProgress
        try? context.save()
    }
}
