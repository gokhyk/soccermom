import Testing
import Foundation
import SwiftData
@testable import SoccerSub

@MainActor
struct LiveGameViewModelTests {

    // MARK: – Container

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Player.self, Game.self,
                Availability.self, PlayerGameAppearance.self, SubstitutionLog.self,
            configurations: config
        )
    }

    /// Creates a game with `onFieldCount` players on-field (midfielder) and
    /// `benchCount` additional players on bench. All bench players can play all positions.
    private func makeGame(
        onFieldCount: Int,
        benchCount: Int,
        periodDurationSeconds: Int = 1800,
        frequency: SubstitutionFrequency = .normal,
        ctx: ModelContext
    ) throws -> (Game, [Player]) {
        let team = Team(name: "Test")
        ctx.insert(team)

        var players: [Player] = []
        let total = onFieldCount + benchCount
        for i in 1...total {
            let p = Player(name: "P\(i)", jerseyNumber: i)
            ctx.insert(p)
            team.players.append(p)
            players.append(p)
        }

        let game = Game(
            opponent: "Rival",
            playersOnField: onFieldCount,
            numberOfPeriods: 2,
            periodDurationSeconds: periodDurationSeconds,
            substitutionFrequency: frequency,
            status: .inProgress
        )
        ctx.insert(game)
        team.games.append(game)

        for (i, player) in players.enumerated() {
            let isOnField = i < onFieldCount
            let app = PlayerGameAppearance(
                secondsPlayed: 0,
                secondsCredited: 0,
                onFieldStatus: isOnField ? .onField : .bench,
                positionAssigned: isOnField ? .midfielder : nil
            )
            app.player = player
            app.game   = game
            ctx.insert(app)
        }
        try ctx.save()
        return (game, players)
    }

    private func makeVM(game: Game, ctx: ModelContext, startDate: Date) -> LiveGameViewModel {
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { startDate })
        vm.blowWhistle()
        vm.stopClock()  // cancel the real Timer; periodStartDate stays set
        return vm
    }

    // MARK: – processTick: elapsed time

    @Test("processTick computes elapsedPeriodSeconds from start date")
    func processTickUpdatesElapsed() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, _) = try makeGame(onFieldCount: 1, benchCount: 1, ctx: ctx)

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        vm.processTick(now: start.addingTimeInterval(100))
        #expect(vm.elapsedPeriodSeconds == 100)
    }

    @Test("processTick clamps elapsed to period duration")
    func processTickClampsAtPeriodEnd() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, _) = try makeGame(onFieldCount: 1, benchCount: 0, periodDurationSeconds: 600, ctx: ctx)

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        vm.processTick(now: start.addingTimeInterval(700))  // past period end
        #expect(vm.elapsedPeriodSeconds == 600)
    }

    // MARK: – processTick: time accumulation routing

    @Test("processTick increments secondsPlayed for an on-field player")
    func processTickIncrementsOnField() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, players) = try makeGame(onFieldCount: 1, benchCount: 1, ctx: ctx)

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        vm.processTick(now: start.addingTimeInterval(50))

        let onFieldApp = game.appearances.first(where: { $0.player?.id == players[0].id })
        #expect(onFieldApp?.secondsPlayed == 50)
        #expect(onFieldApp?.secondsCredited == 50)
    }

    @Test("processTick does not increment secondsPlayed for a bench player")
    func processTickLeavesBenchUnchanged() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, players) = try makeGame(onFieldCount: 1, benchCount: 1, ctx: ctx)

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        vm.processTick(now: start.addingTimeInterval(50))

        let benchApp = game.appearances.first(where: { $0.player?.id == players[1].id })
        #expect(benchApp?.secondsPlayed == 0)
    }

    @Test("processTick correctly applies a large delta (simulates backgrounding)")
    func processTickLargeDelta() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, players) = try makeGame(onFieldCount: 1, benchCount: 0, ctx: ctx)

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        vm.processTick(now: start.addingTimeInterval(30))   // tick at 30 s
        vm.processTick(now: start.addingTimeInterval(90))   // tick at 90 s (60-s gap)

        let app = game.appearances.first(where: { $0.player?.id == players[0].id })
        #expect(app?.secondsPlayed == 90)
    }

    // MARK: – processTick: period end

    @Test("processTick sets isPeriodEnded when elapsed reaches period duration")
    func processTickEndsPeriod() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, _) = try makeGame(onFieldCount: 1, benchCount: 0, periodDurationSeconds: 300, ctx: ctx)

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        #expect(!vm.isPeriodEnded)
        vm.processTick(now: start.addingTimeInterval(300))
        #expect(vm.isPeriodEnded)
        #expect(!vm.isRunning)
    }

    // MARK: – processTick: substitution overlay

    @Test("processTick triggers overlay at warningLeadSeconds before checkpoint")
    func processTickTriggersOverlayAtWarningLead() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        // Game: normal freq (checkpoint at 420 s), warning fires at 360 s
        // On-field: 1 player with 200 s played; bench: 1 player with 50 s played (swap is beneficial)
        let (game, players) = try makeGame(
            onFieldCount: 1, benchCount: 1,
            periodDurationSeconds: 1800, frequency: .normal,
            ctx: ctx
        )
        // Give on-field player some played time so swap is beneficial
        if let app = game.appearances.first(where: { $0.player?.id == players[0].id }) {
            app.secondsPlayed = 200
        }
        try ctx.save()

        let vm = makeVM(game: game, ctx: ctx, startDate: start)

        // One second before warning window: no overlay yet
        vm.processTick(now: start.addingTimeInterval(359))
        #expect(!vm.showSubstitutionOverlay)

        // At exactly warningLeadSeconds before checkpoint (360 s): overlay fires
        vm.processTick(now: start.addingTimeInterval(360))
        #expect(vm.showSubstitutionOverlay)
    }

    @Test("processTick does not trigger overlay before warning window")
    func processTickNoOverlayBeforeWarningWindow() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, _) = try makeGame(
            onFieldCount: 1, benchCount: 1,
            periodDurationSeconds: 1800, frequency: .normal,
            ctx: ctx
        )

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        vm.processTick(now: start.addingTimeInterval(300))  // 60 s before warning (at 360)
        #expect(!vm.showSubstitutionOverlay)
    }

    @Test("processTick does not re-trigger overlay for the same checkpoint")
    func processTickDeduplicatesOverlay() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, players) = try makeGame(
            onFieldCount: 1, benchCount: 1,
            periodDurationSeconds: 1800, frequency: .normal,
            ctx: ctx
        )
        if let app = game.appearances.first(where: { $0.player?.id == players[0].id }) {
            app.secondsPlayed = 200
        }
        try ctx.save()

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        vm.processTick(now: start.addingTimeInterval(360))
        #expect(vm.showSubstitutionOverlay)

        // Dismiss the overlay
        vm.dismissSubstitutionOverlay()
        #expect(!vm.showSubstitutionOverlay)

        // Another tick in the same window — overlay should NOT re-fire for same checkpoint
        vm.processTick(now: start.addingTimeInterval(365))
        #expect(!vm.showSubstitutionOverlay)
    }

    // MARK: – applySubstitutions

    @Test("applySubstitutions swaps onFieldStatus for the paired players")
    func applySubstitutionsSwapsStatus() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, players) = try makeGame(onFieldCount: 1, benchCount: 1, ctx: ctx)

        // Give on-field player more played time so the engine recommends the swap
        if let app = game.appearances.first(where: { $0.player?.id == players[0].id }) {
            app.secondsPlayed = 300
        }
        try ctx.save()

        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })
        vm.rebuildPendingSubstitutions()
        vm.applySubstitutions()

        let outApp = game.appearances.first(where: { $0.player?.id == players[0].id })
        let inApp  = game.appearances.first(where: { $0.player?.id == players[1].id })
        #expect(outApp?.onFieldStatus == .bench)
        #expect(inApp?.onFieldStatus  == .onField)
    }

    @Test("applySubstitutions creates a SubstitutionLog entry per pair")
    func applySubstitutionsCreatesLog() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, players) = try makeGame(onFieldCount: 1, benchCount: 1, ctx: ctx)

        if let app = game.appearances.first(where: { $0.player?.id == players[0].id }) {
            app.secondsPlayed = 300
        }
        try ctx.save()

        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })
        vm.rebuildPendingSubstitutions()
        vm.applySubstitutions(reason: .scheduled)

        let logs = try ctx.fetch(FetchDescriptor<SubstitutionLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.reason == .scheduled)
    }

    @Test("applySubstitutions clears the overlay and pending list")
    func applySubstitutionsClearsOverlay() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let (game, players) = try makeGame(onFieldCount: 1, benchCount: 1, ctx: ctx)

        if let app = game.appearances.first(where: { $0.player?.id == players[0].id }) {
            app.secondsPlayed = 300
        }
        try ctx.save()

        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })
        vm.rebuildPendingSubstitutions()
        vm.showSubstitutionOverlay = true
        vm.applySubstitutions()

        #expect(!vm.showSubstitutionOverlay)
        #expect(vm.pendingSubstitutions.isEmpty)
    }

    // MARK: – advancePeriod / endGame

    @Test("advancePeriod increments currentPeriod and resets elapsed time")
    func advancePeriodIncrementsCounter() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, _) = try makeGame(onFieldCount: 1, benchCount: 0, periodDurationSeconds: 300, ctx: ctx)

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        vm.processTick(now: start.addingTimeInterval(300))  // end period 1
        #expect(vm.isPeriodEnded)

        vm.advancePeriod()
        #expect(vm.currentPeriod == 2)
        #expect(vm.elapsedPeriodSeconds == 0)
        #expect(!vm.isPeriodEnded)
    }

    @Test("advancePeriod after last period marks game as completed")
    func advancePeriodAfterLastPeriodEndsGame() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let (game, _) = try makeGame(onFieldCount: 1, benchCount: 0, periodDurationSeconds: 300, ctx: ctx)

        let vm = makeVM(game: game, ctx: ctx, startDate: start)
        // End period 1
        vm.processTick(now: start.addingTimeInterval(300))
        vm.advancePeriod()  // → period 2

        // End period 2: need to re-blow whistle
        vm.blowWhistle()
        vm.stopClock()
        vm.processTick(now: start.addingTimeInterval(600))  // reuse start; delta is large
        #expect(vm.isPeriodEnded)

        vm.advancePeriod()  // last period → endGame
        #expect(vm.isGameOver)
        #expect(game.status == .completed)
    }
}
