import Testing
import Foundation
import SwiftData
@testable import SoccerSub

@MainActor
struct AvailabilityViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Player.self, Game.self, Availability.self, PlayerGameAppearance.self,
            configurations: config
        )
    }

    /// Creates a team with `playerCount` players and one game, all inside `ctx`.
    private func makeSampleGame(
        playerCount: Int,
        playersOnField: Int = 7,
        periodDurationSeconds: Int = 1500,
        numberOfPeriods: Int = 2,
        dateTime: Date = .now,
        ctx: ModelContext
    ) throws -> (Game, [Player]) {
        let team = Team(
            name: "Test Team",
            defaultPlayersOnField: playersOnField,
            defaultNumberOfPeriods: numberOfPeriods,
            defaultPeriodDurationSeconds: periodDurationSeconds,
            defaultBreakDurationSeconds: 300
        )
        ctx.insert(team)

        var players: [Player] = []
        for i in 1...playerCount {
            let p = Player(name: "Player \(i)", jerseyNumber: i)
            ctx.insert(p)
            team.players.append(p)
            players.append(p)
        }

        let game = Game(
            opponent: "Opponent",
            dateTime: dateTime,
            playersOnField: playersOnField,
            numberOfPeriods: numberOfPeriods,
            periodDurationSeconds: periodDurationSeconds
        )
        ctx.insert(game)
        team.games.append(game)
        try ctx.save()
        return (game, players)
    }

    // MARK: – GameStartLogic: targetSeconds

    @Test("targetSeconds applies the formula correctly")
    func targetSecondsFormula() {
        // (1800 * 2 * 9) / 12 = 2700
        let result = GameStartLogic.targetSeconds(
            periodDurationSeconds: 1800,
            numberOfPeriods: 2,
            playersOnField: 9,
            availableCount: 12
        )
        #expect(result == 2700)
    }

    @Test("targetSeconds uses integer division (rounds down)")
    func targetSecondsRoundsDown() {
        // (1800 * 2 * 9) / 11 = 2945.45... → 2945
        let result = GameStartLogic.targetSeconds(
            periodDurationSeconds: 1800,
            numberOfPeriods: 2,
            playersOnField: 9,
            availableCount: 11
        )
        #expect(result == 2945)
    }

    @Test("targetSeconds returns 0 when availableCount is 0")
    func targetSecondsNoPlayersAvailable() {
        let result = GameStartLogic.targetSeconds(
            periodDurationSeconds: 1800,
            numberOfPeriods: 2,
            playersOnField: 9,
            availableCount: 0
        )
        #expect(result == 0)
    }

    // MARK: – GameStartLogic: date mismatch

    @Test("No mismatch when now equals scheduled time")
    func noMismatchExactTime() {
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(!GameStartLogic.isDateMismatch(scheduledDate: scheduled, now: scheduled))
    }

    @Test("No mismatch when now is 1 hour before game")
    func noMismatchOneHourBefore() {
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(!GameStartLogic.isDateMismatch(
            scheduledDate: scheduled,
            now: scheduled.addingTimeInterval(-3600)
        ))
    }

    @Test("No mismatch when now is 1 hour after game")
    func noMismatchOneHourAfter() {
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(!GameStartLogic.isDateMismatch(
            scheduledDate: scheduled,
            now: scheduled.addingTimeInterval(3600)
        ))
    }

    @Test("No mismatch at exactly the 4-hour boundary")
    func noMismatchAtWindowBoundary() {
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(!GameStartLogic.isDateMismatch(
            scheduledDate: scheduled,
            now: scheduled.addingTimeInterval(GameStartLogic.mismatchWindowSeconds)
        ))
    }

    @Test("Mismatch when now is 5 hours after scheduled time")
    func mismatchFiveHoursAfter() {
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(GameStartLogic.isDateMismatch(
            scheduledDate: scheduled,
            now: scheduled.addingTimeInterval(5 * 3600)
        ))
    }

    @Test("Mismatch when now is 5 hours before scheduled time")
    func mismatchFiveHoursBefore() {
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(GameStartLogic.isDateMismatch(
            scheduledDate: scheduled,
            now: scheduled.addingTimeInterval(-5 * 3600)
        ))
    }

    // MARK: – AvailabilityViewModel: initialization

    @Test("Rows count matches the team's player count")
    func rowsCountMatchesPlayers() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 4, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        #expect(vm.rows.count == 4)
    }

    @Test("All players default to available when no records exist")
    func allPlayersDefaultAvailable() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 3, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        #expect(vm.rows.allSatisfy { $0.status == .available })
    }

    @Test("Existing Availability records are loaded into rows")
    func existingAvailabilityLoadedIntoRows() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, players) = try makeSampleGame(playerCount: 3, ctx: ctx)

        let avail = Availability(status: .absent)
        avail.player = players[0]
        avail.game = game
        ctx.insert(avail)
        try ctx.save()

        let vm = AvailabilityViewModel(game: game)
        let absRow = vm.rows.first(where: { $0.player.id == players[0].id })
        let presentRow = vm.rows.first(where: { $0.player.id == players[1].id })
        #expect(absRow?.status == .absent)
        #expect(presentRow?.status == .available)
    }

    @Test("availableCount reflects current row statuses")
    func availableCountUpdatesWithStatuses() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 5, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.rows[0].status = .absent
        vm.rows[1].status = .absent
        #expect(vm.availableCount == 3)
    }

    // MARK: – AvailabilityViewModel: targetSecondsPerPlayer

    @Test("targetSecondsPerPlayer matches formula with all available")
    func targetSecondsAllAvailable() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        // 12 players, 9 on field, 2 × 1800 s → (1800 * 2 * 9) / 12 = 2700
        let (game, _) = try makeSampleGame(
            playerCount: 12, playersOnField: 9, periodDurationSeconds: 1800, numberOfPeriods: 2, ctx: ctx
        )

        let vm = AvailabilityViewModel(game: game)
        #expect(vm.targetSecondsPerPlayer == 2700)
    }

    @Test("targetSecondsPerPlayer recomputes when a player is marked absent")
    func targetSecondsUpdatesOnAbsent() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        // 12 → 2700; mark one absent → 11 available → (1800 * 2 * 9) / 11 = 2945
        let (game, _) = try makeSampleGame(
            playerCount: 12, playersOnField: 9, periodDurationSeconds: 1800, numberOfPeriods: 2, ctx: ctx
        )

        let vm = AvailabilityViewModel(game: game)
        #expect(vm.targetSecondsPerPlayer == 2700)
        vm.rows[0].status = .absent
        #expect(vm.targetSecondsPerPlayer == 2945)
    }

    // MARK: – AvailabilityViewModel: startGame

    @Test("startGame creates one Availability record per player")
    func startGameCreatesAvailabilityRecords() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 3, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.startGame(context: ctx)

        let all = try ctx.fetch(FetchDescriptor<Availability>())
        #expect(all.count == 3)
    }

    @Test("startGame persists correct status for each player")
    func startGamePersistsPlayerStatuses() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, players) = try makeSampleGame(playerCount: 3, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.rows[0].status = .absent
        vm.startGame(context: ctx)

        let all = try ctx.fetch(FetchDescriptor<Availability>())
        let absentRecord = all.first(where: { $0.player?.id == players[0].id })
        let presentRecord = all.first(where: { $0.player?.id == players[1].id })
        #expect(absentRecord?.status == .absent)
        #expect(presentRecord?.status == .available)
    }

    @Test("startGame creates one PlayerGameAppearance per player")
    func startGameCreatesAppearanceRecords() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 4, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.startGame(context: ctx)

        let all = try ctx.fetch(FetchDescriptor<PlayerGameAppearance>())
        #expect(all.count == 4)
    }

    @Test("Absent player gets secondsCredited = targetSeconds")
    func absentPlayerGetsCreditedTarget() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        // 12 players, mark first absent → 11 available → target = (1800*2*9)/11 = 2945
        let (game, players) = try makeSampleGame(
            playerCount: 12, playersOnField: 9, periodDurationSeconds: 1800, numberOfPeriods: 2, ctx: ctx
        )

        let vm = AvailabilityViewModel(game: game)
        vm.rows[0].status = .absent
        vm.startGame(context: ctx)

        let appearance = game.appearances.first(where: { $0.player?.id == players[0].id })
        #expect(appearance?.secondsCredited == 2945)
        #expect(appearance?.onFieldStatus == .absent)
    }

    @Test("Available player gets secondsCredited = 0 at game start")
    func availablePlayerGetsCreditedZero() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        // 10 players, 7 on field → 3 stay bench; all available have secondsCredited = 0
        let (game, players) = try makeSampleGame(playerCount: 10, playersOnField: 7, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.startGame(context: ctx)

        // Every available player (on field or bench) starts with 0 credited seconds.
        for player in players {
            let appearance = game.appearances.first(where: { $0.player?.id == player.id })
            #expect(appearance?.secondsCredited == 0)
            #expect(appearance?.secondsPlayed == 0)
        }
    }

    // MARK: – startGame: auto-starter selection

    @Test("startGame auto-selects the least-credited players as starters")
    func startGameAutoSelectsLeastCreditedAsStarters() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, players) = try makeSampleGame(playerCount: 10, playersOnField: 7, ctx: ctx)

        // Give the last 3 players more season time so they should stay on bench.
        for player in players.suffix(3) {
            player.seasonCreditedSeconds = 600
        }
        try ctx.save()

        let vm = AvailabilityViewModel(game: game)
        vm.startGame(context: ctx)

        let starters = game.appearances.filter { $0.onFieldStatus == .onField }
        let benchPlayers = game.appearances.filter { $0.onFieldStatus == .bench }

        #expect(starters.count == 7)
        #expect(benchPlayers.count == 3)

        // The 3 bench players should be the ones with the most season time.
        let benchIds = Set(benchPlayers.compactMap { $0.player?.id })
        for player in players.suffix(3) {
            #expect(benchIds.contains(player.id),
                    "\(player.name) has most season time and should be on bench")
        }
    }

    @Test("startGame puts all available players on field when count ≤ playersOnField")
    func startGameAllOnFieldWhenFewPlayers() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        // 3 available, 7 on field needed → all 3 go on field (can't fill team, but that's the coach's problem)
        let (game, players) = try makeSampleGame(playerCount: 3, playersOnField: 7, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.startGame(context: ctx)

        for player in players {
            let app = game.appearances.first(where: { $0.player?.id == player.id })
            #expect(app?.onFieldStatus == .onField)
        }
    }

    @Test("startGame assigns a position to every starter")
    func startGameAssignsPositionToStarters() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 10, playersOnField: 7, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.startGame(context: ctx)

        let starters = game.appearances.filter { $0.onFieldStatus == .onField }
        #expect(starters.allSatisfy { $0.positionAssigned != nil })
    }

    @Test("startGame leaves bench players with no position assigned")
    func startGameBenchPlayersHaveNoPosition() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 10, playersOnField: 7, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.startGame(context: ctx)

        let bench = game.appearances.filter { $0.onFieldStatus == .bench }
        #expect(bench.allSatisfy { $0.positionAssigned == nil })
    }

    // MARK: – GameStartLogic: autoSelectStarters

    @Test("autoSelectStarters picks the least-credited candidates")
    func autoSelectStartersPicksLeastCredited() {
        let candidates = [
            GameStartLogic.StarterCandidate(id: UUID(), seasonCreditedSeconds: 300, eligiblePositions: [.midfielder]),
            GameStartLogic.StarterCandidate(id: UUID(), seasonCreditedSeconds: 100, eligiblePositions: [.midfielder]),
            GameStartLogic.StarterCandidate(id: UUID(), seasonCreditedSeconds: 200, eligiblePositions: [.midfielder]),
        ]
        let result = GameStartLogic.autoSelectStarters(from: candidates, count: 2)
        let ids = result.map { $0.id }
        #expect(ids.contains(candidates[1].id))  // 100 s — must be selected
        #expect(ids.contains(candidates[2].id))  // 200 s — must be selected
        #expect(!ids.contains(candidates[0].id)) // 300 s — most time, must sit
    }

    @Test("autoSelectStarters returns all candidates when count exceeds available")
    func autoSelectStartersAllWhenCountExceeds() {
        let candidates = (0..<3).map {
            GameStartLogic.StarterCandidate(id: UUID(), seasonCreditedSeconds: $0 * 60, eligiblePositions: Set(Position.allCases))
        }
        let result = GameStartLogic.autoSelectStarters(from: candidates, count: 10)
        #expect(result.count == 3)
    }

    @Test("autoSelectStarters assigns exactly one position per starter")
    func autoSelectStartersOnePositionEach() {
        let candidates = (0..<7).map {
            GameStartLogic.StarterCandidate(id: UUID(), seasonCreditedSeconds: $0 * 60, eligiblePositions: Set(Position.allCases))
        }
        let result = GameStartLogic.autoSelectStarters(from: candidates, count: 7)
        #expect(result.count == 7)
        // Each candidate ID appears exactly once.
        let ids = result.map { $0.id }
        #expect(Set(ids).count == 7)
    }

    @Test("positionSlots distributes 7 slots as 1 GK + 2 DEF + 2 MID + 2 ATT")
    func positionSlotsSevenPlayers() {
        let slots = GameStartLogic.positionSlots(for: 7)
        #expect(slots.count == 7)
        #expect(slots.filter { $0 == .goalkeeper }.count == 1)
        #expect(slots.filter { $0 == .defender }.count == 2)
        #expect(slots.filter { $0 == .midfielder }.count == 2)
        #expect(slots.filter { $0 == .attacker }.count == 2)
    }

    @Test("positionSlots always starts with exactly 1 GK for any positive count")
    func positionSlotsAlwaysOneGK() {
        for n in 1...11 {
            let slots = GameStartLogic.positionSlots(for: n)
            #expect(slots.count == n)
            #expect(slots.filter { $0 == .goalkeeper }.count == 1, "n=\(n) should have 1 GK")
        }
    }

    @Test("startGame sets game.status to inProgress")
    func startGameSetsStatusInProgress() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 2, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.startGame(context: ctx)

        #expect(game.status == .inProgress)
    }

    @Test("startGame saves the substitutionFrequency choice to the game")
    func startGameSavesSubFrequency() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 2, ctx: ctx)

        let vm = AvailabilityViewModel(game: game)
        vm.substitutionFrequency = .frequent
        vm.startGame(context: ctx)

        #expect(game.substitutionFrequency == .frequent)
    }

    @Test("startGame is a no-op when game is already inProgress")
    func startGameNoOpWhenAlreadyStarted() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, _) = try makeSampleGame(playerCount: 2, ctx: ctx)
        game.status = .inProgress
        try ctx.save()

        let vm = AvailabilityViewModel(game: game)
        vm.startGame(context: ctx)

        // No appearances should have been created
        let all = try ctx.fetch(FetchDescriptor<PlayerGameAppearance>())
        #expect(all.isEmpty)
    }

    // MARK: – AvailabilityViewModel: isMismatch (injectable clock)

    @Test("isMismatch is false when clock is within the 4-hour window")
    func isMismatchFalseWithinWindow() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        let (game, _) = try makeSampleGame(playerCount: 2, dateTime: scheduled, ctx: ctx)

        let vm = AvailabilityViewModel(game: game, clock: { scheduled.addingTimeInterval(3600) })
        #expect(!vm.isMismatch)
    }

    @Test("isMismatch is true when clock is outside the 4-hour window")
    func isMismatchTrueOutsideWindow() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        let (game, _) = try makeSampleGame(playerCount: 2, dateTime: scheduled, ctx: ctx)

        let vm = AvailabilityViewModel(game: game, clock: { scheduled.addingTimeInterval(5 * 3600) })
        #expect(vm.isMismatch)
    }
}
