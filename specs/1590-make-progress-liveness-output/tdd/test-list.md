---
feature: 1590-make-progress-liveness-output
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 8
planned_at: manual-fallback
updated_at: 369dcb00
suite_baseline: green
---

# Test List: 1590-make-progress-liveness-output

`loop: inside-out` — the surface is the progress-output layer of the TDD
driver and the make pipeline (no business objects change); the behaviors
below close at the unit tier against the static line builders and the
spawn primitives, plus the slow-tier run loop for the driven contracts.

Derived via the tdd extension's LLM-guided fallback (no `.zfa.json` at the
repo root — the deterministic `zfa tdd plan` path is unavailable here).

## Outer loop: acceptance behaviors

One per driven-contract acceptance criterion in `spec.md`.

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A-1590-1 | every spawned step prints `[run] <id> <step> — ` positioned BEFORE its `[run] <id> <step> -> ` completion line, with the machine contract unchanged | AC-1, AC-8 | example | DONE    | `test/plugins/tdd/run_command_test.dart` |
| A-1590-2 | the run forwards banner-shaped child lines live (default), everything verbatim under `--verbose`, and heartbeats follow `--heartbeat` (0.05 → lines, 0 → none) | AC-4, AC-5, AC-7 | example | DONE    | `test/plugins/tdd/run_command_test.dart` |

## Unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U-1590-1 | `PipelineRunner.bannerFor`/`nameFor` mapping is exact (func, build+hint, entity create User, make User, mock create, two-arg fallback) and `runPlan` prints one `→ ` banner per spawned step before its spawn | AC-2, FR-002 | unit | DONE    | `test/plugins/tdd/issue_1590_progress_liveness_test.dart` |
| U-1590-2 | make's plan lines name the steps: `   plan: 2 step(s): func, build` and `   plan: composition fallback — 2 step(s): compose, build` | AC-3, FR-003 | unit | DONE    | `test/plugins/tdd/issue_1590_progress_liveness_test.dart` |
| U-1590-3 | the driver's step-start line renders the static per-step hints and the FR-007 resume suffix exactly when the loaded in-flight trio names this behavior+step with a foreign pid | AC-1, AC-6 | unit | DONE    | `test/plugins/tdd/issue_1590_progress_liveness_test.dart` |
| U-1590-4 | the heartbeat line format and the `--heartbeat` parse contract: `… <elapsed> elapsed` via `formatTddTimeout`; '0' → off, '0.05' → 50ms, garbage → TddTimeoutFormatException | AC-4, FR-006 | unit | DONE    | `test/plugins/tdd/issue_1590_progress_liveness_test.dart` |
| U-1590-5 | the runTimed stdout tee fires the callback per complete line in order while `ProcessResult.stdout` stays byte-faithful to the pre-#1590 join | AC-5, FR-004 | unit | DONE    | `test/plugins/tdd/issue_1590_progress_liveness_test.dart` |

## Traceability notes

- AC-2 ↔ U-1590-1 (banner mapping + per-spawn banner print), AC-3 ↔
  U-1590-2, AC-1/AC-6 ↔ U-1590-3 + A-1590-1, AC-4 ↔ U-1590-4 + A-1590-2,
  AC-5 ↔ U-1590-5 + A-1590-2, AC-7 ↔ A-1590-2, AC-8 ↔ A-1590-1 (contract
  smoke) + the pre-existing suites (regression gate, SC-8).
- No behavior touches the state machine, the step argv, or the test
  runner: the implementations are print/tee/flag plumbing only.
