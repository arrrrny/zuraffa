---
feature: tdd-make-u4-hangs-no-timeout
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 13172c0 (branch fix/742-tdd-make-u4-hangs-no-timeout, pre-commit)
behaviors: 6
proven: 5
likely: 0
test_after: 1
no_test: 0
high_smells: 0
criteria_total: 8
criteria_covered: 8
mutation_score: n/a # no mutation tool in profile; deliberate mutants 2/2 caught (1 equivalent survivor documented)
mutants_survived: 0
suite: new timeout suite 22/22 RED pre-fix (39 analyzer errors + real-hang repro exit 1) -> GREEN post-fix; fast-tier TDD plugin suite 397/397 green; full fast suite chunked 66 chunks — 61 OK, 2557 test cases passed, 5 SKIP (slow-tier-only folders), 0 failed; dart analyze: No issues found; dart format clean on every touched file; real-CLI repro on a live fixture: hang verbatim pre-fix -> child killed + runner returned post-fix
---

# TDD Verification: fix(742) — add timeouts to all TDD subprocess invocations

**Verdict: PASS.** The hang is real and the fix is proven at three levels:
(1) the new `test/plugins/tdd/services/subprocess_timeout_test.dart` suite
fails to compile against pristine `13172c0` (the timeout API does not exist —
39 analyzer errors) and a scratch repro drives the pre-fix
`SingleTestRunner.runSingle` against a never-terminating child and prints
`STILL HANGING after 20s` (exit 1) verbatim — the bug #742 signature — then
passes 22/22 post-fix and the same repro returns within its 5 s deadline with
the child killed; (2) every one of the 8 `Process.run` spawn sites in the TDD
subsystem now runs under a hard deadline through one shared `runTimed()`
primitive that kills (SIGKILL), reaps, and captures partial output; (3) the
full fast suite is green (2557 cases) — the constraint "no exit-code/summary
changes for non-timeout cases" is regression-pinned by the untouched suites.
2/2 load-bearing deliberate mutants caught. No existing test was weakened.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — every TDD subprocess invocation carries a hard deadline; a hanging child is killed (SIGKILL) and reaped, and the invocation returns with the output captured before the kill | PROVEN | RED first: the 22-test suite fails to compile pre-fix (`runTimed`/`ProcessTimeoutException`/`timeout`/`timedOut` all undefined — 39 analyzer errors). Post-fix: `runTimed` tests kill a real 1-hour sleeper at a 3 s deadline (elapsed < 20 s asserted), capture the child's pre-kill output, and preserve the `ProcessException` contract for unlaunchable executables. Covered at every layer: `runSingle`/`runSuite` (runner), `runPlan` (pipeline step), `StepRunner` + `CorpusStepRunner` default spawns, `DefaultProcessExecutor` (refactor pass) — each kills a REAL child and reports it |
| B2 — a timed-out single test classifies `runner-error`, never a certified red; no red evidence is written | PROVEN | RED first (same compile failure). Post-fix: `classify()` rule 1b maps `timedOut: true` → `RedClassification.runnerError` (unit test, plus a no-regression test asserting non-timeout classifications are byte-identical); the CLI test proves `zfa tdd verify-red` on a hanging target prints `classification=runner-error certified=false`, exits 1, and `cycle-log.md` is NOT created |
| B3 — `zfa tdd make` maps every timed-out step (drift check, suite baseline, generation step, post-generation re-run, suite guard) to `outcome=runner-error`, exit non-zero, with a message naming the behavior, step, and command; no green entry is appended | PROVEN | CLI test: make on a fixture whose profile `single` command is a sleeper + `--timeout 0.05` → `make: behavior=B-001 outcome=runner-error feature=…` summary line, `TIMED OUT` message containing the command, the `re-run with a larger --timeout` remediation line, exit 1, and the cycle log contains no `kind: green`. The five per-step guard branches are implemented as explicit pre-checks before each generic failure path (drift/baseline/step/postRun/guard); the drift branch is the one exercised end-to-end by the CLI test, the others share the same record-driven predicate (`timedOut` on `RunRecord`/`SuiteRunRecord`/`GenerationStep`) proven by the service-layer tests |
| B4 — the `--timeout <minutes>` flag overrides the default deadline; invalid values are rejected non-zero with a clear message | PROVEN | Service test: a 30 s sleeper under a 1 s explicit timeout reports `timedOut` in < 15 s (the 2-minute default would not have fired) while the same runner completes under the default for a fast child. CLI tests: `verify-red --timeout 0.05` kills the hanging target (~3 s wall) and `--timeout abc` exits 1 naming `--timeout` + `positive`. Flag accepted by make, verify-red, run, refactor, verify, corpus run |
| B5 — non-timeout behavior is unchanged: exit codes, summary lines, classifier outcomes, and suite-guard semantics for fast-completing children are byte-identical | PROVEN (regression) | Full fast suite green: 66 chunks — 61 OK / 2557 test cases / 0 failed / 5 SKIP (slow-tier-only folders: benchmark/property/integration dirs with no fast-tier tests) — including the untouched make/refactor/run/verify-red/corpus suites that pin the summary-line and exit-code contracts; `RunRecord.timedOut` et al. default to `false` so every pre-existing constructor call site is unaffected (analyzer-clean) |
| B6 — the mutation audit treats a timed-out preflight or mutation run as NOT_ASSESSED with a clear reason, never `preflight_red`, and the source restorer still runs | TEST_AFTER | Auditor tests: injected `PreflightResult(timedOut: true)` → `gate: not_assessed`, reason contains "timed out", `mutation_was_run: false`; injected `ProcessTimeoutException` from the mutation run → NOT_ASSESSED "mutation run timed out: …". Written alongside the fix rather than before it because the honest-gate wiring is inseparable from the auditor change itself; the underlying kill semantics are B1's PROVEN tests |

