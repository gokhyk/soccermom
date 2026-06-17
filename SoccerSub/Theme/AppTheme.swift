import SwiftUI

/// A named palette for one visual theme.  Plain struct — not persisted via SwiftData.
struct AppTheme: Identifiable {
    let id: String
    let name: String

    // ── Field colors ──────────────────────────────────────────
    let fieldPrimary:   Color   // main grass green
    let fieldSecondary: Color   // complementary green (stripe / alternate)

    // ── Surface & text ────────────────────────────────────────
    let background:  Color
    let textPrimary: Color

    // ── Live-game player markers ──────────────────────────────
    let onFieldMarker: Color    // player currently on the pitch
    let benchMarker:   Color    // player on the bench
    let absentMarker:  Color    // player marked absent

    // ── UI chrome ─────────────────────────────────────────────
    let accent: Color           // buttons, selection rings, alerts
}

// MARK: – Equatable (by ID — Color isn't Equatable)
extension AppTheme: Equatable {
    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool { lhs.id == rhs.id }
}

// MARK: – Theme catalog
extension AppTheme {
    /// Saturated, high-contrast palette for outdoor afternoon use.
    static let fieldAndSun = AppTheme(
        id:   "fieldAndSun",
        name: "Field & Sun",
        fieldPrimary:   Color(red: 0.18, green: 0.49, blue: 0.20), // #2E7D32 deep grass
        fieldSecondary: Color(red: 0.40, green: 0.73, blue: 0.42), // #66BB6A lighter green
        background:     Color(red: 0.98, green: 0.98, blue: 0.96), // warm off-white
        textPrimary:    Color(red: 0.10, green: 0.22, blue: 0.10), // very dark green
        onFieldMarker:  Color(red: 0.98, green: 0.66, blue: 0.15), // #F9A825 golden amber
        benchMarker:    Color(red: 0.08, green: 0.40, blue: 0.75), // #1565C0 deep blue
        absentMarker:   Color(red: 0.72, green: 0.11, blue: 0.11), // #B71C1C deep red
        accent:         Color(red: 0.90, green: 0.32, blue: 0.00)  // #E65100 deep orange
    )

    /// Dark palette for evening / indoor venues.
    static let nightMatch = AppTheme(
        id:   "nightMatch",
        name: "Night Match",
        fieldPrimary:   Color(red: 0.10, green: 0.30, blue: 0.12), // dark green
        fieldSecondary: Color(red: 0.16, green: 0.44, blue: 0.18), // medium green
        background:     Color(red: 0.09, green: 0.09, blue: 0.11), // near-black
        textPrimary:    Color(red: 0.92, green: 0.92, blue: 0.92), // near-white
        onFieldMarker:  Color(red: 0.35, green: 0.90, blue: 0.40), // bright green
        benchMarker:    Color(red: 0.35, green: 0.62, blue: 0.95), // sky blue
        absentMarker:   Color(red: 0.95, green: 0.32, blue: 0.32), // bright red
        accent:         Color(red: 0.98, green: 0.76, blue: 0.18)  // bright gold
    )

    /// All available themes in display order.  Add new entries here to extend.
    static let allThemes: [AppTheme] = [.fieldAndSun, .nightMatch]

    /// The theme used on first launch / as fallback for unknown IDs.
    static let defaultTheme: AppTheme = .fieldAndSun
}
