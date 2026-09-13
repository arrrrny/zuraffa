---
feature: 1537-dead-end-machinery-coverage
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 6
planned_at: 46fe766
updated_at: 46fe766
suite_baseline: green
---

# Test List: Dead-end machinery pinning (criterion-token seam, keep and pin)

The machinery under test is a CLI-observable behaviour of `zfa tdd plan`
(`plan_command.dart`) — the loop is outside-in: every behavior drives the
command through `CliRunner.runCapturing` against a `Directory.systemTemp`
fixture spec, asserting stdout rendering, the exit code, and the `--json`
verdict envelope. The pinning behaviors live beside the existing #1481
guards they extend.

## Outer loop: CLI behaviors

### `zfa tdd plan` — the fatal dead-end class is LIVE (criterion-only trace binding)

| id | behavior                                                                                     | traces | kind    | state | test                                                                                                   |
| --- | ------------------------------------------------------------------------------------------- | ------ | -------- | ---- | ------------------------------------------------------------------------------------------------------- |
| P1  | A `[persistent]` FR with a criterion-only inline `traces:` binding plans exit 0 under default flags, rendering the fatal route line and the one-line tally naming U1 | SC-1 | example | DONE | `test/plugins/tdd/commands/plan_command_bug_1481_test.dart::the fatal dead-end machinery is LIVE — criterion-only trace bindings` |
| P2  | The same routing without the `[persistent]` tag reaches the tally under `--allow-unit-fallback` (exit 0, tally names U1) | SC-2 | example | DONE | `...plan_command_bug_1481_test.dart::the flag route — --allow-unit-fallback reaches the same tally`      |
| P3  | The `--json` verdict envelope records `details.dead_end_behaviors == 1` for the persistence route | SC-3 | example | DONE | `...plan_command_bug_1481_test.dart::the verdict envelope counts the dead end (dead_end_behaviors == 1)` |

### Guard quality (mutant red evidence, recorded not asserted in the suite)

| id | behavior                                                                                     | traces | kind             | state | test                                             |
| --- | ------------------------------------------------------------------------------------------- | ------ | ---------------- | ---- | ------------------------------------------------- |
| M1  | Deleting the machinery (deadEnds.add + fatal prefix + tally calls + verdict keys) turns P1/P2/P3 RED | SC-4 | characterization | DONE | recorded evidence `tdd/red-1537.log` (deletion mutant run) |
| M2  | Restoring the machinery returns P1/P2/P3 to GREEN with the #1481 guards intact                    | SC-4, SC-5 | characterization | DONE | recorded evidence `tdd/green-1537.log` (full file run) |

## Invariants and edge cases still to place

- SC-6 (provenance-doc correction in `plan_command.dart`, comments only) is
  non-behavioural — covered by the T003 implement step, `dart analyze`, and
  the unchanged green suite, not by a new test.
- The criterion-token skip in `RoutingResolver` is out of scope (shared
  make/gen cell shape) per the spec's hard constraints.
