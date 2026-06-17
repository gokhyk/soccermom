import Testing
import Foundation
import SwiftData
@testable import SoccerSub

/// Tests for the three edge-case interactions in Prompt 09:
///   1. Injury / early leave: removeForInjury + applyInjuryReplacement
///   2. Bench → Absent: markAbsent
///   3. Absent → Bench: returnToBench
@MainActor
struct EdgeCaseTests {

    // MARK: – Container / setup helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Player.self, Game.self,
                Availability.self, PlayerGameAppearance.self, SubstitutionLog.self,
            configurations: config
        )
    }

    /// Creates a game in progress with appearances in all three states.
    ///
    /// `onField`: [(position, secondsPlayed)] — each gets an on-field appearance.
    /// `bench`:   [secondsPlayed] — on bench; all positions eligible.
    /// `absent`:  [secondsPlayed] — absent; all positions eligible; secondsCredited set to target.
    ///
    /// One Availability(.available) record is created per on-field and bench player so
    /// `markAbsent` can compute target seconds from `game.availabilities`.
    private func makeGame(
        onField: [(Position, Int)],
        bench: [Int],
        absent: [Int] = [],
        periodDurationSeconds: Int = 1800,
        numberOfPeriods: Int = 2,
        playersOnField: Int? = nil,
        ctx: ModelContext
    ) throws -> (game: Game, onFieldApps: [PlayerGameAppearance],
                 benchApps: [PlayerGameAppearance], absentApps: [PlayerGameAppearance]) {

        let team = Team(name: "T")
        ctx.insert(team)

        let pof = playersOnField ?? onField.count
        let game = Game(
            opponent: "Rival",
            playersOnField: pof,
            numberOfPeriods: numberOfPeriods,
            periodDurationSeconds: periodDurationSeconds,
            substitutionFrequency: .normal,
            status: .inProgress
        )
        ctx.insert(game)
        team.games.append(game)

        var playerIndex = 1

        func makePlayer(name: String) -> Player {
            let p = Player(name: "\(name)\(playerIndex)", jerseyNumber: playerIndex)
            p.canPlayGoalkeeper = true; p.canPlayDefender = true
            p.canPlayMidfielder = true; p.canPlayAttacker = true
            ctx.insert(p); team.players.append(p)
            playerIndex += 1
            return p
        }

        // On-field appearances + Availability records
        var onFieldApps: [PlayerGameAppearance] = []
        for (position, seconds) in onField {
            let p = makePlayer(name: "OF")
            let app = PlayerGameAppearance(
                secondsPlayed: seconds, secondsCredited: seconds,
                onFieldStatus: .onField, positionAssigned: position
            )
            app.player = p; app.game = game
            ctx.insert(app)
            onFieldApps.append(app)

            let avail = Availability(status: .available)
            avail.player = p; avail.game = game
            ctx.insert(avail)
        }

        // Bench appearances + Availability records
        var benchApps: [PlayerGameAppearance] = []
        for seconds in bench {
            let p = makePlayer(name: "BN")
            let app = PlayerGameAppearance(
                secondsPlayed: seconds, secondsCredited: seconds,
                onFieldStatus: .bench, positionAssigned: nil
            )
            app.player = p; app.game = game
            ctx.insert(app)
            benchApps.append(app)

            let avail = Availability(status: .available)
            avail.player = p; avail.game = game
            ctx.insert(avail)
        }

        // Absent appearances — secondsCredited frozen at target; no Availability record
        // (they were absent at game start or were marked absent mid-game)
        let targetSeconds = GameStartLogic.targetSeconds(
            periodDurationSeconds: periodDurationSeconds,
            numberOfPeriods: numberOfPeriods,
            playersOnField: pof,
            availableCount: onField.count + bench.count
        )
        var absentApps: [PlayerGameAppearance] = []
        for seconds in absent {
            let p = makePlayer(name: "AB")
            let app = PlayerGameAppearance(
                secondsPlayed: seconds, secondsCredited: targetSeconds,
                onFieldStatus: .absent, positionAssigned: nil
            )
            app.player = p; app.game = game
            ctx.insert(app)
            absentApps.append(app)
        }

        try ctx.save()
        return (game, onFieldApps, benchApps, absentApps)
    }

    // ── removeForInjury ───────────────────────────────────────────────────────

    @Test("removeForInjury moves the on-field player to bench and clears positionAssigned")
    func removeForInjuryMovesToBench() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, onFieldApps, _, _) = try makeGame(
            onField: [(.midfielder, 500)], bench: [100], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)

        _ = vm.removeForInjury(onFieldApps[0])

        #expect(onFieldApps[0].onFieldStatus    == .bench)
        #expect(onFieldApps[0].positionAssigned == nil)
    }

    @Test("removeForInjury returns the least-played eligible bench player as the replacement")
    func removeForInjuryReturnsLeastPlayedBench() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        // Two bench players: BN1=200s, BN2=50s — engine should propose BN2
        let (game, onFieldApps, benchApps, _) = try makeGame(
            onField: [(.midfielder, 1000)], bench: [200, 50], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)

        let pair = vm.removeForInjury(onFieldApps[0])

        let bn2ID = try #require(benchApps[1].player?.id)
        #expect(pair != nil)
        #expect(pair?.playerIn.id == bn2ID)
    }

    @Test("removeForInjury returns nil when no bench player is available")
    func removeForInjuryNilWhenNoBench() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, onFieldApps, _, _) = try makeGame(
            onField: [(.midfielder, 300)], bench: [], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)

        let pair = vm.removeForInjury(onFieldApps[0])

        #expect(pair == nil)
    }

    // ── applyInjuryReplacement ────────────────────────────────────────────────

    @Test("applyInjuryReplacement moves the proposed bench player to on-field")
    func applyInjuryReplacementMovesToField() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, onFieldApps, benchApps, _) = try makeGame(
            onField: [(.midfielder, 800)], bench: [100], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)

        let pair = try #require(vm.removeForInjury(onFieldApps[0]))
        vm.applyInjuryReplacement(pair, reason: .injury)

        #expect(benchApps[0].onFieldStatus == .onField)
    }

    @Test("applyInjuryReplacement assigns the outgoing player's position to the replacement")
    func applyInjuryReplacementAssignsPosition() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, onFieldApps, benchApps, _) = try makeGame(
            onField: [(.attacker, 600)], bench: [50], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)

        let pair = try #require(vm.removeForInjury(onFieldApps[0]))
        vm.applyInjuryReplacement(pair, reason: .earlyLeave)

        #expect(benchApps[0].positionAssigned == .attacker)
    }

    @Test("applyInjuryReplacement creates a SubstitutionLog with the correct reason")
    func applyInjuryReplacementCreatesLog() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, onFieldApps, _, _) = try makeGame(
            onField: [(.defender, 700)], bench: [200], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)

        let pair = try #require(vm.removeForInjury(onFieldApps[0]))
        vm.applyInjuryReplacement(pair, reason: .injury)

        let logs = try ctx.fetch(FetchDescriptor<SubstitutionLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.reason == .injury)
    }

    // ── markAbsent ────────────────────────────────────────────────────────────

    @Test("markAbsent sets onFieldStatus to absent")
    func markAbsentSetsStatusAbsent() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, _, benchApps, _) = try makeGame(
            onField: [(.midfielder, 0)], bench: [0], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)

        vm.markAbsent(benchApps[0])

        #expect(benchApps[0].onFieldStatus == .absent)
    }

    @Test("markAbsent freezes secondsCredited at the computed target seconds")
    func markAbsentFreezesCredits() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        // 1 on-field + 1 bench = 2 available; target = (1800 * 2 * 1) / 2 = 1800
        let (game, _, benchApps, _) = try makeGame(
            onField: [(.midfielder, 0)], bench: [0],
            periodDurationSeconds: 1800, numberOfPeriods: 2, playersOnField: 1,
            ctx: ctx
        )
        let expected = GameStartLogic.targetSeconds(
            periodDurationSeconds: 1800, numberOfPeriods: 2,
            playersOnField: 1, availableCount: 2
        )
        let vm = LiveGameViewModel(game: game, context: ctx)

        vm.markAbsent(benchApps[0])

        #expect(benchApps[0].secondsCredited == expected)
        #expect(expected == 1800)
    }

    @Test("After markAbsent, the engine does not propose the absent player as a sub candidate")
    func markAbsentExcludesFromEngine() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        // On-field A (1000s), bench B (200s) and C (50s).
        // Before markAbsent(C): engine would prefer C (fewer seconds played).
        // After markAbsent(C): only B should appear in proposed pairs.
        let (game, _, benchApps, _) = try makeGame(
            onField: [(.midfielder, 1000)], bench: [200, 50], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)
        let cID = try #require(benchApps[1].player?.id)
        let bID = try #require(benchApps[0].player?.id)

        vm.markAbsent(benchApps[1])
        vm.rebuildPendingSubstitutions()

        let inIDs = vm.pendingSubstitutions.map { $0.playerIn.id }
        #expect(!inIDs.contains(cID))
        #expect(inIDs.contains(bID))
    }

    // ── returnToBench ─────────────────────────────────────────────────────────

    @Test("returnToBench sets onFieldStatus to bench")
    func returnToBenchSetsStatusBench() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, _, _, absentApps) = try makeGame(
            onField: [(.midfielder, 0)], bench: [], absent: [0], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)

        vm.returnToBench(absentApps[0])

        #expect(absentApps[0].onFieldStatus == .bench)
    }

    @Test("returnToBench resets secondsCredited to secondsPlayed (resume actual tracking)")
    func returnToBenchResetsCredits() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        let (game, _, _, absentApps) = try makeGame(
            onField: [(.midfielder, 0)], bench: [], absent: [0], ctx: ctx
        )
        let vm = LiveGameViewModel(game: game, context: ctx)
        // Absent player has a frozen secondsCredited > 0 set at game start.
        let frozenCredits = absentApps[0].secondsCredited
        #expect(frozenCredits > 0)

        vm.returnToBench(absentApps[0])

        // After return: credits should equal actual played time (0).
        #expect(absentApps[0].secondsCredited == absentApps[0].secondsPlayed)
        #expect(absentApps[0].secondsCredited == 0)
    }

    @Test("After returnToBench, the engine can pair the returned player as a sub candidate")
    func returnToBenchIncludesInEngine() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        // On-field A (1000s midfielder), bench B (goalkeeper-only → can't fill midfielder),
        // absent C (all positions, 0s).
        let (game, _, benchApps, absentApps) = try makeGame(
            onField: [(.midfielder, 1000)], bench: [300], absent: [0], ctx: ctx
        )
        // Restrict B to goalkeeper only.
        if let playerB = benchApps[0].player {
            playerB.canPlayMidfielder = false
            playerB.canPlayAttacker   = false
            playerB.canPlayDefender   = false
        }
        try ctx.save()

        let vm = LiveGameViewModel(game: game, context: ctx)

        // Before returning C: B can't play midfielder → no valid pairs.
        vm.rebuildPendingSubstitutions()
        #expect(vm.pendingSubstitutions.isEmpty)

        // After returnToBench(C): C on bench with 0s, can play midfielder → A→C pair.
        vm.returnToBench(absentApps[0])
        vm.rebuildPendingSubstitutions()

        let cID = try #require(absentApps[0].player?.id)
        let inIDs = vm.pendingSubstitutions.map { $0.playerIn.id }
        #expect(inIDs.contains(cID))
    }

    // ── absent ↔ bench round trip ─────────────────────────────────────────────

    @Test("Absent → bench → absent round trip: credits freeze at target on second markAbsent")
    func absentBenchAbsentRoundTrip() throws {
        let c = try makeContainer(); let ctx = ModelContext(c)
        // 1 on-field + 1 bench player X → 2 available; target = (1800*2*1)/2 = 1800
        let (game, _, benchApps, _) = try makeGame(
            onField: [(.midfielder, 0)], bench: [0],
            periodDurationSeconds: 1800, numberOfPeriods: 2, playersOnField: 1,
            ctx: ctx
        )
        let vm  = LiveGameViewModel(game: game, context: ctx)
        let xApp = benchApps[0]

        // Step 1: mark X absent → credits frozen at target
        vm.markAbsent(xApp)
        let frozenTarget = xApp.secondsCredited
        #expect(xApp.onFieldStatus   == .absent)
        #expect(frozenTarget > 0)

        // Step 2: return X to bench → credits reset to actual (0)
        vm.returnToBench(xApp)
        #expect(xApp.onFieldStatus   == .bench)
        #expect(xApp.secondsCredited == 0)

        // Step 3: mark X absent again → credits frozen at target again
        vm.markAbsent(xApp)
        #expect(xApp.onFieldStatus   == .absent)
        #expect(xApp.secondsCredited == frozenTarget)
    }
}
