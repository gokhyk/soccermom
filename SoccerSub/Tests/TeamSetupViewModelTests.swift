import Testing
import Foundation
import SwiftData
@testable import SoccerSub

@MainActor
struct TeamSetupViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Player.self, Game.self, Availability.self, PlayerGameAppearance.self,
            configurations: config
        )
    }

    // MARK: Age-group defaulting

    @Test("Selecting U6 populates all four defaults")
    func selectU6PopulatesDefaults() {
        let vm = TeamSetupViewModel()
        vm.selectAgeGroup("U6")
        #expect(vm.ageGroup == "U6")
        #expect(vm.playersOnField == 4)
        #expect(vm.numberOfPeriods == 4)
        #expect(vm.periodDurationSeconds == 480)
        #expect(vm.breakDurationSeconds == 120)
    }

    @Test("Selecting U12 populates all four defaults")
    func selectU12PopulatesDefaults() {
        let vm = TeamSetupViewModel()
        vm.selectAgeGroup("U12")
        #expect(vm.playersOnField == 9)
        #expect(vm.numberOfPeriods == 2)
        #expect(vm.periodDurationSeconds == 1800)
        #expect(vm.breakDurationSeconds == 300)
    }

    @Test("Selecting U16/U19 populates all four defaults")
    func selectU16u19PopulatesDefaults() {
        let vm = TeamSetupViewModel()
        vm.selectAgeGroup("U16/U19")
        #expect(vm.playersOnField == 11)
        #expect(vm.periodDurationSeconds == 2400)
        #expect(vm.breakDurationSeconds == 600)
    }

    // MARK: Manual edits are preserved until age group changes

    @Test("Manual edits after selectAgeGroup are preserved")
    func manualEditsPreservedAfterSelection() {
        let vm = TeamSetupViewModel()
        vm.selectAgeGroup("U10")
        vm.playersOnField = 8          // nudge from default 7
        vm.periodDurationSeconds = 1800 // nudge from default 1500

        #expect(vm.playersOnField == 8)
        #expect(vm.periodDurationSeconds == 1800)
        // age group and other fields unchanged
        #expect(vm.ageGroup == "U10")
        #expect(vm.numberOfPeriods == 2)
    }

    @Test("Changing age group overrides manual edits with new defaults")
    func changingAgeGroupResetsManualEdits() {
        let vm = TeamSetupViewModel()
        vm.selectAgeGroup("U10")
        vm.playersOnField = 8  // manual edit
        vm.selectAgeGroup("U12")  // switch → should reset to U12 defaults
        #expect(vm.playersOnField == 9)   // U12 default, not the manual 8
        #expect(vm.numberOfPeriods == 2)
        #expect(vm.periodDurationSeconds == 1800)
    }

    @Test("Selecting the same age group twice is a no-op (manual edits survive)")
    func selectingSameAgeGroupPreservesEdits() {
        let vm = TeamSetupViewModel()
        vm.selectAgeGroup("U10")
        vm.playersOnField = 8  // manual nudge
        vm.selectAgeGroup("U10")  // same group — must not clobber the nudge
        #expect(vm.playersOnField == 8)
    }

    @Test("Selecting empty string does not apply defaults")
    func selectingEmptyStringNoDefaults() {
        let vm = TeamSetupViewModel()
        vm.selectAgeGroup("U10")
        let savedPlayers = vm.playersOnField
        vm.selectAgeGroup("")  // deselect — should not change numeric fields
        #expect(vm.playersOnField == savedPlayers)
        #expect(vm.ageGroup == "")
    }

    // MARK: isValid

    @Test("isValid is false when name is empty")
    func isValidFalseWhenNameEmpty() {
        let vm = TeamSetupViewModel()
        #expect(!vm.isValid)
    }

    @Test("isValid is true when name has content")
    func isValidTrueWithName() {
        let vm = TeamSetupViewModel()
        vm.name = "Tigers"
        #expect(vm.isValid)
    }

    @Test("isValid is false when name is whitespace-only")
    func isValidFalseForWhitespace() {
        let vm = TeamSetupViewModel()
        vm.name = "   "
        #expect(!vm.isValid)
    }

    // MARK: Save — create mode

    @Test("Save in create mode inserts exactly one Team with correct fields")
    func saveCreateMode() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let vm = TeamSetupViewModel()
        vm.name = "Storm"
        vm.leagueName = "City League"
        vm.selectAgeGroup("U10")
        vm.save(to: ctx)

        let teams = try ctx.fetch(FetchDescriptor<Team>())
        #expect(teams.count == 1)
        let t = try #require(teams.first)
        #expect(t.name == "Storm")
        #expect(t.leagueName == "City League")
        #expect(t.ageGroup == "U10")
        #expect(t.defaultPlayersOnField == 7)
        #expect(t.defaultNumberOfPeriods == 2)
        #expect(t.defaultPeriodDurationSeconds == 1500)
        #expect(t.defaultBreakDurationSeconds == 300)
    }

    @Test("Save with manually-nudged values stores the nudged values, not the age-group defaults")
    func saveStoresManualEdits() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let vm = TeamSetupViewModel()
        vm.name = "Rockets"
        vm.selectAgeGroup("U10")
        vm.playersOnField = 8        // nudge
        vm.periodDurationSeconds = 1800 // nudge
        vm.save(to: ctx)

        let t = try #require(try ctx.fetch(FetchDescriptor<Team>()).first)
        #expect(t.defaultPlayersOnField == 8)
        #expect(t.defaultPeriodDurationSeconds == 1800)
    }

    @Test("Save does nothing when name is invalid")
    func saveNoOpWhenInvalid() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let vm = TeamSetupViewModel()
        vm.name = ""
        vm.save(to: ctx)

        let teams = try ctx.fetch(FetchDescriptor<Team>())
        #expect(teams.isEmpty)
    }

    // MARK: Save — edit mode

    @Test("Save in edit mode updates the existing Team, does not create a new one")
    func saveEditMode() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let existing = Team(name: "Old Name", leagueName: "Old League", ageGroup: "U8")
        ctx.insert(existing)
        try ctx.save()

        let vm = TeamSetupViewModel(editing: existing)
        vm.name = "New Name"
        vm.leagueName = "New League"
        vm.selectAgeGroup("U12")
        vm.save(to: ctx)

        let teams = try ctx.fetch(FetchDescriptor<Team>())
        #expect(teams.count == 1)          // still exactly one team
        #expect(teams.first?.name == "New Name")
        #expect(teams.first?.leagueName == "New League")
        #expect(teams.first?.ageGroup == "U12")
        #expect(teams.first?.defaultPlayersOnField == 9)
        #expect(teams.first?.defaultPeriodDurationSeconds == 1800)
    }

    // MARK: Edit-mode loading

    @Test("Edit mode loads all stored values, including customized ones")
    func editModeLoadsStoredValues() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let team = Team(
            name: "Rockets",
            leagueName: "Youth League",
            ageGroup: "U14",
            defaultPlayersOnField: 10,       // customized from U14's 11
            defaultNumberOfPeriods: 4,        // non-default
            defaultPeriodDurationSeconds: 1800, // customized
            defaultBreakDurationSeconds: 300
        )
        ctx.insert(team)

        let vm = TeamSetupViewModel(editing: team)
        #expect(vm.name == "Rockets")
        #expect(vm.leagueName == "Youth League")
        #expect(vm.ageGroup == "U14")
        #expect(vm.playersOnField == 10)        // stored custom, not U14 default (11)
        #expect(vm.numberOfPeriods == 4)
        #expect(vm.periodDurationSeconds == 1800)
    }

    @Test("Edit mode: isEditingExisting is true; create mode: false")
    func isEditingExistingFlag() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let team = Team(name: "X")
        ctx.insert(team)

        let createVM = TeamSetupViewModel()
        let editVM = TeamSetupViewModel(editing: team)

        #expect(!createVM.isEditingExisting)
        #expect(editVM.isEditingExisting)
    }
}
