# Prompt 06 — Availability view + Start Game flow

Read docs/SPEC.md's Availability View section.

Build the Availability screen, opened when a game is selected from the Game
Management list: every roster player with a status picker (Available/Sick/
Injured/Out of town), a substitution-frequency selector (Frequent/Normal/Infrequent),
and a Start Game button at the top.

Implement the date/time mismatch check: if the system's current date/time doesn't
fall on the same day (or within a reasonable window — decide and document) as the
game's scheduled date/time, show a confirmation dialog with "Start Anyway" and "Go
Back" options before proceeding.

Wire Availability records into SwiftData (one per player per game), and
compute+store each PlayerGameAppearance's initial secondsCredited per the crediting
rule in docs/DATA_MODEL.md (available players get a placeholder that will update
live; unavailable players get the fixed target-average value computed from current
availability counts).

Write unit tests for: target-seconds calculation given a set of available/unavailable
players, crediting assignment for absent vs available players, and the date-mismatch
detection logic (use an injectable/fake "now" rather than the real clock so this is
testable).

Run tests, confirm passing, then stop. Starting the game can navigate to a placeholder
Live Game screen for now — prompt 08 builds the real one.
