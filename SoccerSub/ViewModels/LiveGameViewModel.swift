import Foundation
import Observation
import SwiftData

@Observable
final class LiveGameViewModel {

    // MARK: – Observed state

    var currentPeriod: Int = 1
    var elapsedPeriodSeconds: Int = 0
    var isRunning: Bool = false
    var isPeriodEnded: Bool = false
    var isGameOver: Bool = false
    var hasStarted: Bool = false       // true once the first whistle is blown; never resets
    var showSubstitutionOverlay: Bool = false
    var pendingSubstitutions: [SubstitutionPair] = []

    // MARK: – Non-observed internals

    @ObservationIgnored let game: Game
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let clock: () -> Date

    @ObservationIgnored private var periodStartDate: Date? = nil
    @ObservationIgnored private var lastTickElapsed: Int = 0
    @ObservationIgnored private var lastPromptedCheckpoint: Int? = nil
    @ObservationIgnored private var timer: Timer? = nil

    // MARK: – Init

    init(game: Game, context: ModelContext, clock: @escaping () -> Date = { .now }) {
        self.game = game
        self.context = context
        self.clock = clock
    }

    deinit { timer?.invalidate() }

    // MARK: – Computed appearance views

    var onFieldAppearances: [PlayerGameAppearance] {
        game.appearances
            .filter { $0.onFieldStatus == .onField }
            .sorted { ($0.positionAssigned?.displayRow ?? 99) < ($1.positionAssigned?.displayRow ?? 99) }
    }

    var benchAppearances: [PlayerGameAppearance] {
        game.appearances
            .filter { $0.onFieldStatus == .bench }
            .sorted { ($0.player?.jerseyNumber ?? 0) < ($1.player?.jerseyNumber ?? 0) }
    }

    var absentAppearances: [PlayerGameAppearance] {
        game.appearances
            .filter { $0.onFieldStatus == .absent }
            .sorted { ($0.player?.jerseyNumber ?? 0) < ($1.player?.jerseyNumber ?? 0) }
    }

    var canBlowWhistle: Bool {
        !isRunning && !isPeriodEnded && !isGameOver &&
        onFieldAppearances.count == game.playersOnField
    }

    // MARK: – Lineup setup

    func assignToField(_ appearance: PlayerGameAppearance, position: Position) {
        appearance.onFieldStatus   = .onField
        appearance.positionAssigned = position
        try? context.save()
    }

    func removeFromField(_ appearance: PlayerGameAppearance) {
        appearance.onFieldStatus   = .bench
        appearance.positionAssigned = nil
        try? context.save()
    }

    // MARK: – Clock

