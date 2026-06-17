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
        isRunning = true
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
        isPeriodEnded    = false
        isGameOver       = true
        game.status      = .completed
        try? context.save()
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
