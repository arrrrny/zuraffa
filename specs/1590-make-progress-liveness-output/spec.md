**Template Version**: `zuraffa-1.0`

# Spec: 1590-make-progress-liveness-output

## Overview

`zfa tdd run` prints nothing while a step runs. A single `make` step ran
**273.7 seconds** with zero output — no sub-step names, no child output, no
heartbeat; the next line the operator saw was `[run] A1 make -> green`. On a
spec with tens of behaviors that silence reads as a hang and the operator
kills the run.

Three compounding causes, all in the progress-output layer:

1. **Driver silence** — `RunDriverCore._driveBehavior` marks in-flight,
   write-aheads the transaction, then spawns the step child and prints
   NOTHING until the child exits (`[run] <behavior> <step> -> <outcome>`).
   There is no "about to run" line and no heartbeat while the child runs.
2. **Pipeline silence** — `PipelineRunner.runPlan` spawns each generation
   sub-step (`tdd func <id>`, `build`, `entity create …`, `mock create …`,
   `tdd wire …`, `tdd compose …`) with no banner; make's only pre-execution
   output is a step COUNT (`   plan: N step(s)`), not names.
3. **Capture blindness** — every spawn goes through `runTimed`, which joins
   the child's stdout/stderr into the captured `ProcessResult`. The make
   child's progress output (and anything it would print) never reaches the
   terminal during a driven run; the driver surfaces it only as a failure
   tail.

This feature fixes the progress output ONLY: the driver prints what it is
about to run, make (and the pipeline runner) prints a banner before each
sub-step spawn, long-running steps emit a heartbeat with elapsed time, and
the run forwards banner-shaped child lines live. Step execution logic, the
state machine, the test runner, and the machine-readable contract
(`[run] <behavior> <step> -> <outcome>` lines, the `run: feature=…` summary
line, `--stream` NDJSON events, the verdict envelope) are untouched.
Related: #1587 (make perf — companion issue), #1529 (make timeout
diagnostics) — both out of scope here.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The operator sees what is about to run (Priority: P1)

An operator (human or agent) drives `zfa tdd run` on a multi-behavior
feature. Before each step spawns, the run prints a step-start line naming
the behavior and step, and for `make`, the plan names its sub-steps and the
pipeline prints a banner before each sub-step spawn — so the shape of the
work is visible BEFORE the long silence begins.

**Why this priority**: the reported defect is the silence itself; knowing
what is running is the minimum honest progress output.

**Independent Test**: drive a run against the fake-zfa fixture; assert the
step-start line appears BEFORE the step's completion line and the pipeline
banner precedes each spawned sub-step.

**Acceptance Scenarios**:

1. **Given** a driven behavior step, **When** the step is about to spawn,
   **Then** the run prints `[run] <behavior> <step> — <hint>` BEFORE the
   spawn (the line's output position precedes the step's
   `[run] <behavior> <step> -> <outcome>` completion line).
   **Type**: acceptance
2. **Given** an expressible generation plan, **When** the pipeline is about
   to spawn a sub-step, **Then** it prints `→ <name>` first —
   `→ func` for the func step and
   `→ build (build_runner + analyze; minutes on first run)` for the build
   step.
   **Type**: acceptance
3. **Given** an expressible plan, **When** make announces the plan, **Then**
   the plan line NAMES the steps (`   plan: 2 step(s): func, build`), not
   just the count; the composition-fallback variant names its steps too.
   **Type**: acceptance

---

### User Story 2 - The operator sees liveness DURING long steps (Priority: P2)

During a step that runs for minutes (the 273.7s make), the run is not
silent: the driver emits a heartbeat with elapsed time at a fixed cadence,
and banner-shaped lines the make child prints (`→ …`) are forwarded to the
run output as they arrive — the operator sees `→ func` and
`→ build (build_runner + analyze; minutes on first run)` land during the
step, not after it.

**Why this priority**: a started step with no further output for minutes is
still read as a hang; elapsed-time heartbeats are the standard liveness fix.