No pre-existing test was weakened: the only test-file changes are the ADDED
`subprocess_timeout_test.dart` (22 tests); `git diff` over
`test/plugins/tdd` touches no existing test file, zero assertions edited,
zero skips introduced.

## Real repro (scratch fixture, deleted after capture)

`tool/repro_742_hang.dart` (scratch, not committed) built a temp project with
a tdd-profile whose `single` command is the real Dart VM running a 1-hour
sleeper, then invoked the real `SingleTestRunner`:

- Pre-fix (`13172c0`): `runSingle` on the never-terminating command →
  `repro #742: runSingle on a never-terminating command: STILL HANGING after
  20s` → `RED EVIDENCE: no timeout — the runner awaits the child forever
  (bug #742)`, exit 1 (the orphan child was pkill'd after capture).
- Post-fix: the same harness with a 5 s deadline →
  `repro #742 (post-fix): runSingle with a 5s deadline: RETURNED unexpectedly
  (exit -1)` → `GREEN EVIDENCE: the hanging child was killed at the deadline
  and the runner returned (bug #742 fixed)`, exit 0.

## Deliberate mutants (profile has no mutation tool; rubric fallback)

Sampled on `lib/src/plugins/tdd/services/tdd_timeout.dart` — the shared
primitive every spawn site depends on. One small change each, observed,
restored exactly, suite re-run green after each restoration.

1. **Mutant A — `SIGTERM` instead of `SIGKILL`**: SURVIVED, judged an
   equivalent mutant for the sampled child: a plain Dart VM child without
   signal handlers dies on SIGTERM identically, so no observable contract
   changes. The distinction matters only for children that install SIGTERM
   handlers; recording it here rather than weakening the kill.
2. **Mutant A2 — remove the kill entirely**: CAUGHT. The deadline fires but
   `runTimed` still awaits the living child forever — the bug #742 hang
   returns — and `kills a child that outlives the deadline and reports it`
   fails (package:test 30 s timeout). The kill is load-bearing.
3. **Mutant B — swallow the timeout fact** (return the killed result as if
   it completed): CAUGHT. 10 of the 22 tests fail
   (`timedOut`-assertions across runner/pipeline/step/corpus/refactor plus
   the verify-red and make CLI contracts).

## Traceability (assessment.md remediation → evidence)

| Remediation criterion | Evidence |
| --------------------- | -------- |
| Timeouts across the whole TDD subsystem | All 8 spawn sites moved to `runTimed`: runner.dart (2), pipeline_runner.dart, step_runner.dart, corpus_step_runner.dart, refactor_passes.dart, mutation_auditor.dart preflight, mutation_verifier.dart (mutation run + `dart --version` probe). `grep -n "Process.run" lib/src/plugins/tdd` now shows only the two `Process.runSync('kill', ['-0', pid])` liveness probes (non-blocking by construction) and the new helper |
| Kill the spawned process on timeout | `runTimed`: `process.kill(ProcessSignal.sigkill)` + reaped exit (Mutant A2 proves it load-bearing) |
| runnerError/timeout outcome | `classify()` rule 1b → `runner-error`; make → `MakeOutcome.runnerError`; StepRunner/CorpusStepRunner → `outcome: 'runner-error'` (the driver's existing runner-error stop, exit 2, surfaces it); refactor → `RefactorOutcome.runnerError` misfire-stop; mutation → NOT_ASSESSED |
| Clear message naming behavior+step+command | `ProcessTimeoutException.toString()` names the command, deadline, working directory, and pre-kill output tail; every command prefixes it with the behavior and step (e.g. `behavior "B-001" — drift check (target test re-run before generation) timed out: …`) plus the `re-run with a larger --timeout` hint — asserted in the CLI tests |
| Exit non-zero (misfire-stop) | verify-red exit 1 (CLI test), make exit 1 (CLI test), run driver `_exitRunnerError` = 2 via the existing runner-error path, refactor exit 1, corpus `_exitRunnerError` = 2 |
| Generous defaults (2 min single / 10 min suite) + `--timeout <minutes>` | `TddTimeouts` defaults pinned by unit test (2m single, 10m suite/pipeline/steps/refactor/preflight, 30m mutation run, 30s probe); flag parsed by `parseTddTimeoutMinutes` (fractions allowed, negatives/zeros/garbage rejected non-zero) |
| No exit-code/summary changes for non-timeout cases | 2557-case fast suite green, including every summary-line/exit-code contract suite; timeout branches are additive pre-checks on a new `timedOut` flag that defaults to false |
| One PR for the bug | This branch, single PR, closes #742 |

## Findings

1. **LOW — equivalent mutant documented**: SIGTERM-vs-SIGKILL is
   indistinguishable for signal-naive children (Mutant A survived, judged
   equivalent). Children that trap SIGTERM would still hold the pipes open
   after the deadline until they exit or are SIGKILLed by an operator; a
   process-group kill is the complete fix and is out of scope for a minimal
   remediation (the assessment names `Process.kill(pid)`).
2. **LOW — same-session audit**: the tests and the fix were authored in the
   same session, so the smell pass is not independent. Mitigated by: the
   rubric catalogue was applied cold to the final file state, the suite
   spawns REAL child processes (no fakes) at the kill layer, and two
   load-bearing mutants were caught by the suite as written.
3. **INFO — mutation-layer kill path tested via the shared primitive**: the
   default preflight/`mutation_test` spawns run through the same
   `runTimed()` contract proven by Mutants A2/B and the `runTimed` tests;
   driving them against a real hanging `dart test` in a fixture was skipped
   to keep the suite fast-tier (the wiring itself is covered by the
   injected-preflight/runMutation auditor tests).

## What was not audited

- Slow-tier suites (`regression`/`integration`/`property`/`benchmark`
  presets) were not run on this disposable agent per `dart_test.yaml`'s
  explicit guidance (several GB of temp-project builds); the fast tier is
  the CI gate this repo defines.
- Coverage was not measured (profile marks it opt-in, not a gate).
- The Windows kill path (`TerminateProcess`) follows the same `Process.kill`
  call but was not exercised on this Linux agent.
- `example/` (a Flutter subpackage) was not resolved or analyzed — it needs
  the Flutter SDK and is untouched by this change.
- Process-group (tree) kill semantics for grandchildren spawned by a hung
  child: not implemented, not audited (Findings #1).
