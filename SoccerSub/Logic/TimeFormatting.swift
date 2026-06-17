// No SwiftData or SwiftUI imports — pure Swift.

enum TimeFormatting {
    /// Formats a played-time duration for a compact roster cell.
    ///
    /// Rules:
    ///   0 s        → "0 min"
    ///   1–59 s     → "Xs sec"
    ///   whole mins → "X min"
    ///   mixed      → "Xm Ys"
    static func format(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let minutes = s / 60
        let secs    = s % 60
        switch (minutes, secs) {
        case (0, 0): return "0 min"
        case (0, _): return "\(secs) sec"
        case (_, 0): return "\(minutes) min"
        default:     return "\(minutes)m \(secs)s"
        }
    }
}
