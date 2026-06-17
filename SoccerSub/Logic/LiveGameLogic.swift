import Foundation

/// Pure, dependency-free functions for live-game time tracking.
/// No SwiftUI/SwiftData imports — fully unit-testable in isolation.
enum LiveGameLogic {

    /// A value-type snapshot of a single player's in-game state.
    struct PlayerState: Equatable {
        let id: UUID
        let status: OnFieldStatus
        var secondsPlayed: Int
        var secondsCredited: Int
    }

    /// Seconds elapsed since `startDate`, clamped to a minimum of 0.
    /// Using Date arithmetic (not accumulated increments) keeps the clock
    /// accurate when the app is backgrounded.
    static func elapsedSeconds(since startDate: Date, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(startDate)))
    }

    /// Applies `delta` elapsed seconds to a snapshot array of player states.
    ///
    /// - Only `.onField` players accumulate time.
    /// - `.bench` and `.absent` players are returned unchanged.
    /// - For on-field players, `secondsCredited` mirrors `secondsPlayed`
    ///   (credited = actual when the player is present and playing).
    /// - Returns the original array unchanged when `delta <= 0`.
    static func applyTick(to players: [PlayerState], delta: Int) -> [PlayerState] {
        guard delta > 0 else { return players }
        return players.map { p in
            guard p.status == .onField else { return p }
            var updated = p
            updated.secondsPlayed   += delta
            updated.secondsCredited  = updated.secondsPlayed
            return updated
        }
    }
}
