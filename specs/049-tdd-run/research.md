# Research: `zfa tdd run`

Phase 0 findings, resolved against master@`43841d0c` (046 merged; 047/048
planned, not merged — the driver consumes their contracts, not their code).
No NEEDS CLARIFICATION remain.

## Decision 1: Steps are sub-processes of the zfa CLI, consumed via contracts

- **Decision**: `step_runner.dart` spawns `dart <zfa-entrypoint> tdd <step>
  <behavior-id> --feature <f> --project <dir>` via `Process.run`, captures
  exit code + output, and parses the step's documented summary line
  (`verify-red: behavior=... certified=...`, `make: ... outcome=...`,
  `refactor: ... outcome=...`). Success = exit 0 AND contract-consistent
  summary line.
- **Rationale**: spec FR-002 (machine contracts, not prose) and the
  Assumptions (sub-process crash isolation). Entrypoint resolution reuses
  the `run_zfa_source.dart` pattern: `Isolate.resolvePackageUri` → project
  root → `bin/zfa.dart`, with a `--zfa-bin` override (same flag 047 plans).
- **Alternatives considered**: in-process `CliRunner` composition — rejected;
  a step crash would take the driver's state with it, and `make`/`build`
  call `exit()` internally.

## Decision 2: State machine mapping and re-entry

- **Decision**: state → next step(s): `pending` → `gen` then `verify-red`;
  `red` → `make`; `green` → `refactor`; `done` → skip. Sequence per step:
  `markInFlight(behavior, step)` + save → spawn step → on success `advance`
  (clears in-flight) + save. A crash between markInFlight and advance resumes
  at exactly that step.
- **Rationale**: `RunState.advance` already clears in-flight markers — the
  mark→run→advance rhythm is the model's designed usage.
- **Alternatives considered**: per-step sub-states (e.g. `generated`) —
  rejected; four states are the spec's contract (FR-001), and re-entry is
  already safe via each step's idempotency.

## Decision 3: Evidence beats state, parsed by a shared cycle_evidence service

- **Decision**: `cycle_evidence.dart` generalizes verify_red's
  `split('\n## ')` section parsing into `redEvidence(featureDir)` and
  `greenEvidence(featureDir)` sets. On load, the driver intersects state
  with evidence: a `done` claim without both red and green entries is
  demoted to the highest evidence-backed state.
- **Rationale**: spec FR-003 — the audit trail is the truth, the state file
  a cache.
- **Alternatives considered**: trusting the state file — rejected (spec
  US3.AC3).

## Decision 4: Atomic state writes; in-flight marker is the concurrency guard

- **Decision**: `run_state_store.dart` writes via temp-file + rename; load
  validates JSON shape and reports corruption with the recovery path
  (delete to restart). A non-null in-flight marker at start (and no evidence
  the owning process is this one) refuses the second run.
- **Rationale**: FR-004/FR-006; the codebase has no lock-file pattern and
  needs none — the state file is the coordination point.
- **Alternatives considered**: OS file locks — rejected; unneeded complexity
  for a sequential driver.

## Decision 5: Parse the 4-column test-list format that `plan` actually writes

- **Decision**: `test_list_reader.dart` parses the `| id | behavior | traces
  | state |` rows produced by `plan_command.dart` (kind inferred from the
  section header), and reconciles against the state file: rows removed from
  the spec become DROPPED-marker entries (retained, never deleted — spec edge
  case); new rows append as PENDING.
- **Rationale**: the writer's format is the contract the driver must read.
- **GAP FOUND (to file)**: `gen_command.dart`'s `_parseBehaviorRow` expects a
  6-column table (`id|description|source|kind|state|target`) while
  `plan_command.dart` writes 4 columns — `gen` cannot parse what `plan`
  emits. This is a real zuraffa gap for the epic's gap protocol: file it;
  the driver itself does not depend on the 6-column parse. **Not fixed in
  this spec** (out of scope; 044/041 own those commands).
- **Alternatives considered**: teaching the driver both formats — rejected;
  papers over the gap instead of surfacing it.

## Decision 6: Fixture extensions drive the slow-tier scenarios

- **Decision**: extend `TddFixture` with test-list seeding (4-column format),
  run-state seeding, green evidence seeding, and mixed-state multi-behavior
  fixtures. Driver tests use stubbed step executors (fast) plus slow-tier
  scenarios with scripted fake step binaries.
- **Rationale**: same fixture strategy as 046/047/048; the driver's logic
  (state machine, resume, evidence reconciliation) is testable without real
  generation.

## Testing approach

- Fast: `test_list_reader_test.dart`, `run_state_store_test.dart`,
  `step_runner_test.dart` (fake step process), `cycle_evidence_test.dart`.
- Slow (`@Tags(['slow'])`): `run_command_test.dart` + scenarios sc_013–016
  (drive-to-done, resume-at-each-boundary, stop-on-failure matrix, summary
  contract).
- Baseline recorded in the cycle log at planning time.
