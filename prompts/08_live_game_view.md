# Prompt 08 — Live Game View

Read docs/SPEC.md's Live Game View section.

Build the Live Game View: a soccer-field diagram (simple shapes are fine, doesn't need
to be fancy) showing starters at their assigned positions, a "Whistle" button, and a
top bar showing current period + elapsed time. Pressing Whistle starts the period
clock (use a Timer-driven or Date-based elapsed-time approach — prefer computing
elapsed time from a start Date over accumulating with a repeating Timer tick, so
backgrounding the app doesn't desync the clock).

While the clock runs, increment each on-field player's PlayerGameAppearance.
secondsPlayed (and secondsCredited, since they're present) once per second of game
time. Wire in the engine from prompt 07: ~60 seconds before the next checkpoint, show
an overlay with the recommended sub pairs and a "Sub Complete" button; applying it
updates onFieldStatus/positionAssigned for everyone involved and logs a
SubstitutionLog entry per pair. Add a Bench/Absent section reflecting current state.

Add a view-model and unit tests for the parts that aren't pure UI: the
elapsed-time-from-Date calculation, the per-second tick correctly routing to
secondsPlayed/secondsCredited only for on-field players, and the overlay trigger
firing at the right point relative to the checkpoint from prompt 07's logic.

Run tests, confirm passing, then stop.
