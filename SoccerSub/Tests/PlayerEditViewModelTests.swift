import Testing
import Foundation
import SwiftData
@testable import SoccerSub

@MainActor
struct PlayerEditViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Player.self, Game.self, Availability.self, PlayerGameAppearance.self,
            configurations: config
        )
    }

    // Convenience: create a team with one inserted player already committed.
    private func makeTeamWithPlayer(
        playerName: String = "Alice",
        jerseyNumber: Int = 7,
        ctx: ModelContext
    ) throws -> (Team, Player) {
        let team = Team(name: "Tigers")
        let player = Player(name: playerName, jerseyNumber: jerseyNumber)
        ctx.insert(team)
        ctx.insert(player)
        team.players.append(player)
        try ctx.save()
        return (team, player)
    }

    // MARK: – Adding a player

    @Test("Save in create mode inserts a player with correct field values")
    func addPlayerPersistsCorrectly() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = Team(name: "Lions")
        ctx.insert(team)
        try ctx.save()

        let vm = PlayerEditViewModel(inTeam: team)
        vm.name             = "Bob"
        vm.jerseyNumberText = "10"
        vm.canPlayGoalkeeper = false    // deliberately off
        vm.save(to: ctx)

        let players = try ctx.fetch(FetchDescriptor<Player>())
        #expect(players.count == 1)
        let p = try #require(players.first)
        #expect(p.name == "Bob")
        #expect(p.jerseyNumber == 10)
        #expect(p.canPlayGoalkeeper  == false)
        #expect(p.canPlayDefender    == true)
        #expect(p.canPlayMidfielder  == true)
        #expect(p.canPlayAttacker    == true)
        #expect(p.seasonPlayedSeconds == 0)
        // Player is linked to team
        #expect(team.players.contains(where: { $0.name == "Bob" }))
    }

    // MARK: – Position toggling

    @Test("Toggling Goalkeeper off and saving preserves the other three positions")
    func toggleGoalkeeperOffPreservesOthers() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (team, player) = try makeTeamWithPlayer(ctx: ctx)

        let vm = PlayerEditViewModel(editing: player, inTeam: team)
        vm.canPlayGoalkeeper = false   // toggle off
        #expect(vm.canPlayDefender   == true)
        #expect(vm.canPlayMidfielder == true)
        #expect(vm.canPlayAttacker   == true)
        vm.save(to: ctx)

        let players = try ctx.fetch(FetchDescriptor<Player>())
        let saved = try #require(players.first)
        #expect(saved.canPlayGoalkeeper  == false)
        #expect(saved.canPlayDefender    == true)
        #expect(saved.canPlayMidfielder  == true)
        #expect(saved.canPlayAttacker    == true)
    }

    @Test("All four positions can be toggled independently")
    func allPositionsToggleIndependently() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (team, player) = try makeTeamWithPlayer(ctx: ctx)

        let vm = PlayerEditViewModel(editing: player, inTeam: team)
        vm.canPlayGoalkeeper  = false
        vm.canPlayDefender    = false
        vm.canPlayMidfielder  = true
        vm.canPlayAttacker    = false
        vm.save(to: ctx)

        let saved = try #require(try ctx.fetch(FetchDescriptor<Player>()).first)
        #expect(saved.canPlayGoalkeeper  == false)
        #expect(saved.canPlayDefender    == false)
        #expect(saved.canPlayMidfielder  == true)
        #expect(saved.canPlayAttacker    == false)
    }

    // MARK: – Jersey number validation

    @Test("Empty jersey number text is invalid")
    func emptyJerseyInvalid() {
        let vm = PlayerEditViewModel()
        vm.name = "Carol"
        vm.jerseyNumberText = ""
        #expect(vm.jerseyValidationError != nil)
        #expect(!vm.isValid)
    }

    @Test("Non-numeric jersey text is invalid")
    func nonNumericJerseyInvalid() {
        let vm = PlayerEditViewModel()
        vm.name = "Carol"
        vm.jerseyNumberText = "abc"
        #expect(vm.jerseyValidationError != nil)
    }

    @Test("Jersey number 0 is invalid")
    func jerseyZeroInvalid() {
        let vm = PlayerEditViewModel()
        vm.name = "Carol"
        vm.jerseyNumberText = "0"
        #expect(vm.jerseyValidationError != nil)
    }

    @Test("Negative jersey number is invalid")
    func jerseyNegativeInvalid() {
        let vm = PlayerEditViewModel()
        vm.name = "Carol"
        vm.jerseyNumberText = "-3"
        #expect(vm.jerseyValidationError != nil)
    }

    @Test("Jersey number 1 is valid (minimum allowed)")
    func jerseyOneValid() {
        let vm = PlayerEditViewModel()
        vm.name = "Carol"
        vm.jerseyNumberText = "1"
        #expect(vm.jerseyValidationError == nil)
        #expect(vm.isValid)
    }

    @Test("Duplicate jersey number within the same team is invalid")
    func duplicateJerseyInvalidOnSameTeam() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (team, _) = try makeTeamWithPlayer(jerseyNumber: 7, ctx: ctx)

        // New player trying to claim #7 — already taken
        let vm = PlayerEditViewModel(inTeam: team)
        vm.name = "Dave"
        vm.jerseyNumberText = "7"
        #expect(vm.jerseyValidationError != nil)
        #expect(!vm.isValid)
    }

    @Test("A different jersey number on the same team is valid")
    func differentJerseyValidOnSameTeam() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (team, _) = try makeTeamWithPlayer(jerseyNumber: 7, ctx: ctx)

        let vm = PlayerEditViewModel(inTeam: team)
        vm.name = "Dave"
        vm.jerseyNumberText = "10"
        #expect(vm.jerseyValidationError == nil)
        #expect(vm.isValid)
    }

    @Test("Editing a player with their own jersey number is valid (no self-conflict)")
    func editPlayerKeepingOwnNumber() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (team, player) = try makeTeamWithPlayer(jerseyNumber: 7, ctx: ctx)

        let vm = PlayerEditViewModel(editing: player, inTeam: team)
        vm.jerseyNumberText = "7"   // same as their own current number
        #expect(vm.jerseyValidationError == nil)
        #expect(vm.isValid)
    }

    @Test("Editing a player with another player's number on the same team is invalid")
    func editPlayerConflictingWithOtherNumber() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (team, player) = try makeTeamWithPlayer(playerName: "Alice", jerseyNumber: 7, ctx: ctx)

        let bob = Player(name: "Bob", jerseyNumber: 10)
        ctx.insert(bob)
        team.players.append(bob)
        try ctx.save()

        let vm = PlayerEditViewModel(editing: player, inTeam: team)
        vm.jerseyNumberText = "10"   // Bob's number — conflict
        #expect(vm.jerseyValidationError != nil)
    }

    // MARK: – Edit mode

    @Test("Edit mode loads existing player values")
    func editModeLoadsValues() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let team = Team(name: "Wolves")
        let player = Player(
            name: "Eve",
            jerseyNumber: 9,
            canPlayGoalkeeper: false,
            canPlayDefender: true,
            canPlayMidfielder: false,
            canPlayAttacker: true,
            seasonPlayedSeconds: 1530
        )
        ctx.insert(team); ctx.insert(player)
        team.players.append(player)

        let vm = PlayerEditViewModel(editing: player, inTeam: team)
        #expect(vm.name == "Eve")
        #expect(vm.jerseyNumberText == "9")
        #expect(vm.canPlayGoalkeeper  == false)
        #expect(vm.canPlayDefender    == true)
        #expect(vm.canPlayMidfielder  == false)
        #expect(vm.canPlayAttacker    == true)
        #expect(vm.isEditingExisting)
    }

    @Test("Save in edit mode updates the player, does not create a new one")
    func saveEditModeUpdatesExisting() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (team, player) = try makeTeamWithPlayer(playerName: "Old Name", jerseyNumber: 5, ctx: ctx)

        let vm = PlayerEditViewModel(editing: player, inTeam: team)
        vm.name = "New Name"
        vm.jerseyNumberText = "11"
        vm.canPlayGoalkeeper = false
        vm.save(to: ctx)

        let players = try ctx.fetch(FetchDescriptor<Player>())
        #expect(players.count == 1)              // still exactly one player
        #expect(players.first?.name == "New Name")
        #expect(players.first?.jerseyNumber == 11)
        #expect(players.first?.canPlayGoalkeeper == false)
    }

    // MARK: – seasonPlayedDisplay

    @Test("seasonPlayedDisplay delegates to TimeFormatting.format")
    func seasonPlayedDisplayFormatting() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let player = Player(name: "Frank", jerseyNumber: 3, seasonPlayedSeconds: 1530)
        ctx.insert(player)

        let vm = PlayerEditViewModel(editing: player)
        #expect(vm.seasonPlayedDisplay == "25m 30s")
    }

    @Test("seasonPlayedDisplay shows '0 min' for a player with no time played")
    func seasonPlayedDisplayZero() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let player = Player(name: "Grace", jerseyNumber: 4, seasonPlayedSeconds: 0)
        ctx.insert(player)

        let vm = PlayerEditViewModel(editing: player)
        #expect(vm.seasonPlayedDisplay == "0 min")
    }

    // MARK: – isValid guards

    @Test("Save does nothing when name is empty")
    func saveNoOpWithEmptyName() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = Team(name: "X")
        ctx.insert(team)

        let vm = PlayerEditViewModel(inTeam: team)
        vm.name = ""
        vm.jerseyNumberText = "1"
        vm.save(to: ctx)

        #expect(try ctx.fetch(FetchDescriptor<Player>()).isEmpty)
    }

    @Test("Save does nothing when jersey text is non-numeric")
    func saveNoOpWithBadJersey() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let team = Team(name: "X")
        ctx.insert(team)

        let vm = PlayerEditViewModel(inTeam: team)
        vm.name = "Hannah"
        vm.jerseyNumberText = "abc"
        vm.save(to: ctx)

        #expect(try ctx.fetch(FetchDescriptor<Player>()).isEmpty)
    }
}
