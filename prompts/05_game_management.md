# Prompt 05 — Game Management screen

Read docs/SPEC.md's Game Management section.

Build the Game Management screen for the active team: a list of games (past and
upcoming), and a create/edit form with opponent, field, optional address, date/time,
and the four rule overrides (players on field, periods, period duration, break
duration) pre-filled from the team's defaults but independently editable per game.

Add the view-model and unit tests covering: creating a game inherits team defaults
correctly, editing a game's overrides doesn't affect the team's defaults or other
games, and the game list sorts/filters sensibly (e.g. upcoming first, or chronological
— pick one and document it).

Run tests, confirm passing, then stop.
