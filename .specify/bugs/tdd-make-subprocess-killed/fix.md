# Fix: tdd make generation subprocess killed (exit -9) — memory-bounded subprocess execution + classified kill verdict (issue #826)

## What changed

`zfa tdd make` spawns the generation plan (`zfa make <id> --no-entity`,
`zfa build`) as subprocesses. The spawned child loads the full
analyzer/build pipeline; under memory pressure the OS killed it with SIGKILL
(`exit: -9`), nondeterministically and transiently, and the pipeline graded
the death as a bare `generation-error`. For the 120-spec corpus driver the
stop was indistinguishable from a genuine red needing a fix — a
transient kill deadlocked the loop.

Four remediation items, per the assessment:

1. **Bounded subprocess.** Every generation step child now spawns under a
   kernel-enforced address-space ceiling — `sh -c 'ulimit -v <kb>; exec
   "$0" "$@"'` on POSIX (2 GiB default, measured: 1 GiB aborts a trivial
   CLI start, 2 GiB lets legitimate generation complete; `exec` keeps the
   kill PID and the exit code honest). `ZFA_TDD_STEP_MEMORY_KB` tunes it,
   `0` opts out, garbage falls back to the default. Windows has no ulimit
   equivalent — the bound is skipped there (deadline + classification still
   apply); macOS accepts but does not enforce `ulimit -v`, so the bound is
   best-effort there and the classified-verdict contract carries the rest.
   The pre-existing per-step deadline (bug #742) is unchanged.
2. **Classified verdict, never a bare failed.** A child that died by signal
   (Dart reports a signal-killed child as a negative exit code; SIGKILL is
   -9) is captured with `killClass: resource-limit`; a child killed by our
   deadline is `timeout`. The make emits
   `verdict: <class> (exit <code>)`, a `--> fix:` line, and the telemetry
   JSON, and the machine-parseable summary line carries the class
   (`make: behavior=<id> outcome=resource-limit|timeout`) so corpus drivers
   can tell a transient, re-runnable kill from a genuine red. Ordinary
   exits — including ordinary failures — stay unclassified (the honest
   `generation-error` stop is preserved).
3. **Empty plan → no-op.** When the plan's first step is a bare
   `zfa make <name>` (no explicit plugin ids) and the same cheap
   PlanResolver the child runs — same registry, same project config,
   before any analyzer load — resolves to ZERO active plugins
   ("❌ No active plugins to run."), the make records `outcome=no-op`
   WITHOUT spawning the heavy subprocess at all. The gate is fail-open:
   any resolution error or a `--zfa-bin` override (fake-bin semantics may
   differ) runs the subprocess path exactly as before. The run loop defers
   `no-op` makes to phase 2 exactly like `unexpressible` (bugs #625/#657
   deferral family), unblocking the loop on nothing-to-generate behaviors.
4. **Resource telemetry.** Every captured step now carries
   `rssBeforeKb` / `rssAfterKb` (the spawning process's RSS sampled just
   before/after the child) and `wallClockMs`, surfaced in the kill verdict's
   JSON (`telemetry json: {...}`) for observability.

## Files

- `lib/src/plugins/tdd/models/generation_plan.dart` — `GenerationKillClass`,
  `StepTelemetry`; `GenerationStep.killClass/telemetry/verdictLabel/
  verdictJson()`; `MakeOutcome.resourceLimit/timeout/noOp`.
- `lib/src/plugins/tdd/services/tdd_timeout.dart` — `runTimed` gains
  `memoryLimitKb` (POSIX `ulimit -v` wrapper, `exec`-based, documented
  platform tuning).
- `lib/src/plugins/tdd/services/pipeline_runner.dart` —
  `defaultStepMemoryKb` + `resolveStepMemoryLimitKb` (env-tuned); bounded
  spawn, per-step telemetry, kill classification (negative exit →
  `resource-limit`; `ProcessTimeoutException` → `timeout`).
- `lib/src/plugins/tdd/commands/make_command.dart` — classified kill verdict
  emission (verdict + `--> fix:` + telemetry JSON + classified summary
  outcome) and the empty-plan no-op pre-flight (`_bareMakeName`,
  `_innerMakePlanIsEmpty`).
- `lib/src/plugins/tdd/commands/run_command.dart` — `no-op` joins the
  `unexpressible` make deferral (bug #625/#657 branch, issue #826 amendment).

## Tests

- `test/plugins/tdd/services/pipeline_runner_test.dart` — group
  `bug #826 — kill classification, telemetry, bounded subprocess`
  (K1 SIGKILL → resource-limit + telemetry JSON; K2 deadline kill → timeout;
  K3 clean steps carry telemetry but no verdict; K4 ordinary exit-1 stays
  unclassified; K5 the ceiling is installed in the child (Linux);
  K6 ceiling-resolution contract).
- `test/plugins/tdd/make_command_test.dart` — group
  `bug #826 — classified kill verdict + empty-plan no-op` (B1 CLI-level
  resource-limit verdict with telemetry JSON, never generation-error;
  B2 CLI-level timeout verdict; B3 empty-plan no-op without subprocess).
- `test/plugins/tdd/run_command_test.dart` — bug 826 deferral test
  (`outcome=no-op` → `deferred (phase 2)` → phase-2 green → feature
  complete, exit 0).

## Evidence (RED → GREEN, this session)

RED (pre-fix): the end-to-end repro (24-acceptance-behavior fixture, real
`zfa tdd run` → real `zfa tdd make` → pipeline child `kill -9`) printed
`generation step failed at index 0 … exit: -9` and
`make: behavior=A1 outcome=generation-error`; the run stopped at `A1:make`.

GREEN (post-fix): the same repro prints `generation step killed at index 0`,
`verdict: resource-limit (exit -9)`, the `--> fix:` line, the telemetry JSON,
and `make: behavior=A1 outcome=resource-limit`. A REAL bounded child
(`dart bin/zfa.dart make a2 --no-entity`, 768 MB ceiling) aborted
deterministically in-child and was classified `resource-limit (exit -6)`;
under the default 2 GiB ceiling legitimate generation completed and an
ordinary application failure kept the honest unclassified
`generation-error`; the empty-plan pre-flight short-circuited a real
no-plugin project to `outcome=no-op` with no subprocess.

See `tdd/verification.md` for the full verification record.
