# Test List: 1587-make-skip-or-batch-build

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | generation writes no build-relevant file → terminal `build` step skipped: no `zfa build` spawn in the fake-zfa argv log, skip note printed naming issue #1587, synthetic audit step (exit 0 + skip note) in the green evidence's generation block, make outcome green exit 0. | AC-1 | DONE |
| A2 | generation DOES write a build-relevant input (subject rewrite under lib/) → terminal `build` step runs exactly as before; the #737/#942/#1407 failed-build guards keep their contracts. | AC-2 | DONE |
| A3 | certified red with matching subject-hash as the LAST entry → make precondition satisfied from the certification: zero precondition target-test subprocesses, dedup note printed, generation + live green evidence unchanged. | AC-3 | DONE |
| A4 | hashless certified red OR drifted subject → live drift-check re-run exactly as before (fail open; never a silent pass). | AC-4 | DONE |
| A5 | green entry after the last red → live drift check; already-green skip transition (outcome=skipped) and #1036 subject-drift refusal unchanged. | AC-5 | DONE |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `canSkipTerminalBuild` skips on empty changed set and on plain un-annotated `.dart` writes. | FR-001 | DONE |
| U2 | `canSkipTerminalBuild` refuses on annotated writes (`@Zorphy`, `@JsonSerializable`, `@HiveType`, `@Route`), config-file changes, deletions, and non-dart writes. | FR-001 | DONE |
| U3 | a skipped build step is captured as a synthetic `GenerationStep` with exit 0, the skip reason in output, and `buildSkipped: true`; the generation block renders the additive note line. | FR-002 | DONE |
| U4 | when the build step RUNS, the pipeline result and the #942/#1407 build-output verdicts are byte-identical to the pre-fix contract. | FR-003 | DONE |
| U5 | the dedup certificate requires: last entry is red, carries a 64-hex subject-hash, exit == 1, and the current subject sha256 equals it. | FR-004 | DONE |
| U6 | the dedup fails open on every unmet condition (hashless, drifted, green/refactor after red). | FR-005 | DONE |
| U7 | the post-generation green-evidence target test stays a live run in both the skip and dedup paths. | FR-006 | DONE |
| U8 | the runner's scheduling flag defaults to OFF — a caller that does not opt in spawns the build step unchanged. | FR-008 | DONE |
