import Foundation
import Observation
import SwiftData

@Observable
final class GameEditViewModel {
    var opponent: String = ""
    var field: String = ""
    var address: String = ""          // empty string → stored as nil
    var dateTime: Date = .now
    var playersOnField: Int
    var numberOfPeriods: Int
    var periodDurationSeconds: Int
    var breakDurationSeconds: Int

    @ObservationIgnored private let editingGame: Game?
    @ObservationIgnored private let team: Team?

    var isEditingExisting: Bool { editingGame != nil }
    var isValid: Bool { !opponent.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: Init

    init(editing game: Game? = nil, team: Team? = nil) {
        self.editingGame = game
        self.team = team

        if let game {
            opponent             = game.opponent
            field                = game.field
            address              = game.address ?? ""
            dateTime             = game.dateTime
            playersOnField       = game.playersOnField
            numberOfPeriods      = game.numberOfPeriods
            periodDurationSeconds = game.periodDurationSeconds
            breakDurationSeconds  = game.breakDurationSeconds
        } else {
            // Seed from team defaults; fall back to AgeGroupDefaults if no team.
            let f = AgeGroupDefaults.fallback
            playersOnField       = team?.defaultPlayersOnField       ?? f.playersOnField
            numberOfPeriods      = team?.defaultNumberOfPeriods      ?? f.numberOfPeriods
            periodDurationSeconds = team?.defaultPeriodDurationSeconds ?? f.periodDurationSeconds
            breakDurationSeconds  = team?.defaultBreakDurationSeconds  ?? f.breakDurationSeconds
        }
    }

    // MARK: Save

    func save(to context: ModelContext) {
        guard isValid else { return }

        let resolvedAddress: String? = address.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : address.trimmingCharacters(in: .whitespaces)

        if let game = editingGame {
            game.opponent             = opponent
            game.field                = field
            game.address              = resolvedAddress
            game.dateTime             = dateTime
            game.playersOnField       = playersOnField
            game.numberOfPeriods      = numberOfPeriods
            game.periodDurationSeconds = periodDurationSeconds
            game.breakDurationSeconds  = breakDurationSeconds
        } else {
            let game = Game(
                opponent:             opponent,
                field:                field,
                address:              resolvedAddress,
                dateTime:             dateTime,
                playersOnField:       playersOnField,
                numberOfPeriods:      numberOfPeriods,
                periodDurationSeconds: periodDurationSeconds,
                breakDurationSeconds:  breakDurationSeconds
            )
            context.insert(game)
            team?.games.append(game)
        }
        try? context.save()
    }
}
