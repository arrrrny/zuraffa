# Cycle Log: `zfa corpus import`

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/commands test/core/project` -> 53 passed, 0 failed
  (fast tier; `test/cli/services/` is created by this feature)
- commit: `2a6246f3`
- recorded: cycle 0, before any change

## Notes and deviations

- All tests are fast tier (file-I/O only); no subprocess/slow suites.
- Blocks on nothing in the loop; #628's batch driver consumes this
  feature's manifest contract.
- Consumes issue #627 (feature origin) and plan decisions from
  `specs/050-corpus-import/research.md`.