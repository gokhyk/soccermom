import Foundation

// MARK: – Input types

struct OnFieldPlayer: Equatable {
    let id: UUID
    let secondsPlayed: Int
    let position: Position    // position currently assigned on the field
}

struct BenchPlayer: Equatable {
    let id: UUID
    let secondsPlayed: Int
    let eligiblePositions: Set<Position>   // positions this player is allowed to cover
}

// MARK: – Output type

struct SubstitutionPair: Equatable {
    let playerOut: OnFieldPlayer
    let playerIn: BenchPlayer
    let position: Position                 // slot being filled
}

// MARK: – Engine

enum SubstitutionEngine {

    // Cadence constants (seconds of period-elapsed time). Expose as named constants
    // so they're easy to tune without hunting through logic.
    static let frequentIntervalSeconds:   Int = 240   // 4 min
    static let normalIntervalSeconds:     Int = 420   // 7 min
    static let infrequentIntervalSeconds: Int = 720   // 12 min

    // Surface the sub-suggestion overlay this many seconds before a checkpoint.
    static let warningLeadSeconds: Int = 60

    // MARK: Checkpoint helpers

    static func intervalSeconds(for frequency: SubstitutionFrequency) -> Int {
        switch frequency {
        case .frequent:   return frequentIntervalSeconds
        case .normal:     return normalIntervalSeconds
        case .infrequent: return infrequentIntervalSeconds
        }
    }

    /// Next substitution checkpoint within the current period (in period-elapsed seconds).
    /// Returns nil when no checkpoint remains (elapsed is too close to period end).
    static func nextCheckpoint(
        elapsedPeriodSeconds: Int,
        periodDurationSeconds: Int,
        frequency: SubstitutionFrequency
    ) -> Int? {
        let interval = intervalSeconds(for: frequency)
        let next = ((elapsedPeriodSeconds / interval) + 1) * interval
        return next <= periodDurationSeconds ? next : nil
    }

    /// True when the sub-suggestion overlay should be displayed to the coach.
    /// Called on each clock tick with the current period-elapsed time.
    static func shouldPromptSubstitution(
        elapsedPeriodSeconds: Int,
        periodDurationSeconds: Int,
        frequency: SubstitutionFrequency
    ) -> Bool {
        guard let checkpoint = nextCheckpoint(
            elapsedPeriodSeconds: elapsedPeriodSeconds,
            periodDurationSeconds: periodDurationSeconds,
            frequency: frequency
        ) else { return false }
        return (checkpoint - elapsedPeriodSeconds) <= warningLeadSeconds
    }

    // MARK: Scheduled substitution

    /// Builds the recommended (playerOut, playerIn, position) pairs for a planned stoppage.
    ///
    /// Algorithm:
    ///   1. Sort on-field players descending by secondsPlayed (most played → first off).
    ///   2. Sort bench players ascending by secondsPlayed (least played → first on).
    ///   3. For each off-candidate, find the least-played bench player who can fill
    ///      the open position AND has fewer secondsPlayed than the outgoing player.
    ///      Use `continue` (not `break`) on both miss conditions so that a position
    ///      constraint on one pair does not prevent a valid subsequent pair from forming.
    ///   4. Stop when maxSubstitutions pairs have been collected.
    ///
    /// - Parameters:
    ///   - onField: Players currently on the field.
    ///   - bench: Players on the bench (available, not absent).
    ///   - maxSubstitutions: Cap on pairs returned; default = unlimited.
    static func recommendedSubstitutions(
        onField: [OnFieldPlayer],
        bench: [BenchPlayer],
        maxSubstitutions: Int = Int.max
    ) -> [SubstitutionPair] {
        var result: [SubstitutionPair] = []
        var availableBench = bench.sorted { $0.secondsPlayed < $1.secondsPlayed }
        let sortedOnField  = onField.sorted { $0.secondsPlayed > $1.secondsPlayed }

        for outgoing in sortedOnField {
            if result.count >= maxSubstitutions { break }

            // Find the least-played bench player who can fill this position.
            guard let matchIdx = availableBench.firstIndex(where: {
                $0.eligiblePositions.contains(outgoing.position)
            }) else {
                continue   // no bench player can play this position
            }

            let incoming = availableBench[matchIdx]

            // Only propose the swap if it actually reduces the played-time gap.
            guard incoming.secondsPlayed < outgoing.secondsPlayed else {
                continue   // this specific swap would not improve fairness
            }

            result.append(SubstitutionPair(
                playerOut: outgoing,
                playerIn: incoming,
                position: outgoing.position
            ))
            availableBench.remove(at: matchIdx)
        }

        return result
    }

    // MARK: Immediate substitution (injury / early leave)

    /// Finds the single best replacement for an urgent sub.
    /// Unlike `recommendedSubstitutions`, this ignores the played-time gap check —
    /// an injury forces a swap regardless of fairness.
    /// Returns nil when no bench player can cover the outgoing player's position.
    static func immediateSubstitution(
        outgoing: OnFieldPlayer,
        bench: [BenchPlayer]
    ) -> SubstitutionPair? {
        let candidate = bench
            .filter  { $0.eligiblePositions.contains(outgoing.position) }
            .min     { $0.secondsPlayed < $1.secondsPlayed }

        guard let incoming = candidate else { return nil }
        return SubstitutionPair(
            playerOut: outgoing,
            playerIn: incoming,
            position: outgoing.position
        )
    }
}
