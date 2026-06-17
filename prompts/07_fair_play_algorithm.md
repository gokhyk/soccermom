# Prompt 07 — Fair-play substitution engine (core logic, no UI)

Read docs/DATA_MODEL.md's "Substitution engine" section carefully — this is the heart
of the app and the most important thing to get right and well-tested.

In Logic/, implement the substitution engine as pure, dependency-free Swift
functions/types (no SwiftData, no SwiftUI — it should take plain structs in and return
plain structs out, so it's trivial to unit test and to swap later for a
"win-optimized" mode without touching this code). At minimum implement:
- a function that computes the next substitution checkpoint given elapsed time,
  period length, and substitutionFrequency
- a function that, given on-field players (with current secondsPlayed + position) and
  bench players (with secondsPlayed + eligible positions), returns the recommended
  (playerOut, playerIn, position) pairs
- a function that applies a single immediate substitution (for the injury/early-leave
  edge case) given one outgoing player and the same bench pool

Write a thorough unit test suite — this is the one piece of logic that deserves heavy
coverage. Cover: even pairing across players with different played-time deltas,
position-eligibility filtering (a bench player who can't play the open position is
skipped even if they're least-played), behavior when no bench player fits any open
position, behavior with very few/many bench players, and each substitutionFrequency
setting producing a different checkpoint cadence.

Run tests, confirm passing, then stop. No UI changes in this prompt.
