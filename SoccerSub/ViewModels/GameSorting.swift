import Foundation

/// Sorting rule for the Game Management list (documented):
///
/// Priority groups (lower = higher in list):
///   0 — inProgress  (sorted ascending by dateTime — should normally be at most one)
///   1 — scheduled   (sorted ascending by dateTime — soonest upcoming first)
///   2 — completed   (sorted descending by dateTime — most recent past game at top)
///
/// Rationale: coach sees the active game first, then upcoming games in the order
/// they will be played, then history with the most recent past game nearest the top.
enum GameSorting {
    static func sorted(_ games: [Game]) -> [Game] {
        games.sorted { a, b in
            let pa = priority(a.status)
            let pb = priority(b.status)
            guard pa == pb else { return pa < pb }
            return a.status == .completed
                ? a.dateTime > b.dateTime   // completed: newest first
                : a.dateTime < b.dateTime   // upcoming/active: soonest first
        }
    }

    private static func priority(_ status: GameStatus) -> Int {
        switch status {
        case .inProgress: return 0
        case .scheduled:  return 1
        case .completed:  return 2
        }
    }
}
