# CLAUDE.md — SoccerSub Coach App

This file is read automatically by Claude Code at the start of every session in this
repository. It is the source of truth for how this project should be built. Read
`docs/SPEC.md` and `docs/DATA_MODEL.md` for more detail before writing code.

## What this app is
A native iPhone app for a parent volunteer coach managing one or more youth soccer
teams. The core feature is a fair-playing-time substitution assistant: during a live
game, the app tracks each player's on-field seconds and prompts the coach with
substitution suggestions so that, over the course of the season, every player gets as
close to equal playing time as possible. No backend, no accounts, no cloud sync —
everything is stored on-device.

## Tech stack (use this, don't deviate without asking)
- Swift 5.10+, SwiftUI for all UI
- SwiftData (iOS 17+) for local persistence — no Core Data, no third-party DB
- Swift Testing (or XCTest if Swift Testing isn't set up) for unit tests
- MVVM-ish: SwiftData models are the source of truth; plain Swift structs/classes hold
  pure business logic (especially the substitution algorithm) so it can be unit-tested
  without touching SwiftUI or SwiftData
- Minimum target: iOS 17
- No external dependencies unless explicitly approved — keep this a zero-dependency
  project if at all possible

## Project structure
```
SoccerSub/
  Models/        SwiftData @Model classes (Team, Player, Game, Availability, ...)
  Logic/         Pure, dependency-free business logic (fair-play algorithm, time math, defaults)
  Views/         SwiftUI screens, one folder per feature area
  ViewModels/    Observable view models, one per screen, holding state
  Theme/         Color theme definitions + theme manager
  Tests/         Unit tests, mirroring Models/Logic structure
```

## Working agreement
- Build in the order laid out in `prompts/` (00 through 10). Each prompt file is a
  self-contained unit of work: read it, implement it, write/run tests for it, confirm
  tests pass, then stop and report back before moving to the next one.
- The fair-play algorithm and time math live in `Logic/` as plain Swift with no
  SwiftUI/SwiftData imports, so they can be tested in isolation. Views call into Logic;
  they never contain the math themselves.
- Every new model and every new piece of Logic gets unit tests in the same prompt/step
  that introduces it — don't defer testing to a later phase.
- After each meaningful change, build (`xcodebuild build`) and run the relevant test
  target before continuing.
- Don't introduce networking, cloud sync, authentication, or analytics. This app is
  fully offline by design.
- All durations are stored internally in seconds (Int). Convert to minutes only for
  display.

## Core domain rules (keep these consistent everywhere)
- Target playing time per player for a game =
  `(periodDuration_seconds * numberOfPeriods * playersOnField) / availablePlayersCount`.
  This is the number every player "should" reach by the end of the game.
- A player marked absent for a game is still credited with that game's target playing
  time for season-fairness purposes (so missing a game never makes them look more
  "owed" time later). Their actual `secondsPlayed` for that game stays 0; track
  credited and actual separately.
- Within a live game, the substitution engine ranks on-field players by seconds played
  descending (most-played = first candidates to come off) and bench players by seconds
  played ascending (least-played = first candidates to go on), and only matches
  players whose eligible positions overlap with the open slot.
- Substitution frequency (frequent / normal / infrequent) sets how often the engine
  looks for swaps — implement as a configurable interval (e.g. frequent ≈ every 4 min,
  normal ≈ every 7 min, infrequent ≈ every 12 min of period time), not a hardcoded
  one-size value.
- See `docs/DATA_MODEL.md` for the exact entities, fields, and algorithm pseudocode.

## Commands
- Build: `xcodebuild -scheme SoccerSub -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Test: `xcodebuild -scheme SoccerSub -destination 'platform=iOS Simulator,name=iPhone 15' test`
(Adjust scheme/destination names once the Xcode project is created in prompt 01.)

## What "done" looks like for the v1 scope
Everything described in `docs/SPEC.md`, ending with the live-game substitution flow and
its edge cases (injury/early-leave swap, bench↔absent toggling). Win-optimized
substitution strategy is explicitly out of scope for v1 — fairness only.
