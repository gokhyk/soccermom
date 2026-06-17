# Prompt 03 — Roster Management screen

Read docs/SPEC.md's Roster Management section.

Build the Roster Management screen for the currently active team: list players, add a
new player, edit an existing one. Fields: name, jersey number, four position toggles
(Goalkeeper/Defender/Midfielder/Attacker, default on), and a read-only display of
season played time — store seconds (seasonPlayedSeconds on Player) and format it as
minutes for display (write a small formatting helper in Logic/ with a unit test, e.g.
1530 seconds → "25 min" or "25m 30s", whichever reads best on a small screen).

Add the view-model and unit tests covering: adding a player persists correctly,
toggling a position off and saving preserves the other three, jersey number
validation (must be a positive integer, and ideally unique within the team — decide
and document whichever rule you implement), and the seconds→minutes formatting
helper.

Run tests, confirm passing, then stop.
