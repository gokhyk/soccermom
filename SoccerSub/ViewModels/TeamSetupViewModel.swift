import Foundation
import Observation
import SwiftData

@Observable
final class TeamSetupViewModel {
    var name: String
    var leagueName: String

    // private(set) forces callers to use selectAgeGroup() so defaults always apply.
    private(set) var ageGroup: String

    var playersOnField: Int
    var numberOfPeriods: Int
    var periodDurationSeconds: Int
    var breakDurationSeconds: Int

    // Not observed — constant after init.
    @ObservationIgnored private let editingTeam: Team?

    var isEditingExisting: Bool { editingTeam != nil }
    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    init(editing team: Team? = nil) {
        editingTeam = team
        let f = AgeGroupDefaults.fallback
        name                  = team?.name ?? ""
        leagueName            = team?.leagueName ?? ""
        ageGroup              = team?.ageGroup ?? ""
        playersOnField        = team?.defaultPlayersOnField ?? f.playersOnField
        numberOfPeriods       = team?.defaultNumberOfPeriods ?? f.numberOfPeriods
        periodDurationSeconds = team?.defaultPeriodDurationSeconds ?? f.periodDurationSeconds
        breakDurationSeconds  = team?.defaultBreakDurationSeconds ?? f.breakDurationSeconds
    }

    // Selects a new age group and, if it differs from the current one,
    // overwrites the four numeric fields with the table defaults.
    func selectAgeGroup(_ group: String) {
        guard group != ageGroup else { return }
        ageGroup = group
        guard !group.isEmpty else { return }
        let d = AgeGroupDefaults.defaults(for: group)
        playersOnField        = d.playersOnField
        numberOfPeriods       = d.numberOfPeriods
        periodDurationSeconds = d.periodDurationSeconds
        breakDurationSeconds  = d.breakDurationSeconds
    }

    func deleteTeam(from context: ModelContext) {
        guard let team = editingTeam else { return }
        context.delete(team)
        try? context.save()
    }

    func save(to context: ModelContext) {
        guard isValid else { return }
        if let team = editingTeam {
            team.name                        = name
            team.leagueName                  = leagueName
            team.ageGroup                    = ageGroup
            team.defaultPlayersOnField       = playersOnField
            team.defaultNumberOfPeriods      = numberOfPeriods
            team.defaultPeriodDurationSeconds = periodDurationSeconds
            team.defaultBreakDurationSeconds  = breakDurationSeconds
        } else {
            context.insert(Team(
                name: name,
                leagueName: leagueName,
                ageGroup: ageGroup,
                defaultPlayersOnField: playersOnField,
                defaultNumberOfPeriods: numberOfPeriods,
                defaultPeriodDurationSeconds: periodDurationSeconds,
                defaultBreakDurationSeconds: breakDurationSeconds
            ))
        }
        try? context.save()
    }
}
