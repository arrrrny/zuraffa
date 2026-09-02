---
feature: .specify/bugs/tdd-make-subprocess-killed (bug #826 / committed records' #796, pinned per bug extension TDD mode, branch audit; task slug alias tdd-make-subprocess-killed-memory)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: fa2da18f
behaviors: 6
proven: 5
likely: 1
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 4/4 caught # scope: the kill classification + verdict emission + empty-plan pre-flight this fix added only (pipeline_runner.dart, make_command.dart), manual deliberate mutants
mutants_survived: 0
suite: "chunked fast suite 67/67 chunks +2584 −0; pipeline_runner_test +12 (bug-826 group +6); make_command_test +33 −2 (2 pre-existing, pristine-identical); run_command_test +35 −1 (1 pre-existing, pristine-identical); dart analyze clean; dart format clean on all touched files"
---

# TDD Verification: bug #826 — tdd make generation subprocess killed (exit -9): memory-bounded subprocess execution + classified kill verdict

**Verdict: PASS_WITH_GAPS.** The red→green cycle is real: the end-to-end CLI
repro on a 24-acceptance-behavior fixture drove the REAL `zfa tdd run` →
`zfa tdd make` → pipeline and captured the exact issue signature pre-fix
(`exit: -9`, bare `outcome=generation-error`, no classification, no fix line),
and post-fix the same run reports `outcome=resource-limit` with
`verdict: resource-limit (exit -9)`, a `--> fix:` line, and the telemetry JSON
`{"verdict":"resource-limit","exitCode":-9,...,"rssBeforeKb":819204,"rssAfterKb":819216,"wallClockMs":16}`.
All four remediation items are covered through the real CLI and real
subprocesses, a REAL bounded child (plain `dart bin/zfa.dart make a2
--no-entity` under a 768 MB ceiling) aborted deterministically in-child and was
classified `resource-limit (exit -6)`, the default 2 GiB ceiling let
legitimate generation complete (its ordinary application failure kept the
honest unclassified `generation-error`), all four deliberate mutants were
killed, and the empty-plan no-op pre-flight was proven on the real CLI with no
fake zfa at all. The gaps: no committed test list exists for the bug workflow
(ordering evidence is session-recorded; the commit is atomic, so git history
alone shows LIKELY), the telemetry's RSS figures are the SPAWNING process's
before/after samples rather than the child's peak (documented in code; the
child's peak on Linux is not portable to sample), the make-level timeout
fixture relies on a scripted fast-red single runner (deterministic, but it
does not exercise a real `dart test` inside the deadline path), and 3
pre-existing failures elsewhere pre-date this branch and are documented, not
fixed, here.

## Test-first evidence

| Behavior                                                                                              | Class  | Evidence                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ----------------------------------------------------------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1 — a SIGKILLed generation step is graded `resource-limit` with the verdict, fix line, and telemetry JSON (remediation 2 + 4) | PROVEN | RED captured verbatim (pre-fix e2e run, this session): `generation step failed at index 0 (generate use-case/repository scaffolds for a1 (behavior A1)):` → `exit: -9` → `make: behavior=A1 outcome=generation-error`; run loop: `step failed — behavior=A1 step=make outcome=generation-error`. GREEN post-fix: `generation step killed at index 0` → `verdict: resource-limit (exit -9)` → `--> fix:` → telemetry JSON → `outcome=resource-limit`; B1 + K1 pin it.                                                                                                                                                                              |
| B2 — a step killed at the per-step deadline is graded `timeout` (remediation 1 + 2)                                            | PROVEN | K2 pins the pipeline capture (`killClass: timeout`, telemetry, deadline fired) with a real hung child killed at 700 ms; B3 pins the CLI-level summary (`outcome=timeout`, `verdict: timeout (exit -1)`) with a 1.8 s uniform deadline and a real hung fake-zfa child. Both failed pre-fix in the skeleton run (killClass `none`).                                                                                                                                                                                                                                                                                                                                                                                             |
| B3 — the generation subprocess spawns under a bounded address-space ceiling (remediation 1)                                    | PROVEN | K5 asserts the wrapper installs the ceiling in the child (`cap=2097152` read back via `ulimit -v`); a REAL probe run showed a 768 MB-ceiling child abort deterministically in-child (`verdict: resource-limit (exit -6)` with telemetry) while the default 2 GiB ceiling let the real analyzer pipeline load and complete (its ordinary `--domain` application failure stayed an honest unclassified `generation-error`). 1 GiB kills even a trivial CLI start — the 2 GiB default is measured, and `ZFA_TDD_STEP_MEMORY_KB` tunes it (`0` opts out).                                                                                                                                                                              |
| B4 — an empty inner make plan ("No active plugins") records a no-op WITHOUT attempting the subprocess (remediation 3)          | PROVEN | B2 (real CLI, no fake zfa, fixture without plugin defaults): `plan: \`zfa make a1\` resolves to no active plugins — nothing to generate (bug #826).` → `verdict: no-op` → `outcome=no-op`, exit 1, no green evidence, no pipeline capture and no post-generation re-run in the output. Also reproduced on the e2e fixture's A2 with the real CLI. The run loop then DEFERS the behavior (bug-826 deferral test): `[run] A1 make -> deferred (phase 2)` and the feature completes `result=complete` when phase 2 flips it green — the loop is unblocked exactly like the `unexpressible` deferral.                                                                                                                                                                                          |
| B5 — ordinary exits stay unclassified (no over-classification)                                                                 | PROVEN | K4: an exit-1 step keeps `killClass: none` / null verdict label; K3: successful steps carry telemetry but no verdict; the real-CLI default-ceiling run (see B3) graded a genuine application failure as bare `generation-error` — the honest stop is preserved.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| B6 — the memory ceiling resolution contract (env override, opt-out, garbage)                                                   | LIKELY | K6 pins the pure resolver (default 2 GiB; `ZFA_TDD_STEP_MEMORY_KB=1048576` honored; `0` opts out; garbage and negatives fall back to the default bound — the safe reading). No subprocess-level test drives the override end to end; the contract is pinned at the unit level only.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |

No assertion was weakened: the diff touches only the new bug-826 test groups
(plus the deferral-condition extension in `run_command.dart`, an amendment in
the bug #625/#657 deferral branch with the issue reference inline, following
the #694 amendment precedent). No test was renamed out of a filter's reach,
skipped, or excluded; no coverage/mutation gate was touched.

## Findings

| #   | Severity | Finding                                                                                                                                                                                                                                                                                     | Evidence                                                                        |
| --- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| 1   | LOW      | The telemetry RSS figures sample the SPAWNING process (before/after) rather than the child's peak RSS; a Linux-only `/proc/<pid>/status` read could capture the child's VmHWM, but not portably (macOS/Windows). The wall clock is exact; the RSS pair bounds the parent's pressure around the spawn | `lib/src/plugins/tdd/models/generation_plan.dart` (`StepTelemetry` doc); `pipeline_runner.dart` (`_telemetry`) |
| 2   | LOW      | B3's make-level timeout fixture uses a scripted fast-red single runner (exit 1) so the uniform `--timeout` deadline can be small; deterministic, but it does not exercise a real `dart test` inside the deadline path (the pipeline-level K2 does use a real hung child)                    | `test/plugins/tdd/make_command_test.dart` (B3 comment)                            |
| 3   | LOW      | The pre-flight gate skips the empty-plan short-circuit when `--zfa-bin` is passed (a fake bin may not share the in-process registry's plugin semantics), so the no-op short-circuit is only exercised on the default entrypoint path — production's path — and not under test overrides | `lib/src/plugins/tdd/commands/make_command.dart` (`zfaBinFlag == null` gate)      |
| 4   | LOW      | The workflow stated records exist at `.specify/bugs/tdd-make-subprocess-killed-memory/`; the committed records live at `.specify/bugs/tdd-make-subprocess-killed/` (issue #796). This report is filed beside the committed records; the task's slug is recorded as an alias in the frontmatter | `.specify/bugs/tdd-make-subprocess-killed/assessment.md`                          |
| 5   | LOW      | Pre-existing failures pre-date this branch and are intentionally not remediated here (single-purpose PR): bug 657 verb-naming + spec 052 SC-004 in `make_command_test.dart` (pristine +30 −2 → fixed-tree +33 −2, same 2); bug #691 run-state skip in `run_command_test.dart` (pristine +34 −1 → fixed-tree +35 −1, same 1). Also pre-existing on master: the `examples/mcp_demo/lib/src/mcp/tools.dart` format drift (excluded from this PR) | Pristine-master stash runs in this session, matching the #737 verification's list |

## Mutation results (deliberate mutants, manual — no mutation tool in profile)

Scope: the logic this fix added only (the classification in
`pipeline_runner.dart`, the verdict emission + pre-flight in
`make_command.dart`). One mutant at a time; every mutant was restored exactly
(`git diff` checked, `dart format --set-exit-if-changed` clean after restore)
and the owning test re-run.

| Mutant                                                                                  | Behavior | Survived | Judgment                                                                                                                    |
| --------------------------------------------------------------------------------------- | -------- | -------- | ----------------------------------------------------------------------------------------------------------------------------- |
| M1 — signal kill classification dropped (`killClass` forced to `none`)                    | B1       | No       | KILLED by B1 (`Expected: contains 'make: behavior=A1 outcome=resource-limit'`) — the classified outcome is pinned               |
| M2 — timeout classification dropped (deadline kill captured unclassified)                   | B2       | No       | KILLED by K2 (`Expected: GenerationKillClass.timeout / Actual: none`) — the deadline-kill class is pinned                       |
| M3 — empty-plan pre-flight disabled (`_innerMakePlanIsEmpty` → false)                       | B4       | No       | KILLED by B2 (`Expected: contains 'plan: \`zfa make a1\` resolves to no active plugins…'`) — the no-subprocess short-circuit is pinned |
| M4 — make-level timeout outcome flipped (`timeout` → `resourceLimit`)                       | B2       | No       | KILLED by B3 (`Expected: contains 'make: behavior=A1 outcome=timeout…'`) — found missing mid-audit, B3 added, mutant killed      |

M4 deserves the note: the audit-level gap (only the pipeline label was pinned)
was found while designing the mutants, B3 was added to the fix's test suite
BEFORE the verdict was recorded, and the mutant then died. No survivor
remained in the tree.

## Traceability (bug #826 remediation → tests)

| Criterion (remediation item)                                                                                                        | Test(s)                                                | Entry point |
| ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------- | ------------ |
| 1. Bounded memory limit (ulimit -v or platform equivalent) + hard timeout on the generation subprocess                                 | K5, K6, B2→(real probe runs), K2/B3 (deadline side)      | real CLI + real subprocesses |
| 2. Classified verdict (resource-limit / timeout) with exit code and `--> fix:` line — never a bare failed                               | B1, B3, K1, K2 (+ e2e repro flipped generation-error → resource-limit) | real CLI |
| 3. Empty plan ("No active plugins") → no-op outcome instead of attempting the subprocess                                                 | B2, bug-826 run-loop deferral test (+ real-CLI A2 probe) | real CLI |
| 4. Resource telemetry (RSS before/after, wall clock) in the JSON verdict                                                                | B1, K1 (telemetry JSON keys + values asserted)           | real CLI |

Every test claiming these criteria exists and runs (session runs in the
frontmatter and the tables above); they drive the real `zfa` CLI surface
against real subprocesses (bash fakes, real `dart test` in fixtures, and one
real bounded `dart bin/zfa.dart make` child), not unit doubles at every
boundary.

## Suite evidence (real runs, this session)

- RED (pre-fix): e2e repro script (24-acceptance-behavior fixture, real `zfa tdd run` → real `zfa tdd make` → pipeline child `kill -9`): `exit: -9`, bare `outcome=generation-error`, exit 1, run stops at `A1:make`.
- GREEN (post-fix): same fixture — `[run] A1 make -> resource-limit`, `verdict: resource-limit (exit -9)`, `--> fix:` line, telemetry JSON with rssBeforeKb/rssAfterKb/wallClockMs; detailed make run captured verbatim above.
- Real bounded child (768 MB ceiling, no fake): deterministic in-child abort → `verdict: resource-limit (exit -6)`; default 2 GiB ceiling: legitimate generation completes, ordinary failure stays unclassified `generation-error`.
- `dart test test/plugins/tdd/services/pipeline_runner_test.dart` → `+12` (6 pre-existing U8–U13 + 6 new K1–K6).
- `dart test --preset=all test/plugins/tdd/make_command_test.dart` → `+33 −2` (the 2 failures pre-date the branch, pristine-identical via stash run: +30 −2).
- `dart test --preset=all test/plugins/tdd/run_command_test.dart` → `+35 −1` (the 1 failure pre-dates the branch, pristine-identical via stash run: +34 −1).
- `tools/run_tests_chunked.sh` semantics replicated chunk-for-chunk (kernel cleanup, stdin `/dev/null`, fast-tier selector): 67/67 chunks, `+2584 −0`; `test/plugins/tdd/scenarios`, `test/property`, `test/benchmark`, `test/integration` are slow-tier-only ("No tests ran" skips, by design).
- `dart analyze` → No issues found (lib/src/plugins/tdd + test/plugins/tdd; also full tdd tree mid-session).
- `dart format .` → run; all touched files stable (`--set-exit-if-changed` exit 0); the only repo-wide drift is the pre-existing `examples/mcp_demo/lib/src/mcp/tools.dart` on master, excluded from this single-purpose PR.

## What was not audited

- No mutation tool ran; the deliberate-mutant sample covered only the new
  classification/verdict/pre-flight logic (4 mutants), not the untouched
  entrypoint-resolution or plan-execution paths.
- The memory bound is kernel-enforced on Linux only; macOS enforcement
  (Darwin ignores RLIMIT_AS) and Windows (no ulimit equivalent) were
  reasoned and documented but not executed in this session (Linux-only box).
- The corpus harness layer (`corpus_run_command` / `CorpusStepRunner`) was
  verified only through the summary-token contract it parses (make's
  `outcome=`), not through a dedicated corpus-driver test driving the new
  tokens.
- Phase-2 interplay of the `no-op` deferral with a fully-green suite was
  verified through the scripted run-loop test, not a real multi-behavior e2e.
- The `integration`, `property`, and `benchmark` slow tiers were not run
  (temp-project + `build_runner` tiers; `dart_test.yaml` marks them unsafe on
  small/disposable agents — this session's disk is 9.9 GB).
- Coverage was not run (corroboration only per the rubric).
