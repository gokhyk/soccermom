# Prompt 10 — Season totals, polish, and a light QA pass

This is the wrap-up step once 01–09 are done and individually tested.

1. Roll PlayerGameAppearance.secondsPlayed/secondsCredited up into Player.
   seasonPlayedSeconds/seasonCreditedSeconds whenever a game is marked completed, and
   surface season totals on the Roster Management screen (already has a
   season-minutes field from prompt 03 — wire it to real data now).
2. Add a simple "end game" action (manual button is fine for v1) that marks the Game
   as completed and triggers the roll-up above.
3. Do a pass over every screen built so far against the color theme from prompt 04 —
   make sure nothing is hardcoding colors outside the theme.
4. Write integration-style tests (still XCTest/Swift Testing, not UI tests) that
   simulate a full short game end-to-end: create a team/players/game, mark some
   absent, run through several checkpoints' worth of simulated elapsed time, apply
   suggested subs, end the game, and assert the season totals come out as expected
   (everyone's seconds should be close to equal, absent players credited at target,
   not zero).
5. Run the full test suite. Fix anything broken before stopping.

This concludes v1. Future work (not in scope now): win-optimized substitution mode,
multi-device sync, opponent scorekeeping.
