import Foundation

/// Pure functions for game-start rules. No SwiftUI/SwiftData imports.
enum GameStartLogic {

    // MARK: – Auto-selection input type

    struct StarterCandidate {
        let id: UUID
        let seasonCreditedSeconds: Int
        let eligiblePositions: Set<Position>
    }
    /// ±4 hours around scheduled game time.
    /// Chosen over "same calendar day" to avoid midnight edge cases while still
    /// flagging yesterday's/tomorrow's game being started by mistake.
    static let mismatchWindowSeconds: TimeInterval = 4 * 3600

    /// Target seconds each player should accumulate in a game.
    /// Uses integer division intentionally — the engine works in whole seconds.
    static func targetSeconds(
        periodDurationSeconds: Int,
        numberOfPeriods: Int,
        playersOnField: Int,
        availableCount: Int
    ) -> Int {
        guard availableCount > 0 else { return 0 }
        return (periodDurationSeconds * numberOfPeriods * playersOnField) / availableCount
    }

    // MARK: – Starter auto-selection

    /// Picks the `count` candidates with the least season credited time and assigns each
    /// a position from a balanced slot distribution (1 GK + ~⅓ each DEF/MID/ATT).
    /// When `count` ≥ candidates.count, all candidates are selected.
    static func autoSelectStarters(
        from candidates: [StarterCandidate],
        count: Int
    ) -> [(id: UUID, position: Position)] {
        guard !candidates.isEmpty, count > 0 else { return [] }

        // 1. Sort by least credited time first; stable tie-break is implicit via Swift's sort.
        let sorted = candidates.sorted { $0.seasonCreditedSeconds < $1.seasonCreditedSeconds }
        let starters = Array(sorted.prefix(count))

        return assignPositions(to: starters)
    }

    /// Balanced slot distribution for a given player count.
    /// Always 1 GK; the remainder splits as ⌊r/3⌋ DEF, ⌊r/3⌋ ATT, rest MID.
    static func positionSlots(for count: Int) -> [Position] {
        guard count > 0 else { return [] }
        let remaining = count - 1
        let def = remaining / 3
        let att = remaining / 3
        let mid = remaining - def - att
        return [.goalkeeper]
            + Array(repeating: .defender,  count: def)
            + Array(repeating: .midfielder, count: mid)
            + Array(repeating: .attacker,  count: att)
    }

    private static func assignPositions(to starters: [StarterCandidate]) -> [(id: UUID, position: Position)] {
        var result: [(id: UUID, position: Position)] = []
        var assigned = Set<UUID>()
        let slots = positionSlots(for: starters.count)

        // Greedy pass: for each slot, assign the first unassigned eligible player.
        for slot in slots {
            guard let match = starters.first(where: {
                !assigned.contains($0.id) && $0.eligiblePositions.contains(slot)
            }) else { continue }
            result.append((id: match.id, position: slot))
            assigned.insert(match.id)
        }

        // Fallback: any player not yet assigned gets their first eligible position.
        for candidate in starters where !assigned.contains(candidate.id) {
            let pos = Position.allCases.first(where: { candidate.eligiblePositions.contains($0) })
                ?? .midfielder
            result.append((id: candidate.id, position: pos))
            assigned.insert(candidate.id)
        }

        return result
    }

    /// Returns true when |now − scheduledDate| exceeds mismatchWindowSeconds.
    /// `now` is injectable so callers and tests can control the clock.
    static func isDateMismatch(scheduledDate: Date, now: Date) -> Bool {
        abs(now.timeIntervalSince(scheduledDate)) > mismatchWindowSeconds
    }
}
