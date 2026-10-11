---
feature: 1676-makepoststate-skipped-outcome
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 5
planned_at: fe015970
updated_at: fe015970
suite_baseline: green
---

# Test List: MakePostState records on the skipped outcome (hand-step flow inherits)

Single-point write-side fix in the run driver's `recordMakePostState`
block — no consumer change, no gate change. The behaviors are driver-level
contracts on the fake-zfa harness (scripted `make` outcomes) plus one
command-level inheritance variant. One behavior per line, traced to the
spec's success criteria.

## Inner loop: driver-level behaviors (`run_driver_core.dart` recording gate)

### `test/plugins/tdd/run_driver_1652_make_post_state_test.dart` (revised + new)

| id | behavior                                                                                     | traces | kind             | state | test                                                                                          |
| --- | ------------------------------------------------------------------------------------------- | ------ | ---------------- | ----- | --------------------------------------------------------------------------------------------- |
| U5a | A green make records the certified post-state (unchanged — the #1652 contract stays verbatim) | SC-5   | characterization | DONE  | existing `U5a` (green verdict byte-identical, digests match)                                   |
| U5b | The #694 skip transition records its own certification: record exists, names the skipping behavior, digests match the on-disk trees, verdict contains `outcome=skipped` | SC-1 | example | DONE | revised `U5b` (was "skip writes nothing" — overturned by #1676) |
| U5b2 | The exit-disagreeing skip token (`outcome=skipped`, exit 1 — bug #986 terminal classification) records under the same gate, with the real exit code in the verdict | SC-2 | example | DONE | new `U5b2` |
| U5c | A record write failure is a warning, never an error (unchanged)                              | SC-4   | characterization | DONE  | existing `U5c`                                                                                |
| U6  | The record describes one moment: a later tree change makes its digests stale (unchanged)      | SC-4   | characterization | DONE  | existing `U6`                                                                                 |

### `test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart` (new variant)

| id | behavior                                                                                     | traces | kind    | state | test        |
| --- | ------------------------------------------------------------------------------------------- | ------ | ------- | ----- | ----------- |
| A1s | A skip-written record (`green_verdict` names `outcome=skipped`) on the current tree inherits the pipeline: zero suite spawns, the honest verdict is printed, ledger untouched | SC-3 | example | DONE | new `A1s` |

## Invariants and edge cases still to place

- Guarded by existing suites (must stay green, no change):
  - Tree/baseline/config/exempt mismatch, corrupt record, flag-less
    standalone, `--full-reproof` → full pipeline (SC-4: A2, U1a, U1b,
    U1c, U2, U2b, U3, U7, U8).
  - Ledger precedence over the make record (SC-4: U4).
  - Skip/exit-disagreeing skip defer the following refactor exactly like
    a green make (A1b, A1c in issue_1652_defer_phase1_refactor_test.dart).
- Out of scope per the spec's single-point constraint: the adoption
  classes (`adopted`, `adopted-placeholder`, `adopted-interrupted`) keep
  their non-recording behavior; the refactor-side consumer is untouched.
