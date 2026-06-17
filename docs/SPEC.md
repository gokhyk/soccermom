# Product Spec — SoccerSub Coach App (v1)

## Overview
An iPhone app for a volunteer parent coach to manage one or more youth soccer teams,
with the primary goal of giving every kid fair playing time across the season. All
data lives on-device.

## Screens

### Main Screen
Hub with navigation to: Team Selection, Team Setup, Roster Management, Game
Management, Color Theme Management.

### Team Selection
Dropdown/picker listing all teams the coach manages. Selecting a team sets it as the
"active" team for every other screen (roster, games, etc.) until changed.

### Team Setup
- Create more than one team.
- Fields: team name, local league name, age group.
- Selecting an age group auto-populates defaults (see table below) for: players on
  field, number of periods (2 or 4), period duration, break duration(s). All of these
  remain editable afterward via increment/decrement controls, since local league rules
  vary.

#### Age group defaults (starting points — adjustable per team)
| Age group | Players on field | Periods | Period duration | Break duration |
|---|---|---|---|---|
| U6  | 4  | 4 | 8 min  | 2 min  |
| U8  | 6  | 4 | 10 min | 2 min  |
| U10 | 7  | 2 | 25 min | 5 min  |
| U12 | 9  | 2 | 30 min | 5 min  |
| U14 | 11 | 2 | 35 min | 10 min |
| U16/U19 | 11 | 2 | 40 min | 10 min |

These are common youth-soccer ballparks, not a rulebook — every value must stay
editable per team to match local league rules.

### Roster Management
- Add/edit players: name, jersey number.
- Eligible positions, default all ON, individually toggleable off: Goalkeeper,
  Defender, Midfielder, Attacker.
- Season played time, stored internally in seconds, displayed in minutes.

### Color Theme Management
- Theme choice applies app-wide, immediately.
- Palette should read as a soccer field (greens) plus a high-contrast accent set that
  stays legible in direct sunlight (avoid low-contrast pastels; favor saturated,
  high-contrast combinations).
- Ship with at least one default theme; structure it so more themes can be added later
  without rework.

### Game Management
- Create games ahead of time; maintain a list of upcoming/past games.
- Per-game fields: opponent, field, address (optional), date/time.
- Per-game overrides (default from the active team's setup, but editable per game for
  tournaments with different rules): players on field, number of periods, period
  duration, break duration.
- Selecting a game from the list opens the Availability view.

### Availability View (pre-game)
- Shows every roster player with an availability status: Available, Absent (the algorithm only draws from Available players).
- Substitution frequency selector: Frequent / Normal / Infrequent.
- "Start Game" button at the top.
- Pressing Start Game when the system date/time doesn't match the game's scheduled
  date/time prompts the coach to either proceed anyway (overwrite) or go back (in case
  the wrong game was selected).

### Live Game View
- Soccer-field diagram showing the starting lineup in their positions.
- "Whistle" button: coach calls each starter's name/position, sends them out, then
  presses Whistle when the referee actually starts play — this starts the period
  clock.
- Top bar: current period and elapsed/remaining time.
- Continuous tracking: every on-field player's played-seconds increments while the
  clock runs.
- ~60 seconds before a computed substitution point, the app surfaces an overlay
  listing recommended sub pairs (player out → player in), built from the fair-play
  engine. Coach reviews, then taps "Sub Complete" to apply — the field view updates
  with the new lineup, and a Bench/Absent section reflects who's now off.
- This repeats for the whole game (across periods/breaks) until the game ends.

#### Edge cases
- Injury / early leave: coach taps the on-field player's name → app removes them from
  the field and proposes a suitable bench replacement (same logic as a normal sub:
  eligible position + least played).
- Tapping a bench player marks them Absent (they leave the pool entirely for this
  game).
- Tapping a name in the Absent list means they arrived late: move them to Bench, and
  they become eligible for future substitutions in this game.

## Out of scope for v1
- Optimizing substitutions to win games (only fairness in v1; flagged as a possible
  future mode).
- Cloud sync / multi-device / accounts.
- Any opponent-side tracking, scorekeeping, or stats beyond playing time.
