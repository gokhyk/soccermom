import Testing
import Foundation
import SwiftData
@testable import SoccerSub

/// Integration-style tests that simulate a complete game from team creation through
/// season roll-up, verifying that the whole pipeline (availability → live game →
/// substitutions → end game → season totals) works end-to-end.
///
/// Setup used throughout:
///   12 players · 2 absent (pre-game) · 10 available
///   7 on field  ·  3 on bench
///   2 periods × 300 s · frequent subs (checkpoint every 240 s, warning at 180 s)
///   target = (300 × 2 × 7) / 10 = 420 s
@MainActor
struct FullGameIntegrationTests {

    // MARK: – Shared constants

    private let periodDuration = 300       // 5 min periods
    private let numPeriods     = 2
    private let onFieldCount   = 7
    private let totalPlayers   = 12
    private let absentCount    = 2         // P11, P12
    private let availableCount = 10        // 12 - 2

    // target = (300 × 2 × 7) / 10 = 420 s
    private var expectedTarget: Int {
        GameStartLogic.targetSeconds(
            periodDurationSeconds: periodDuration,
            numberOfPeriods: numPeriods,
            playersOnField: onFieldCount,
            availableCount: availableCount
        )
    }

    // MARK: – Container / game builder

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Player.self, Game.self,
                Availability.self, PlayerGameAppearance.self, SubstitutionLog.self,
            configurations: config
        )
    }

    /// Builds the full team + game in a state identical to what AvailabilityViewModel
    /// produces when `startGame` is called:
    ///   • Players 0..<7  → on field, midfielder
    ///   • Players 7..<10 → bench
    ///   • Players 10..<12→ absent; secondsCredited = target
    ///   • Availability records: .available for 0..<10, .absent for 10..<12
    private func buildGame(ctx: ModelContext) throws -> (Game, [Player]) {
        let team = Team(name: "TestFC")
        ctx.insert(team)

        var players: [Player] = []
        for i in 1...totalPlayers {
            let p = Player(name: "P\(i)", jerseyNumber: i)
            p.canPlayGoalkeeper = true; p.canPlayDefender = true
            p.canPlayMidfielder = true; p.canPlayAttacker = true
            ctx.insert(p)
            team.players.append(p)
            players.append(p)
        }

        let game = Game(
            opponent: "Rival",
            playersOnField: onFieldCount,
            numberOfPeriods: numPeriods,
            periodDurationSeconds: periodDuration,
            substitutionFrequency: .frequent,
            status: .inProgress
        )
        ctx.insert(game)
        team.games.append(game)

        for (i, player) in players.enumerated() {
            let isOnField = i < onFieldCount
            let isAbsent  = i >= totalPlayers - absentCount
            let isAvailable = !isAbsent

            // Appearance
            let app = PlayerGameAppearance(
                secondsPlayed: 0,
                secondsCredited: isAbsent ? expectedTarget : 0,
                onFieldStatus: isOnField ? .onField : isAbsent ? .absent : .bench,
                positionAssigned: isOnField ? .midfielder : nil
            )
            app.player = player; app.game = game
            ctx.insert(app)

            // Availability record (mirrors what AvailabilityViewModel writes)
            let avail = Availability(status: isAvailable ? .available : .absent)
            avail.player = player; avail.game = game
            ctx.insert(avail)
        }

        try ctx.save()
        return (game, players)
    }

    /// Drives the ViewModel through one full period using a frozen clock.
    ///
    /// With frequent freq (interval 240 s) and a 300 s period:
    ///   checkpoint 240 s → warning fires at 180 s
    ///
    /// Ticks: 180 s (sub warning + apply), 300 s (period end).
    private func runPeriod(vm: LiveGameViewModel, start: Date) {
        vm.blowWhistle()
        vm.stopClock()

        // 180 s: substitution overlay fires; apply it.
        vm.processTick(now: start.addingTimeInterval(180))
        if vm.showSubstitutionOverlay { vm.applySubstitutions() }

        // 300 s: period ends.
        vm.processTick(now: start.addingTimeInterval(Double(periodDuration)))
    }

    // MARK: – Tests

    @Test("Full game: game status is completed after all periods")
    func gameCompletedAfterAllPeriods() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, _) = try buildGame(ctx: ctx)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })

        runPeriod(vm: vm, start: start)
        #expect(vm.isPeriodEnded)
        vm.advancePeriod()

        runPeriod(vm: vm, start: start)
        #expect(vm.isPeriodEnded)
        vm.advancePeriod()   // last period → endGame()

        #expect(vm.isGameOver)
        #expect(game.status == .completed)
    }

    @Test("Full game: total played seconds equals total field time (conservation)")
    func totalPlayedSecondsConservation() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, players) = try buildGame(ctx: ctx)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })

        runPeriod(vm: vm, start: start); vm.advancePeriod()
        runPeriod(vm: vm, start: start); vm.advancePeriod()

        let presentPlayers = players.prefix(availableCount)
        let totalPlayed = presentPlayers.reduce(0) { $0 + $1.seasonPlayedSeconds }
        // 7 on-field × 300 s × 2 periods = 4200 s
        #expect(totalPlayed == onFieldCount * periodDuration * numPeriods)
    }

    @Test("Full game: absent players are credited at target, not zero")
    func absentPlayersGetTargetCredit() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, players) = try buildGame(ctx: ctx)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })

        runPeriod(vm: vm, start: start); vm.advancePeriod()
        runPeriod(vm: vm, start: start); vm.advancePeriod()

        let absentPlayers = players.suffix(absentCount)
        for player in absentPlayers {
            #expect(player.seasonPlayedSeconds   == 0,
                    "Absent player should have 0 seconds played")
            #expect(player.seasonCreditedSeconds == expectedTarget,
                    "Absent player should be credited at target \(expectedTarget) s")
        }
    }

    @Test("Full game: every present player gets at least some playing time")
    func everyPresentPlayerGetsTime() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, players) = try buildGame(ctx: ctx)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })

        runPeriod(vm: vm, start: start); vm.advancePeriod()
        runPeriod(vm: vm, start: start); vm.advancePeriod()

        let presentPlayers = players.prefix(availableCount)
        for player in presentPlayers {
            #expect(player.seasonPlayedSeconds > 0,
                    "\(player.name) should have > 0 s played")
        }
    }

    @Test("Full game: present players' seasonCreditedSeconds equals their actual played time")
    func presentPlayersCreditedEqualsPlayed() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, players) = try buildGame(ctx: ctx)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })

        runPeriod(vm: vm, start: start); vm.advancePeriod()
        runPeriod(vm: vm, start: start); vm.advancePeriod()

        let presentPlayers = players.prefix(availableCount)
        for player in presentPlayers {
            #expect(player.seasonCreditedSeconds == player.seasonPlayedSeconds,
                    "\(player.name): credited \(player.seasonCreditedSeconds) ≠ played \(player.seasonPlayedSeconds)")
        }
    }

    @Test("Full game: substitutions reduce the gap between most- and least-played")
    func subsReducePlaytimeGap() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, players) = try buildGame(ctx: ctx)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })

        runPeriod(vm: vm, start: start); vm.advancePeriod()
        runPeriod(vm: vm, start: start); vm.advancePeriod()

        let presentSeconds = players.prefix(availableCount).map { $0.seasonPlayedSeconds }
        let gap = presentSeconds.max()! - presentSeconds.min()!

        // Without any subs the gap would be totalGameTime (starters 600 s, bench 0 s).
        // With subs in both periods the gap must be strictly smaller.
        let noSubGap = periodDuration * numPeriods  // 600 s baseline
        #expect(gap < noSubGap,
                "Gap \(gap) s should be < no-sub baseline \(noSubGap) s")
    }

    @Test("endGameManually marks game completed and rolls up season stats")
    func endGameManuallyRollsUpStats() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, players) = try buildGame(ctx: ctx)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })

        // Blow whistle, accumulate some time, then end early.
        vm.blowWhistle()
        vm.stopClock()
        vm.processTick(now: start.addingTimeInterval(90))  // 90 s played by on-field

        vm.endGameManually()

        #expect(vm.isGameOver)
        #expect(game.status == .completed)

        // On-field players (0..<7) should each have 90 s rolled up.
        let onFieldPlayers = players.prefix(onFieldCount)
        for player in onFieldPlayers {
            #expect(player.seasonPlayedSeconds == 90)
        }

        // Bench players: 0 played, 0 credited (bench doesn't accumulate).
        let benchPlayers = players[onFieldCount..<(totalPlayers - absentCount)]
        for player in benchPlayers {
            #expect(player.seasonPlayedSeconds == 0)
        }

        // Absent players: credited at target.
        let absentPlayers = players.suffix(absentCount)
        for player in absentPlayers {
            #expect(player.seasonCreditedSeconds == expectedTarget)
        }
    }

    @Test("endGame is idempotent: calling it twice does not double-count season stats")
    func endGameIdempotent() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, players) = try buildGame(ctx: ctx)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let vm = LiveGameViewModel(game: game, context: ctx, clock: { start })

        vm.blowWhistle(); vm.stopClock()
        vm.processTick(now: start.addingTimeInterval(90))

        vm.endGameManually()
        let afterFirst = players[0].seasonPlayedSeconds

        // A second call must be a no-op because game.status == .completed.
        vm.endGameManually()
        #expect(players[0].seasonPlayedSeconds == afterFirst)
    }
}
