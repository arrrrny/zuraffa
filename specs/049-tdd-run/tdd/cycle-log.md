# Cycle Log: `zfa tdd run`

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 116 passed, 0 failed (fast tier)
- commit: `43841d0c`
- recorded: cycle 0, before any change

## Notes and deviations

- Driver/scenario tests run in the `slow` tier with scripted fake step
  binaries; steps 047 (make) and 048 (refactor) may be unmerged — the driver
  consumes their contracts, not their code.
- Known zuraffa gap (to file via the bug workflow, task T025):
  `plan_command.dart` writes 4-column test-list rows while
  `gen_command.dart`'s parser expects 6 columns — gen cannot parse what plan
  emits. Not fixed by this feature.
