import Foundation
import Observation
import SwiftData

/// Jersey-number uniqueness rule:
/// A jersey number must be ≥ 1 and unique within the team.
/// When editing an existing player the player's own current number is excluded
/// from the uniqueness check so they can keep their number unchanged.
@Observable
final class PlayerEditViewModel {
    var name: String = ""
    var jerseyNumberText: String = ""
    var canPlayGoalkeeper: Bool = true
    var canPlayDefender: Bool    = true
    var canPlayMidfielder: Bool  = true
    var canPlayAttacker: Bool    = true

    @ObservationIgnored private let editingPlayer: Player?
    @ObservationIgnored private let team: Team?

    // Team resolved from the player being edited (if any) or the one passed in.
    private var contextTeam: Team? { editingPlayer?.team ?? team }

    var isEditingExisting: Bool { editingPlayer != nil }

    var seasonPlayedDisplay: String {
        TimeFormatting.format(editingPlayer?.seasonPlayedSeconds ?? 0)
    }

    // MARK: Validation

    var nameValidationError: String? {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Name is required" : nil
    }

    var jerseyValidationError: String? {
        let trimmed = jerseyNumberText.trimmingCharacters(in: .whitespaces)
        guard let number = Int(trimmed) else {
            return trimmed.isEmpty ? "Jersey number is required" : "Jersey number must be a whole number"
        }
        guard number >= 1 else { return "Jersey number must be at least 1" }
        if let t = contextTeam {
            let taken = t.players.contains { $0.jerseyNumber == number && $0 !== editingPlayer }
            if taken { return "Number \(number) is already taken on this team" }
        }
        return nil
    }

    var isValid: Bool { nameValidationError == nil && jerseyValidationError == nil }

    /// Non-nil when there is at least one validation error; used by the view.
    var validationSummary: String? {
        let errors = [nameValidationError, jerseyValidationError].compactMap { $0 }
        return errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    // MARK: Init

    init(editing player: Player? = nil, inTeam team: Team? = nil) {
        self.editingPlayer = player
        self.team = team
        guard let player else { return }
        name               = player.name
        jerseyNumberText   = String(player.jerseyNumber)
        canPlayGoalkeeper  = player.canPlayGoalkeeper
        canPlayDefender    = player.canPlayDefender
        canPlayMidfielder  = player.canPlayMidfielder
        canPlayAttacker    = player.canPlayAttacker
    }

    // MARK: Save

    func save(to context: ModelContext) {
        guard isValid, let number = Int(jerseyNumberText.trimmingCharacters(in: .whitespaces)) else { return }
        if let player = editingPlayer {
            player.name              = name
            player.jerseyNumber      = number
            player.canPlayGoalkeeper = canPlayGoalkeeper
            player.canPlayDefender   = canPlayDefender
            player.canPlayMidfielder = canPlayMidfielder
            player.canPlayAttacker   = canPlayAttacker
        } else {
            let player = Player(
                name: name,
                jerseyNumber: number,
                canPlayGoalkeeper: canPlayGoalkeeper,
                canPlayDefender:   canPlayDefender,
                canPlayMidfielder: canPlayMidfielder,
                canPlayAttacker:   canPlayAttacker
            )
            context.insert(player)
            contextTeam?.players.append(player)
        }
        try? context.save()
    }
}
