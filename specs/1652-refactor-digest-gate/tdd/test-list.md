# TDD Test List — Spec 1652-refactor-digest-gate

Red pre-fix: A1 red (today the pipeline always runs — suite spawns
happen, no inheritance line, no no-op cycle-log entry); T007 red (the
driver writes no record on make-green). Every mismatch/guard row
(A2, U1–U6) is GREEN pre-fix by design — they pin today's fallback
behavior so the fix cannot weaken it.

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`.

| id | suite | kind | behavior | traces | state |
| -- | ----- | ---- | -------- | ------ | ----- |
| A1 | test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart | unit | the inheritance hit: a recorded make post-state matching the current tree + gate context + a `--pass-batch` refactor spawn → ZERO suite spawns, exit 0, `outcome=clean`, the `issue #1652` inheritance lines in stdout, a no-op cycle-log entry naming the behavior + capture time + green verdict; `pass-batch.json` not rewritten. | AC-1 / FR-002 / FR-004 / SC-001 | DONE |
| A2 | test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart | unit | tree drift (a `lib/` file touched after the record) → the full pipeline runs: suite spawns increase, no inheritance line. | AC-2 / FR-003 / SC-002 | DONE |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | suite | kind | behavior | traces | state |
| -- | ----- | ---- | -------- | ------ | ----- |
| U1 | test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart | unit | context mismatch re-runs the pipeline: (a) baseline-file rewrite, (b) `dart_test.yaml` rewrite, (c) exempt-set difference between the record and the spawn. | FR-003 / AC-3..5 | DONE |
| U2 | test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart | unit | a corrupt or mistyped record falls back to the full pipeline (safe failure). | FR-003 / AC-6 | DONE |
| U3 | test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart | unit | a flag-less standalone refactor never reads the record, and `--full-reproof` never inherits — both run the full pipeline. | FR-003 / FR-005 / AC-7..8 | DONE |
| U4 | test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart | unit | ledger precedence: a matching `pass-batch.json` (the #1588 full-pipeline proof) inherits via its own evidence line even when the record also matches; the record never overwrites it. | FR-007 | DONE |
| U5 | test/plugins/tdd/run_driver_1652_make_post_state_test.dart | unit | the driver records make's certified post-state on make-green: the record exists with `lib`/`test` digests matching the on-disk trees and a verdict naming the behavior + outcome; the #741 already-green skip writes nothing new; a forced write failure is a warning and the run completes. | FR-001 / FR-006 / AC-9 | DONE |
| U6 | test/plugins/tdd/run_driver_1652_make_post_state_test.dart | unit | a stale record (tree changed after the make) no longer matches the tree: recomputed digests differ — the record describes one moment and is inert. | FR-006 / AC-10 | DONE |

## Red protocol

```
dart test test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart
# expected pre-fix: A1 FAIL (suite spawns happened; no inheritance
# evidence), A2/U1–U4 pass (today's fallbacks).
dart test test/plugins/tdd/run_driver_1652_make_post_state_test.dart
# expected pre-fix: U5 FAIL (no record written); U6 fails for the same
# root cause (the record its staleness check reads does not exist yet).
```
