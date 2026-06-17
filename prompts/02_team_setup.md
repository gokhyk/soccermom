# Prompt 02 — Team Setup screen + age-group defaults

Read docs/SPEC.md's Team Setup section and the age-group defaults table.

In Logic/, add a small pure-Swift lookup (no SwiftData/SwiftUI) that maps an
age-group string to its default playersOnField / numberOfPeriods /
periodDurationSeconds / breakDurationSeconds, using the table in docs/SPEC.md. Write
unit tests confirming each age group returns the right defaults and that an
unrecognized age group falls back to a sane default rather than crashing.

In Views/, build the Team Setup screen: create a new team or edit an existing one,
with fields for name, league name, and an age-group picker. When age group changes,
populate the four numeric fields from the Logic lookup above, but keep them editable
via stepper-style increment/decrement controls (don't just show a picker — let the
coach nudge values up/down from whatever the default was). Persist via SwiftData on
save.

Add a view-model layer (ViewModels/) so the screen's logic (defaulting, validation,
save) is testable without instantiating SwiftUI views. Write unit tests for the view
model: changing age group updates the four fields, manual edits after that are
preserved until age group is changed again, saving creates/updates a Team correctly.

Run tests, confirm passing, then stop.
