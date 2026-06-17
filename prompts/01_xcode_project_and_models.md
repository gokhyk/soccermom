# Prompt 01 — Project scaffold + SwiftData models

Read CLAUDE.md and docs/DATA_MODEL.md first.

Set up a new iOS app project named SoccerSub (SwiftUI App lifecycle, iOS 17 minimum,
SwiftData enabled) with the folder structure described in CLAUDE.md (Models/, Logic/,
Views/, ViewModels/, Theme/, Tests/).

Implement the SwiftData @Model classes for Team, Player, Game, Availability, and
PlayerGameAppearance exactly as specified in docs/DATA_MODEL.md, with the correct
relationships between them (Team↔Player, Team↔Game, Game↔Availability,
Game↔PlayerGameAppearance, Player↔PlayerGameAppearance). Use enums where the data
model specifies them (ageGroup can be a String for now, but substitutionFrequency,
availability status, onFieldStatus, and position should be real Swift enums).

Write unit tests in Tests/ that:
- create a Team with players and a Game, and confirm the relationships resolve
  correctly in both directions
- confirm a SwiftData ModelContainer can be created and saved/fetched round-trip for
  each model
- confirm enum-backed fields encode/decode correctly through SwiftData

Run the tests and make sure they pass before stopping. Don't build any UI yet.
