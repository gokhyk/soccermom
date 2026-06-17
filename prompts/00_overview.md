# How to use these prompts

Feed these into Claude Code one at a time, in order, inside this repository (where
CLAUDE.md, docs/SPEC.md, and docs/DATA_MODEL.md already exist). After each one:
1. Let Claude Code implement it.
2. Have it run the tests it just wrote.
3. Skim the diff/output yourself before moving to the next prompt — these are small,
   reviewable chunks on purpose.

Order: 01 → 10. Don't skip ahead; later steps assume earlier ones exist (e.g. the
algorithm in 07 assumes the models from 01 and the game flow from 05–06).