    func blowWhistle() {
        guard canBlowWhistle else { return }
        periodStartDate = clock()
        lastTickElapsed = 0
        isRunning  = true
        hasStarted = true
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.processTick(now: self.clock())
        }
    }

    func stopClock() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        // periodStartDate is intentionally not cleared here — advancePeriod() does that.
    }

    // MARK: – Tick (internal so the test suite can drive it without a real Timer)

    func processTick(now: Date) {
        guard let startDate = periodStartDate else { return }

        let newElapsed = LiveGameLogic.elapsedSeconds(since: startDate, now: now)
        let delta = newElapsed - lastTickElapsed
        guard delta >= 0 else { return }

        lastTickElapsed       = newElapsed
        elapsedPeriodSeconds  = min(newElapsed, game.periodDurationSeconds)

        if delta > 0 {
            for appearance in onFieldAppearances {
                appearance.secondsPlayed  += delta
                appearance.secondsCredited = appearance.secondsPlayed
            }
        }

        if newElapsed >= game.periodDurationSeconds {
            endPeriod()
        } else {
            checkSubstitutionOverlay()
        }

        try? context.save()
    }

    // MARK: – Period / game lifecycle

    private func endPeriod() {
        stopClock()
        isPeriodEnded        = true
        showSubstitutionOverlay = false
        pendingSubstitutions = []
        lastPromptedCheckpoint  = nil
        elapsedPeriodSeconds = game.periodDurationSeconds
    }

    func advancePeriod() {
        guard isPeriodEnded else { return }
        if currentPeriod >= game.numberOfPeriods {
            endGame()
        } else {
            currentPeriod       += 1
            isPeriodEnded        = false
            elapsedPeriodSeconds = 0
            lastTickElapsed      = 0
            periodStartDate      = nil
        }
    }

    private func endGame() {
        guard game.status != .completed else { return }  // idempotency
        isPeriodEnded = false
        isGameOver    = true
        game.status   = .completed

        // Roll every appearance's stats up into the player's season totals.
        for appearance in game.appearances {
            guard let player = appearance.player else { continue }
            player.seasonPlayedSeconds   += appearance.secondsPlayed
            player.seasonCreditedSeconds += appearance.secondsCredited
        }
        try? context.save()
    }

    /// Ends the game immediately regardless of which period is running.
    /// Stops the clock, clears any pending overlay, and triggers the season roll-up.
    func endGameManually() {
        guard !isGameOver else { return }
        stopClock()
        showSubstitutionOverlay = false
        pendingSubstitutions    = []
        isPeriodEnded           = false
        endGame()
    }

    // MARK: – Substitution overlay

    private func checkSubstitutionOverlay() {
        guard !showSubstitutionOverlay else { return }

        guard SubstitutionEngine.shouldPromptSubstitution(
            elapsedPeriodSeconds: elapsedPeriodSeconds,
            periodDurationSeconds: game.periodDurationSeconds,
            frequency: game.substitutionFrequency
        ) else { return }

        guard let checkpoint = SubstitutionEngine.nextCheckpoint(
            elapsedPeriodSeconds: elapsedPeriodSeconds,
            periodDurationSeconds: game.periodDurationSeconds,
            frequency: game.substitutionFrequency
        ), checkpoint != lastPromptedCheckpoint else { return }

        lastPromptedCheckpoint = checkpoint
        rebuildPendingSubstitutions()

        if !pendingSubstitutions.isEmpty {
            showSubstitutionOverlay = true
        }
    }

    func rebuildPendingSubstitutions() {
        let onField = onFieldAppearances.compactMap { app -> OnFieldPlayer? in
            guard let player = app.player, let position = app.positionAssigned else { return nil }
            return OnFieldPlayer(id: player.id, secondsPlayed: app.secondsPlayed, position: position)
        }
        let bench = benchAppearances.compactMap { app -> BenchPlayer? in
            guard let player = app.player else { return nil }
            return BenchPlayer(
                id: player.id,
                secondsPlayed: app.secondsPlayed,
                eligiblePositions: player.eligiblePositions
            )
        }
        pendingSubstitutions = SubstitutionEngine.recommendedSubstitutions(
            onField: onField,
            bench: bench
        )
    }

    // MARK: – Apply substitution

    func applySubstitutions(reason: SubstitutionReason = .scheduled) {
        for pair in pendingSubstitutions {
            guard
                let outApp = game.appearances.first(where: { $0.player?.id == pair.playerOut.id }),
                let inApp  = game.appearances.first(where: { $0.player?.id == pair.playerIn.id  })
            else { continue }

            let position           = outApp.positionAssigned
            outApp.onFieldStatus   = .bench
            outApp.positionAssigned = nil
            inApp.onFieldStatus    = .onField
            inApp.positionAssigned  = position

            let log = SubstitutionLog(
                elapsedPeriodSeconds: elapsedPeriodSeconds,
                period: currentPeriod,
                reason: reason
            )
            log.game      = game
            log.playerOut = outApp.player
            log.playerIn  = inApp.player
            context.insert(log)
        }
        pendingSubstitutions    = []
        showSubstitutionOverlay = false
        try? context.save()
    }

    func dismissSubstitutionOverlay() {
        showSubstitutionOverlay = false
        pendingSubstitutions    = []
    }

    // MARK: – Injury / Early Leave

    /// Immediately removes an on-field player and returns the best available bench
    /// replacement (using `immediateSubstitution`), or nil if none qualifies.
    /// The caller is responsible for confirming and applying the returned pair via
    /// `applyInjuryReplacement(_:reason:)`.
    func removeForInjury(_ appearance: PlayerGameAppearance) -> SubstitutionPair? {
        guard let player = appearance.player,
              let position = appearance.positionAssigned else { return nil }

        let outgoing = OnFieldPlayer(
            id: player.id,
            secondsPlayed: appearance.secondsPlayed,
            position: position
        )

        // Snapshot bench BEFORE modifying state so the outgoing player isn't included.
        let availBench = benchAppearances.compactMap { app -> BenchPlayer? in
            guard let p = app.player else { return nil }
            return BenchPlayer(id: p.id, secondsPlayed: app.secondsPlayed,
                               eligiblePositions: p.eligiblePositions)
        }

        appearance.onFieldStatus    = .bench
        appearance.positionAssigned = nil

        let pair = SubstitutionEngine.immediateSubstitution(outgoing: outgoing, bench: availBench)
        try? context.save()
        return pair
    }

    /// Applies the replacement pair returned by `removeForInjury`.
    func applyInjuryReplacement(_ pair: SubstitutionPair, reason: SubstitutionReason) {
        guard let inApp = game.appearances.first(where: { $0.player?.id == pair.playerIn.id })
        else { return }

        inApp.onFieldStatus    = .onField
        inApp.positionAssigned = pair.position

        let log = SubstitutionLog(
            elapsedPeriodSeconds: elapsedPeriodSeconds,
            period: currentPeriod,
            reason: reason
        )
        log.game      = game
        log.playerOut = game.appearances.first(where: { $0.player?.id == pair.playerOut.id })?.player
        log.playerIn  = inApp.player
        context.insert(log)
        try? context.save()
    }

    // MARK: – Bench ↔ Absent

    /// Marks a bench player absent for the remainder of the game.
    /// Freezes `secondsCredited` at the game's target-average value.
    /// The target is computed *before* updating the Availability record so the
    /// outgoing player is still included in the divisor, giving them their fair share.
    func markAbsent(_ appearance: PlayerGameAppearance) {
        let availableCount = game.availabilities.filter { $0.status == .available }.count
        let target = GameStartLogic.targetSeconds(
            periodDurationSeconds: game.periodDurationSeconds,
            numberOfPeriods: game.numberOfPeriods,
            playersOnField: game.playersOnField,
            availableCount: availableCount
        )

        appearance.onFieldStatus   = .absent
        appearance.secondsCredited = target

        if let avail = game.availabilities.first(where: { $0.player?.id == appearance.player?.id }) {
            avail.status = .absent
        }
        try? context.save()
    }

    /// Returns a previously absent player to the bench (late arrival).
    /// Resets `secondsCredited` to `secondsPlayed` so credits track actual time from now.
    func returnToBench(_ appearance: PlayerGameAppearance) {
        appearance.onFieldStatus   = .bench
        appearance.secondsCredited = appearance.secondsPlayed

        if let avail = game.availabilities.first(where: { $0.player?.id == appearance.player?.id }) {
            avail.status = .available
        }
        try? context.save()
    }
}

// MARK: – Position display helper (field diagram top → bottom ordering)

extension Position {
    var displayRow: Int {
        switch self {
        case .attacker:   return 0
        case .midfielder: return 1
        case .defender:   return 2
        case .goalkeeper: return 3
        }
    }
}
