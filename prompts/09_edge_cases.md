# Prompt 09 — Edge cases: injury/early leave, bench↔absent

Read docs/SPEC.md's "Edge cases" section.

Add the three interactions to the Live Game View:
1. Tapping an on-field player's name brings up a confirmation, then removes them and
   uses prompt 07's single-substitution function to propose a bench replacement
   (coach confirms before it applies).
2. Tapping a bench player marks them Absent for the rest of the game (freeze their
   secondsCredited at the target-average value, exclude from future pairing).
3. Tapping a name in the Absent list moves them to Bench (re-include them in pairing,
   resume tracking secondsCredited as actual from this point forward).

Write unit tests for all three transitions at the data/view-model level: confirm
appearance status changes correctly, confirm excluded/included players are respected
by the engine immediately after each transition, and confirm secondsCredited
freezes/resumes correctly across an absent↔bench round trip.

Run tests, confirm passing, then stop.
