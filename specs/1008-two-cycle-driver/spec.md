# Feature Specification: Two-Cycle Driver (run-engine + run-skin + meta run)

**Feature Branch**: `1008-two-cycle-driver`

**Created**: 2026-09-05

**Status**: Draft

**Template Version**: `zuraffa-1.0`

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/1008 — [ZIKZAK-REBUILD] zfa tdd run-engine and zfa tdd run-skin — two-cycle runner. After #1000 the plan is split into ENGINE.md + SKIN.md. Today zfa tdd run is one command that runs both. After the split, there are three commands: run-engine, run-skin, and run (meta-driver). None exist yet."

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| --- | --- | --- | --- |
| Existing two-phase run driver | lib contract | plan -> run -> verify-red -> make -> green -> refactor -> done, resumable via tdd/run-state.json, evidence in tdd/cycle-log.md (spec 049) | P0 (shared, never duplicated) |
| Lane plan files (#1000) | file contract | specs/<feature>/tdd/04-ENGINE.md and 04-SKIN.md name the behaviors of each lane; absent on legacy features | P1 |
| Lane row tags | file contract | ` [core]` / ` [skin]` / ` [both]` tags in the test list's behavior cell, parsed like `[persistence]` | P1 |
| Engine lane receipt | file contract | specs/<feature>/tdd/04-engine-receipt.json, schema 1, verdict green|red|error | P1 |
| Skin lane receipt | file contract | specs/<feature>/tdd/04-skin-receipt.json, schema 1, verdict green|red|error | P1 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The engine lane runs alone (Priority: P1)

An agent certifies the pure-Dart engine of a feature without touching its skin: `zfa tdd run-engine <feature>` drives only the CORE + BOTH behaviors (the engine plan) through the existing two-phase driver, writes the engine journal (`tdd/cycle-log.md`, via the driven steps) and the `04-engine-receipt.json` verdict.

**Why this priority**: The engine/skin split only pays off if each lane can be certified independently; the engine lane is the one every other lane depends on.

**Independent Test**: A fixture feature with CORE/SKIN/BOTH-tagged behaviors drives only the CORE+BOTH rows (visible in the step invocation log), and the engine receipt names exactly those behaviors with verdict green.

**Acceptance Scenarios**:

1. **Given** a feature whose test list declares lanes (tags or plan files), **When** `zfa tdd run-engine <feature>` runs, **Then** only CORE + BOTH behaviors are driven and the run completes with exit 0.
   **Type**: acceptance
2. **Given** the engine lane run, **When** it completes, **Then** `specs/<feature>/tdd/04-engine-receipt.json` exists with `verdict: green`, the lane's behavior ids, and counts.
   **Type**: acceptance
3. **Given** a legacy feature with no lane declarations, **When** `zfa tdd run-engine <feature>` runs, **Then** every behavior is engine-lane (CORE default) and the run behaves exactly like the pre-split driver.
   **Type**: acceptance
4. **Given** an engine lane that stops honestly (a red step), **When** the run stops, **Then** the receipt records `verdict: red` with the stopped_at location and the exit code stays the driver's honest stop semantics.
   **Type**: acceptance

### User Story 2 - The skin lane is gated on a green engine (Priority: P0)

An agent runs the skin only after the engine's certified mocks exist: `zfa tdd run-skin <feature>` drives only the SKIN + BOTH behaviors (the skin plan) and refuses to start unless `04-engine-receipt.json` is green.

**Why this priority**: The dependency is the product — skin tests bind the engine's certified mocks; running them before the engine is green is waste and lies.

**Independent Test**: A fixture feature without an engine receipt makes `run-skin` exit 2 naming the missing receipt and drive zero steps; after a green engine run the same command drives the SKIN+BOTH rows and writes the skin receipt.

**Acceptance Scenarios**:

1. **Given** a feature with no `04-engine-receipt.json`, **When** `zfa tdd run-skin <feature>` runs, **Then** it exits 2, names the missing receipt and the remediation (`zfa tdd run-engine`), and drives zero steps.
   **Type**: acceptance
2. **Given** a feature whose engine receipt verdict is not green, **When** `zfa tdd run-skin <feature>` runs, **Then** it exits 2 naming the recorded verdict.
   **Type**: acceptance
3. **Given** a green engine receipt, **When** `zfa tdd run-skin <feature>` runs, **Then** only SKIN + BOTH behaviors are driven (BOTH behaviors already done by the engine lane are skipped, never re-driven from scratch), and `04-skin-receipt.json` is written with the honest verdict.
   **Type**: acceptance
4. **Given** a green engine receipt and a feature with no skin behaviors at all, **When** `zfa tdd run-skin <feature>` runs, **Then** it completes vacuously (zero behaviors, verdict green) without driving any step.
   **Type**: acceptance

### User Story 3 - The meta-driver chains both lanes (Priority: P1)

`zfa tdd run <feature>` keeps its one-command contract: engine lane first, then skin lane, failing fast on the first red, writing a unified journal entry that names both receipts.

**Why this priority**: CI and agents keep a single entry point; the two-cycle structure is an implementation detail of the run.

**Independent Test**: A fixture feature driven by `zfa tdd run` shows the engine steps before the skin steps in the invocation log, both receipts on disk, the unified journal entry naming both, and the same final summary line shape as the pre-split driver.

**Acceptance Scenarios**:

1. **Given** a feature with lanes, **When** `zfa tdd run <feature>` runs, **Then** the engine lane's steps all precede the skin lane's steps, both receipts are green, and the exit code is 0.
   **Type**: acceptance
2. **Given** a red engine step, **When** `zfa tdd run <feature>` runs, **Then** the run stops at the engine lane's red (fail-fast), no skin step is spawned, no skin receipt is written, and the exit code is the honest stop code (1).
   **Type**: acceptance
3. **Given** both lanes green, **When** the run completes, **Then** `tdd/cycle-log.md` gains a unified journal entry naming both receipt files, and the final summary line keeps the machine shape `run: feature=<f> result=<r> pending=<n> red=<n> green=<n> done=<n>`.
   **Type**: acceptance
4. **Given** a legacy feature with no lanes, **When** `zfa tdd run <feature>` runs, **Then** the behavior is byte-compatible with the pre-split driver (all behaviors driven once, same step order, same summary, same exit codes) plus the two receipts and the unified entry.
   **Type**: acceptance

### User Story 4 - Status reads the receipts (Priority: P1)

`zfa tdd status <feature>` reads the two receipts and prints a one-line verdict for both lanes.

**Why this priority**: Scripts and agents need the two-cycle state at a glance without parsing journals.

**Independent Test**: After the exit-criteria run on feature `004-login-ui`, `zfa tdd status 004-login-ui` prints one line naming both lane verdicts.

**Acceptance Scenarios**:

1. **Given** both receipts green, **When** `zfa tdd status <feature>` runs, **Then** it prints exactly one verdict line naming engine and skin green and exits 0.
   **Type**: acceptance
2. **Given** any receipt missing or not green, **When** `zfa tdd status <feature>` runs, **Then** the line names the honest per-lane verdict (absent/red/error) and the exit code is non-zero.
   **Type**: acceptance
3. **Given** no feature directory, **When** `zfa tdd status <feature>` runs, **Then** it refuses with the same misfire-stop semantics as the run commands.
   **Type**: acceptance

## Non-Functional Requirements

Performance: lane resolution is one file read over the test list plus at most two plan-file reads; no suite spawns are added by the split itself (the vacuous skin lane runs none).

Security: feature names stay single plain directory segments (traversal guard mirrors verify_red_command.dart); receipts are written inside `specs/<feature>/tdd/` only.

Maintainability: the three run commands share one driver core extracted from `run_command.dart` — no duplicated loop logic.

## Key Entities

The receipts and the lane assignment are the only new artifacts; the driver state remains the per-feature `tdd/run-state.json` and `tdd/cycle-log.md` shared by both lanes.

## Layer Contracts

- CLI layer: `zfa tdd run-engine|run-skin|run|status <feature>` with the shared `--project`, `--zfa-bin`, `--timeout` flags where the driver spawns steps.
- Service layer: lane resolution (plan files + row tags), receipt read/write, unified journal entry append.
- Driver layer: the extracted two-phase driver core (state, journal replay, reconciliation, deferrals, evidence misfire checks) — behavior-preserving.

## MCP Tool / Agent Integration

None (CLI-only commands; agents call them through the shell exactly like the existing `zfa tdd run`).
