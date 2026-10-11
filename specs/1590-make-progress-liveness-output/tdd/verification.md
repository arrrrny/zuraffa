# Verification: 1590-make-progress-liveness-output

**Branch**: `feat/1590-make-progress-liveness-output` | **Date**: 2026-09-13 | **Audited against**: spec.md SC-1…SC-8, tasks.md T001–T018

## Phase 1 — Every behavior is on the list and green

- test-list: 2 acceptance (A-1590-1, A-1590-2) + 5 unit (U-1590-1…U-1590-5)
  behaviors, all `DONE`, every `traces` value resolving to a real AC id in
  `spec.md` (AC-1…AC-8 covered; AC-8 rides A-1590-1's contract smoke plus
  the pre-existing suites as the regression gate).
- Tasks T001–T018 all closed in `tasks.md`; every behavior task was red
  before its implementation landed (Phase 2 below).

## Phase 2 — The reds were honest

Red evidence recorded BEFORE any implementation commit
(`tdd/red-1590-*.txt`, tree state `1320c70b` — the artifacts-only commit):

- **red-1590-fast.txt** — the unit-tier suite failed to LOAD: every new
  API member missing (`PipelineRunner.nameFor/bannerFor/planSummaryLine`,
  `RunDriverCore.stepStartLine/heartbeatLine`, `parseTddHeartbeatSeconds`,
  `runTimed(onStdoutLine:)`). The new surface did not exist.
- **red-1590-slow.txt** — the driven contracts failed at RUNTIME:
  `A-1590-1` found no `[run] B-001 gen — ` step-start line anywhere in the
  output (the pre-#1590 silence, byte-for-byte the issue's defect) and
  `A-1590-1b` found no `→ live-banner` in the run output while the make
  child was running.
- **red-1590-slow-2.txt** — `A-1590-2`/`A-1590-2b` red: no forwarding, no
  heartbeat lines.
- **red-1590-slow-3.txt** — `A-1590-3` red: the resumed in-flight step
  printed no resume banner.

## Phase 3 — Green evidence (what ran)

All runs on this branch, `dart test` (Dart SDK 3.13.3, Linux x64), kernel
cache cleared before each batch (`rm -rf .dart_tool/test/`):

| Suite | Scope | Result |
| --- | --- | --- |
| `test/plugins/tdd/issue_1590_progress_liveness_test.dart` | U-1590-1…5 (12 tests) | **12/12 green** |
| `test/plugins/tdd/run_command_test.dart` `--preset all` | FULL driver suite incl. A-1590-1…3 (55 tests) | **55/55 green** |
| `pipeline_runner_test` + `step_runner_test` + `run_state_store_test` + issue_1590 | services (60 tests) | **60/60 green** |
| `run_engine_command_test` + `run_skin_command_test` + `tdd_json_stream_test` + scenarios sc_013–sc_016 | lanes, NDJSON stream, driven scenarios (12 tests) | **12/12 green** |
| `subprocess_timeout_test` + `scratch_tmpdir_test` | runTimed + env consumers (36 tests) | **36/36 green** |

SC-by-SC: SC-1 (A-1590-1: banner index < completion index for every
spawned step), SC-2 (U-1590-1: exact banner mapping + one banner per
spawned step + misfire-stop prints none for unreached steps), SC-3
(A-1590-1b + A-1590-2: banner forwarded live, control line not), SC-4
(A-1590-2b: `--heartbeat 0.05` fires, `0` silent), SC-5 (A-1590-3: resume
suffix with the recorded owner pid), SC-6 (U-1590-2: named plan lines,
expressible + composition), SC-7 (A-1590-2: `--verbose` forwards
verbatim), SC-8 (full pre-existing driver/lanes/stream/scenarios suites
green + analyze clean below).

A live transcript (the operator-visible shape this issue asked for) is at
`tdd/demo-transcript.txt` — a real driven run with `--heartbeat 0.4`:

```
[run] B-001 make — generation pipeline (sub-steps announced as they start)
→ live-banner (demo)
[run] B-001 make … 0s elapsed
[run] B-001 make -> green
```

## Phase 4 — Gates

- `dart analyze` over ALL 10 changed files (8 lib + 2 test): **No issues
  found** — no new warnings.
- `dart format` over the same files: clean (4 files reflowed to canonical
  style; no semantic diff).
- Machine contract: the FULL pre-existing `run_command_test.dart` suite
  (50 pre-existing driver-contract tests: step order, state machine,
  resume, concurrent-run refusal, evidence misfires, phase-0, summary
  line) passes UNCHANGED alongside the 5 new tests — the additive lines
  break no assertion.

## Phase 5 — Known pre-existing failures (attributed, NOT #1590)

The four `make_command_*` suites (slow tier, real build/analyzer children)
show 2–4 environment-dependent failures in this sandbox. Attribution: the
branch was STASHED to the artifacts-only commit (`1320c70b`, pre-#1590
code) and the identical subset re-run — the SAME tests fail identically
(`A11/U17 … never composes (SC-004)`, `A15 … outcome=skipped` and, in the
full-file run, `U-829g/U-829h` entity-pipeline cases). These suites spawn
real `build_runner`/`dart analyze` children whose outcomes differ on this
constrained agent; they are unrelated to the progress-output layer this
feature touches (the make change here is two print lines). Every make
suite test that exercises the plan-line print itself (US5 summary
contract, spec-052 green-entry captures, bug-829 plan captures minus the
environment-failed asserts) passes.

## Phase 6 — Mutation gate disclosure (honest stop)

The tdd extension's deterministic audit (`zfa tdd verify` → mutation
testing) was NOT run: the repo root carries no `.zfa.json` (the
extension's own Step-0 detection reports ZFA_MISSING → the documented
LLM-guided fallback, which is this file), and the mutation audit's
per-mutant suite runs are not tractable on this sandbox (the suite
preflight alone is minutes; the 041-scoped mutant set executes the TDD
suite once per mutant). The verification above stands on recorded red
evidence, the full green matrix, and the attributed pre-existing
failures — no pass is claimed for anything that did not run.