**Independent Test**: run with a short heartbeat interval and a step child
that sleeps; assert a `… <elapsed> elapsed` line appears before the
completion line, and that a banner line printed by the fake make child is
forwarded into the run output.

**Acceptance Scenarios**:

4. **Given** a step running longer than the heartbeat interval, **When**
   each interval elapses, **Then** the run prints
   `[run] <behavior> <step> … <elapsed> elapsed` until the step completes,
   and prints none after it.
   **Type**: acceptance
5. **Given** a driven make step whose child prints pipeline banner lines,
   **When** those lines arrive on the child's stdout, **Then** the run
   forwards every banner-shaped line (`→ …`) to the run output live.
   **Type**: acceptance

---

### User Story 3 - Resume visibility, opt-in depth, parser safety (Priority: P3)

A resumed run names the in-flight step it is re-driving (the run-state.json
/ transaction.json in-flight trio already exists — it needs visibility).
`--verbose` forwards ALL child stdout lines verbatim for debugging.
`--heartbeat 0` silences heartbeats for parser-strict consumers. The
machine contract is preserved byte-for-byte.

**Why this priority**: completes the liveness story without touching the
contract other tools parse.

**Independent Test**: seed run-state with an in-flight step and re-run;
assert the banner names the resume. Drive with `--verbose` and assert every
child line appears; with `--heartbeat 0` and assert no heartbeat line does.

**Acceptance Scenarios**:

6. **Given** a run resuming a feature whose run-state carries an in-flight
   step (owner pid dead or absent), **When** that in-flight step is about
   to spawn, **Then** the step-start banner names the resume and the
   recorded owner pid.
   **Type**: acceptance
7. **Given** `--verbose`, **When** the make child prints any stdout lines,
   **Then** every line is forwarded verbatim (not just banner-shaped).
   **Type**: acceptance
8. **Given** `--heartbeat 0`, **When** steps run long, **Then** no
   heartbeat line prints; **Given** any flag combination, **When** steps
   complete, **Then** the machine contract
   (`[run] <behavior> <step> -> <outcome>`, the final
   `run: feature=… result=… pending=… red=… green=… done=…` line with
   ` stopped_at=<behavior>:<step>` when stopped, `--stream` NDJSON events,
   the verdict envelope) is byte-identical to the pre-#1590 output.
   **Type**: acceptance

---

## Functional Requirements

- **FR-001**: The run driver MUST print a step-start banner
  `[run] <behavior> <step> — <hint>` BEFORE spawning each step, where
  `<hint>` is static per-step knowledge: `gen` → `scaffold test + stub`;
  `verify-red` → `run target test (expect red)`; `make` →
  `generation pipeline (sub-steps announced as they start)`; `refactor` →
  `format + analyze + re-proof`. The banner is printed by the DRIVER — the
  driver never duplicates make's plan-selection logic (the plan is the
  make child's own knowledge, announced live per FR-002/FR-003/FR-005).
- **FR-002**: `PipelineRunner.runPlan` MUST print a `→ ` banner line BEFORE
  each sub-step spawn. Name derivation from the step's args:
  `tdd`-prefixed → the subcommand verb (`func`, `wire`, `compose`);
  `build` → `build (build_runner + analyze; minutes on first run)`;
  `entity create <Name> …` → `entity create <Name>`;
  `make <Name> …` → `make <Name>`; `mock create …` → `mock create`;
  anything else → the first two args joined. Banners are printed for
  spawned steps only (misfire-stop prints none for steps never reached).
- **FR-003**: make's plan lines MUST name the steps:
  `   plan: <n> step(s): <name>, <name>` (expressible) and
  `   plan: composition fallback — <n> step(s): <name>, <name>` — names
  derived by the same rule as FR-002, hint omitted.
- **FR-004**: `runTimed` MUST accept an optional stdout line callback that
  fires per complete stdout line AS IT ARRIVES, while the returned
  `ProcessResult.stdout` stays byte-faithful to the pre-#1590 capture. The
  callback rides the DEFAULT spawner only — an injected `StepSpawner` fake
  keeps its own contract (the established childEnvironment precedent).
