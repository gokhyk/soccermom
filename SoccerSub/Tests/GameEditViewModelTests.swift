import Testing
import Foundation
import SwiftData
@testable import SoccerSub

@MainActor
struct GameEditViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Player.self, Game.self, Availability.self, PlayerGameAppearance.self,
            configurations: config
        )
    }

    // Convenience: insert a team with custom game defaults.
    private func makeTeam(
        playersOnField: Int = 9,
        numberOfPeriods: Int = 2,
        periodDurationSeconds: Int = 1800,
        breakDurationSeconds: Int = 300,
        ctx: ModelContext
    ) throws -> Team {
        let team = Team(
            name: "Tigers",
            defaultPlayersOnField: playersOnField,
            defaultNumberOfPeriods: numberOfPeriods,
            defaultPeriodDurationSeconds: periodDurationSeconds,
            defaultBreakDurationSeconds: breakDurationSeconds
        )
        ctx.insert(team)
        try ctx.save()
        return team
    }

    // MARK: – Create mode: inheriting team defaults

    @Test("New game seeds playersOnField from team default")
    func newGameInheritsPlayersOnField() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(playersOnField: 9, ctx: ctx)

        let vm = GameEditViewModel(team: team)
        #expect(vm.playersOnField == 9)
    }

    @Test("New game seeds all four rule fields from team defaults")
    func newGameInheritsAllTeamDefaults() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(
            playersOnField: 11,
            numberOfPeriods: 4,
            periodDurationSeconds: 2400,
            breakDurationSeconds: 600,
            ctx: ctx
        )

        let vm = GameEditViewModel(team: team)
        #expect(vm.playersOnField       == 11)
        #expect(vm.numberOfPeriods      == 4)
        #expect(vm.periodDurationSeconds == 2400)
        #expect(vm.breakDurationSeconds  == 600)
    }

    @Test("New game without a team falls back to AgeGroupDefaults.fallback")
    func newGameNoTeamUsesFallback() {
        let vm = GameEditViewModel()
        let f = AgeGroupDefaults.fallback
        #expect(vm.playersOnField       == f.playersOnField)
        #expect(vm.numberOfPeriods      == f.numberOfPeriods)
        #expect(vm.periodDurationSeconds == f.periodDurationSeconds)
        #expect(vm.breakDurationSeconds  == f.breakDurationSeconds)
    }

    // MARK: – Create mode: saving

    @Test("Save creates a game with the correct opponent and attaches it to the team")
    func saveCreatesGameWithOpponent() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(ctx: ctx)

        let vm = GameEditViewModel(team: team)
        vm.opponent = "Wolves"
        vm.field    = "Park Field 1"
        vm.save(to: ctx)

        let games = try ctx.fetch(FetchDescriptor<Game>())
        #expect(games.count == 1)
        let g = try #require(games.first)
        #expect(g.opponent == "Wolves")
        #expect(g.field    == "Park Field 1")
        #expect(team.games.contains(where: { $0.opponent == "Wolves" }))
    }

    @Test("Save persists the date/time correctly")
    func savePersistsDateTime() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(ctx: ctx)
        let target = Date(timeIntervalSince1970: 1_700_000_000)

        let vm = GameEditViewModel(team: team)
        vm.opponent = "Bears"
        vm.dateTime = target
        vm.save(to: ctx)

        let g = try #require(try ctx.fetch(FetchDescriptor<Game>()).first)
        #expect(g.dateTime == target)
    }

    @Test("Empty address field saves as nil")
    func emptyAddressSavesAsNil() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(ctx: ctx)

        let vm = GameEditViewModel(team: team)
        vm.opponent = "Eagles"
        vm.address  = ""
        vm.save(to: ctx)

        let g = try #require(try ctx.fetch(FetchDescriptor<Game>()).first)
        #expect(g.address == nil)
    }

    @Test("Non-empty address field saves as the trimmed string")
    func nonEmptyAddressSaved() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(ctx: ctx)

        let vm = GameEditViewModel(team: team)
        vm.opponent = "Hawks"
        vm.address  = "  123 Main St  "
        vm.save(to: ctx)

        let g = try #require(try ctx.fetch(FetchDescriptor<Game>()).first)
        #expect(g.address == "123 Main St")
    }

    @Test("Save does nothing when opponent is empty")
    func saveNoOpWithEmptyOpponent() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(ctx: ctx)

        let vm = GameEditViewModel(team: team)
        vm.opponent = ""
        vm.save(to: ctx)

        #expect(try ctx.fetch(FetchDescriptor<Game>()).isEmpty)
    }

    @Test("Save does nothing when opponent is whitespace-only")
    func saveNoOpWithWhitespaceOpponent() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(ctx: ctx)

        let vm = GameEditViewModel(team: team)
        vm.opponent = "   "
        vm.save(to: ctx)

        #expect(try ctx.fetch(FetchDescriptor<Game>()).isEmpty)
    }

    // MARK: – Edit mode: overrides don't bleed elsewhere

    @Test("Editing a game's rule overrides does not change the team's defaults")
    func editGameDoesNotAffectTeamDefaults() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(playersOnField: 9, ctx: ctx)

        let game = Game(opponent: "Comets", playersOnField: 9)
        ctx.insert(game)
        team.games.append(game)
        try ctx.save()

        // Edit the game's players-on-field override
        let vm = GameEditViewModel(editing: game, team: team)
        vm.playersOnField = 7   // tournament rule change
        vm.save(to: ctx)

        #expect(game.playersOnField == 7)           // game updated
        #expect(team.defaultPlayersOnField == 9)    // team unchanged
    }

    @Test("Editing one game's overrides does not affect another game's overrides")
    func editOneGameDoesNotAffectOtherGame() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(periodDurationSeconds: 1800, ctx: ctx)

        let gameA = Game(opponent: "A", periodDurationSeconds: 1800)
        let gameB = Game(opponent: "B", periodDurationSeconds: 1800)
        ctx.insert(gameA); ctx.insert(gameB)
        team.games.append(contentsOf: [gameA, gameB])
        try ctx.save()

        let vm = GameEditViewModel(editing: gameA, team: team)
        vm.periodDurationSeconds = 2400   // tournament override for game A only
        vm.save(to: ctx)

        #expect(gameA.periodDurationSeconds == 2400)   // game A changed
        #expect(gameB.periodDurationSeconds == 1800)   // game B untouched
        #expect(team.defaultPeriodDurationSeconds == 1800) // team untouched
    }

    @Test("Edit mode loads the game's own override values, not the team's current defaults")
    func editModeLoadsGameValues() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(playersOnField: 9, ctx: ctx)

        // Game was customized at creation: 7 players, tournament rules
        let game = Game(
            opponent: "Storm",
            field: "Stadium",
            address: "1 Stadium Way",
            playersOnField: 7,
            numberOfPeriods: 4,
            periodDurationSeconds: 1200,
            breakDurationSeconds: 120
        )
        ctx.insert(game); team.games.append(game); try ctx.save()

        let vm = GameEditViewModel(editing: game, team: team)
        #expect(vm.opponent              == "Storm")
        #expect(vm.field                 == "Stadium")
        #expect(vm.address               == "1 Stadium Way")
        #expect(vm.playersOnField        == 7)   // game's override, not team's 9
        #expect(vm.numberOfPeriods       == 4)
        #expect(vm.periodDurationSeconds == 1200)
        #expect(vm.breakDurationSeconds  == 120)
        #expect(vm.isEditingExisting)
    }

    @Test("Save in edit mode updates the game, does not create a new one")
    func saveEditModeUpdatesExisting() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = try makeTeam(ctx: ctx)

        let game = Game(opponent: "Old Opponent")
        ctx.insert(game); team.games.append(game); try ctx.save()

        let vm = GameEditViewModel(editing: game, team: team)
        vm.opponent = "New Opponent"
        vm.playersOnField = 11
        vm.save(to: ctx)

        let games = try ctx.fetch(FetchDescriptor<Game>())
        #expect(games.count == 1)
        #expect(games.first?.opponent == "New Opponent")
        #expect(games.first?.playersOnField == 11)
    }

    // MARK: – GameSorting

    @Test("In-progress game appears before scheduled games")
    func inProgressBeforeScheduled() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let scheduled  = Game(opponent: "Sched",    dateTime: base,             status: .scheduled)
        let inProgress = Game(opponent: "InProg",   dateTime: base.addingTimeInterval(3600), status: .inProgress)
        [scheduled, inProgress].forEach { ctx.insert($0) }

        let sorted = GameSorting.sorted([scheduled, inProgress])
        #expect(sorted[0].opponent == "InProg")
        #expect(sorted[1].opponent == "Sched")
    }

    @Test("Scheduled games are sorted ascending by date (soonest first)")
    func scheduledGamesSortedAscending() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let early  = Game(opponent: "Early",  dateTime: base,                          status: .scheduled)
        let middle = Game(opponent: "Middle", dateTime: base.addingTimeInterval(86400), status: .scheduled)
        let late   = Game(opponent: "Late",   dateTime: base.addingTimeInterval(172800), status: .scheduled)
        [late, early, middle].forEach { ctx.insert($0) }

        let sorted = GameSorting.sorted([late, early, middle])
        #expect(sorted.map(\.opponent) == ["Early", "Middle", "Late"])
    }

    @Test("Completed games appear after scheduled games")
    func completedAfterScheduled() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let upcoming  = Game(opponent: "Upcoming",  dateTime: base.addingTimeInterval(86400), status: .scheduled)
        let completed = Game(opponent: "Completed", dateTime: base,                           status: .completed)
        [completed, upcoming].forEach { ctx.insert($0) }

        let sorted = GameSorting.sorted([completed, upcoming])
        #expect(sorted[0].opponent == "Upcoming")
        #expect(sorted[1].opponent == "Completed")
    }

    @Test("Completed games are sorted descending by date (most recent first)")
    func completedGamesSortedDescending() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let oldest  = Game(opponent: "Oldest",  dateTime: base,                          status: .completed)
        let middle  = Game(opponent: "Middle",  dateTime: base.addingTimeInterval(86400), status: .completed)
        let newest  = Game(opponent: "Newest",  dateTime: base.addingTimeInterval(172800), status: .completed)
        [oldest, middle, newest].forEach { ctx.insert($0) }

        let sorted = GameSorting.sorted([oldest, middle, newest])
        #expect(sorted.map(\.opponent) == ["Newest", "Middle", "Oldest"])
    }

    @Test("Full mixed sort: inProgress → scheduled asc → completed desc")
    func fullMixedSort() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let games: [Game] = [
            Game(opponent: "C2", dateTime: base.addingTimeInterval(-86400), status: .completed),
            Game(opponent: "S1", dateTime: base.addingTimeInterval(86400),  status: .scheduled),
            Game(opponent: "IP", dateTime: base,                            status: .inProgress),
            Game(opponent: "C1", dateTime: base,                            status: .completed),
            Game(opponent: "S2", dateTime: base.addingTimeInterval(172800), status: .scheduled),
        ]
        games.forEach { ctx.insert($0) }

        let sorted = GameSorting.sorted(games)
        #expect(sorted.map(\.opponent) == ["IP", "S1", "S2", "C1", "C2"])
    }
}
