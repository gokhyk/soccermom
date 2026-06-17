import Foundation

/// Pure functions for game-start rules. No SwiftUI/SwiftData imports.
enum GameStartLogic {
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

    /// Returns true when |now − scheduledDate| exceeds mismatchWindowSeconds.
    /// `now` is injectable so callers and tests can control the clock.
    static func isDateMismatch(scheduledDate: Date, now: Date) -> Bool {
        abs(now.timeIntervalSince(scheduledDate)) > mismatchWindowSeconds
    }
}