- **FR-005**: The driver MUST forward banner-shaped child stdout lines
  (`^→ `) to the run output by default; with `--verbose` it forwards EVERY
  child stdout line verbatim. Forwarding never alters the captured output
  the failure tails and the gen guard-only warning already consume.
- **FR-006**: The driver MUST emit a heartbeat per running step at the
  configured interval: `[run] <behavior> <step> … <elapsed> elapsed`,
  elapsed formatted by `formatTddTimeout`. Default interval 30s, tunable
  with `--heartbeat <seconds>` (fractions allowed; `0` disables), timer
  canceled the moment the step completes or the run stops.
- **FR-007**: When the step about to spawn IS the in-flight step restored
  from run-state.json (recorded owner pid differs from the current pid),
  the step-start banner MUST append
  ` (resuming in-flight step from run-state.json, owner pid <pid>)`.
- **FR-008**: The machine contract is UNCHANGED: the
  `[run] <behavior> <step> -> <outcome>` completion lines, the summary
  line, `--stream` step-verdict.v1 NDJSON events, and the verdict envelope
  stay byte-identical. Every new line is additive and never parsed by the
  driver or the step commands. `--quiet` does not exist on the TDD driving
  verbs; the additive lines stay on the same stdout path as the existing
  human-progress lines and every new flag defaults to preserving the
  pre-#1590 line set (heartbeat excepted — the liveness feature itself).

## Success Criteria (measurable)

- **SC-1**: In a driven run, for EVERY spawned step the output contains
  `[run] <behavior> <step> — ` and its position precedes the position of
  that step's `[run] <behavior> <step> -> ` completion line.
- **SC-2**: `PipelineRunner` banner mapping is exact:
  `['tdd','func','A1','--feature','f']` → `→ func`;
  `['build']` →
  `→ build (build_runner + analyze; minutes on first run)`;
  `['entity','create','User','--fields=…']` → `→ entity create User`;
  `['make','User','--no-entity']` → `→ make User`;
  `['mock','create','--name','X','--certify']` → `→ mock create`;
  unknown args → first two args joined. `runPlan` prints exactly one
  banner per spawned step, each before its spawn.
- **SC-3**: A driven make child printing `→ live-banner` has that line in
  the run output before the step's completion line; a control line NOT
  starting with `→ ` does not appear (default mode, no `--verbose`).
- **SC-4**: With `--heartbeat 0.05` and a step child sleeping ≥ 0.2s, the
  run output contains at least one `[run] <behavior> <step> … …s elapsed`
  line; with `--heartbeat 0` and the same child, none.
- **SC-5**: After seeding run-state.json with
  `in_flight_behavior_id/in_flight_step/in_flight_owner_pid` naming a dead
  pid, the resumed run's banner for that step ends with
  `(resuming in-flight step from run-state.json, owner pid <pid>)`.
- **SC-6**: For a unit-kind plan the make output contains
  `   plan: 2 step(s): func, build`; a composition plan prints
  `   plan: composition fallback — 2 step(s): compose, build`.
- **SC-7**: With `--verbose`, every stdout line the make child prints
  appears in the run output verbatim.
- **SC-8**: No regression: every pre-existing `run_command_test.dart` /
  `pipeline_runner_test.dart` / `step_runner_test.dart` assertion passes
  unchanged, `dart analyze` reports no new warnings on the changed files,
  and `dart format` is clean.

## Out of scope

- #1587 (make performance) and #1529 (make timeout diagnostics) —
  companions, not here.
- Corpus driver liveness (`CorpusStepRunner`, `[corpus]` lines) — the issue
  names `zfa tdd run`; the corpus path keeps its own contract untouched.
- Phase-0 entity-orchestration heartbeats (the phase already prints
  per-entity lines).
- Teeing FULL child output by default (build_runner noise would flood the
  terminal — `--verbose` is the opt-in).
