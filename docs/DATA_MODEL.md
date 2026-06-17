# Data Model & Algorithm — SoccerSub Coach App

## Entities

### Team
- id: UUID
- name: String
- leagueName: String
- ageGroup: String (drives defaults, see SPEC.md)
- defaultPlayersOnField: Int
- defaultNumberOfPeriods: Int (2 or 4)
- defaultPeriodDurationSeconds: Int
- defaultBreakDurationSeconds: Int
- colorThemeId: String (key into Theme/)
- players: [Player] (relationship)
- games: [Game] (relationship)

### Player
- id: UUID
- team: Team (relationship)
- name: String
- jerseyNumber: Int
- canPlayGoalkeeper / canPlayDefender / canPlayMidfielder / canPlayAttacker: Bool (default true)
- seasonPlayedSeconds: Int (sum of actual played seconds across all completed games)
- seasonCreditedSeconds: Int (sum of credited seconds — actual when present,
  target-average when absent — used for season fairness comparisons; see algorithm
  section)

### Game
- id: UUID
- team: Team (relationship)
- opponent: String
- field: String
- address: String? (optional)
- dateTime: Date
- playersOnField, numberOfPeriods, periodDurationSeconds, breakDurationSeconds: Int
  (defaults copied from Team at creation, independently editable per game)
- substitutionFrequency: enum { frequent, normal, infrequent }
- status: enum { scheduled, inProgress, completed }
- availabilities: [Availability] (relationship)
- appearances: [PlayerGameAppearance] (relationship)

### Availability
- id: UUID
- game: Game
- player: Player
- status: enum { available, absent }
(Only created/edited from the pre-game Availability view; defaults to available if not
set.)

### PlayerGameAppearance (per-player, per-game running record)
- id: UUID
- game: Game
- player: Player
- secondsPlayed: Int (actual, ticks up live while on field)
- secondsCredited: Int (equals secondsPlayed for present players; set to that game's
  target average for absent players, see below)
- onFieldStatus: enum { onField, bench, absent } (live-game runtime state; persisted so
  the app can resume if interrupted)
- positionAssigned: enum? { goalkeeper, defender, midfielder, attacker } (current
  position while on field)

### SubstitutionLog (history; useful for in-game review/undo)
- id: UUID
- game: Game
- timestamp: Date (or elapsed-seconds-in-game)
- playerOut: Player?
- playerIn: Player?
- reason: enum { scheduled, injury, earlyLeave, lateArrival }

## Core formulas

Target seconds per player for a game:
```
targetSeconds = (periodDurationSeconds * numberOfPeriods * playersOnField) / availablePlayersCount
```
`availablePlayersCount` = count of players with Availability == available for that
game.

Crediting rule (season fairness):
```
if player.availability == .available:
    appearance.secondsCredited = appearance.secondsPlayed   // updates live
else:
    appearance.secondsCredited = targetSeconds              // fixed at game creation/start
```

## Substitution engine (pure function, lives in Logic/, no SwiftData/SwiftUI)

Inputs: list of on-field players with secondsPlayed + position, list of bench players
(available, not absent) with secondsPlayed + eligible positions, targetSeconds,
substitutionFrequency.

1. Compute the next "checkpoint" in game-clock seconds, based on substitutionFrequency
   (e.g. frequent ≈ every 4 minutes of period time, normal ≈ 7, infrequent ≈ 12 — tune
   during build, expose as constants so they're easy to adjust).
2. ~60 seconds before that checkpoint, build candidate pairs:
   - Sort on-field players by secondsPlayed descending → candidates to come off.
   - Sort bench players by secondsPlayed ascending → candidates to go on.
   - Walk both lists, pairing each "off" candidate with the "on" candidate whose
     eligible positions include the outgoing player's current position, skipping bench
     players who don't fit any open slot.
   - Stop once swapping further would no longer reduce the played-time gap, or once a
     max-subs-per-stoppage limit is hit (keep configurable, default unlimited within
     reason).
3. Return the list of (playerOut, playerIn, position) pairs for the UI to render in
   the sub-suggestion overlay.
4. On "Sub Complete," apply all pairs atomically: update each appearance's
   onFieldStatus and positionAssigned, write a SubstitutionLog entry per pair.

## Edge-case logic
- Injury/early leave: same matching step as #2 above, but triggered immediately for a
  single player rather than waiting for a checkpoint, and only proposing one
  replacement.
- Bench → Absent (tap on bench player): set Availability/appearance status to absent,
  exclude from future pairing this game, freeze secondsCredited at the target-average
  value computed at availability time.
- Absent → Bench (tap on absent player, "arrived late"): set back to bench, re-include
  in pairing logic, resume tracking secondsCredited as actual from this point forward.
