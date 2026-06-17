# Prompt 04 — Color theme management

Read docs/SPEC.md's Color Theme Management section.

In Theme/, define a Theme model (plain Swift struct, not SwiftData — themes are app
config, not user data) with named colors for: primary field green, secondary green,
background, text, on-field player marker, bench marker, absent marker, and an accent
color for buttons/alerts. Ship one default "Field & Sun" theme using saturated,
high-contrast colors that stay readable outdoors (avoid washed-out pastels).

Build a ThemeManager (Observable) that holds the active theme and is injected into the
SwiftUI environment so every screen can read from it instead of hardcoding colors.
Build the Color Theme Management screen: lets the coach pick from available themes and
see a live preview; selecting one updates the whole app immediately.

Write unit tests for ThemeManager: default theme loads on first launch, switching
themes persists the choice (UserDefaults is fine here — it's app preference, not
domain data) and reloads correctly on relaunch.

Run tests, confirm passing, then stop.
