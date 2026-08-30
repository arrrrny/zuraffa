# Research: `zfa tdd verify-red`

Phase 0 findings. All Technical Context items resolved against the codebase
on branch `046-tdd-verify-red`; no NEEDS CLARIFICATION remain.

## Decision 1: Reuse existing tdd-plugin infrastructure

- **Decision**: Build on `ArtifactRegistry`, `CycleLog`, `TddProfile`,
  `VerifyRedCommand` stub (already registered in `TddCommand`).
- **Rationale**: All four exist and are exercised by specs 041/044; the stub
  is already wired into `lib/src/commands/tdd_command.dart`.
- **Alternatives considered**: parallel helpers — rejected; would fork the
  registry/log contracts the loop driver depends on.

## Decision 2: New `runner.dart` as the single-test execution service

- **Decision**: Create `lib/src/plugins/tdd/services/runner.dart`: resolves
  the profile `single` template (`{file}`, `{name}` substitution) and runs it
  via `Process.run`, capturing exit code + combined output.
- **Rationale**: No shared test-runner helper exists today —
  `MutationAuditor._defaultPreflight` and `MutationVerifier` each call
  `Process.run` directly. A dedicated service gives the classifier a clean
  input record and gives future commands (`make`, `run`) a reusable runner.
- **Alternatives considered**: inlining `Process.run` in the command (like
  `verify_command.dart`) — rejected; classification needs structured capture
  and `make`/`run` will need the same wrapper.

## Decision 3: New `red_classifier.dart` with a six-way outcome enum

- **Decision**: Classify runner results into exactly: `assertion`,
  `compile-error`, `load-error`, `skipped`, `unexpected-green`,
  `runner-error` (spec FR-004).
- **Rationale**: The spec's gate semantics require distinguishing all six;
  the existing `FailureClass` enum in `cycle_entry.dart` has only four values
  (`assertionFailure`, `compileError`, `loadError`, `unexpectedGreen`) and
  must be widened (add `skipped`, `runnerError`) or mapped at the boundary.
- **Classification rule order** (from runner output analysis):
  1. process failed to start / non-test infrastructure failure → `runner-error`
  2. `Failed to load` / missing file / unresolvable import → `load-error`
  3. compilation diagnostics (`Error:` from the CFE, `Compilation failed`) → `compile-error`
  4. exit 0 with skip/pending markers only → `skipped`
  5. exit 0 → `unexpected-green`
  6. exit non-zero with `Expected:`/`Actual:`/`TestFailure` assertion
     signature → `assertion`
  7. exit non-zero without assertion signature → `runner-error` (unexplained
     failure is not honest red)
- **Alternatives considered**: regex-per-class inline in the command —
  rejected; untestable and duplicates `MutationVerifier`'s hard-won parsing
  lesson (keep parsing in a pure, unit-testable function).

## Decision 4: Extend `CycleLogEntry` rather than wrap it

- **Decision**: Add `sourceCriterion`, `testPath`, `timestamp` to
  `CycleLogEntry`; keep `CycleLog.append` append-only.
- **Rationale**: Spec FR-006 requires eight evidence fields; the current
  entry has five. The 041 cycle-log format already tolerates extra bullet
  lines, so extension is backward-compatible.
- **Alternatives considered**: sidecar JSON evidence file — rejected; splits
  the human-readable audit trail the epic depends on.

## Decision 5: Target resolution from registry + cycle log, no globbing

- **Decision**: Explicit id → `ArtifactRegistry.findRecord`; no id → exactly
  one registry record whose behavior has no red entry in `cycle-log.md`;
  otherwise error listing candidates.
- **Rationale**: Spec FR-001/FR-002; registry is the contract surface written
  by `gen`.
- **Alternatives considered**: scanning `test/` for `*_test.dart` — rejected
  (spec forbids rediscovery by globbing).

## Decision 6: Scope-guard against blended runs

- **Decision**: The classifier input includes the parsed test count/result
  summary; if the runner executed anything other than exactly the target
  test, reject as `runner-error` (spec FR-005).
- **Rationale**: `dart test <file> --plain-name "<name>"` still loads the
  file; output parsing must confirm a single test outcome.

## Testing approach

Fast unit tests (no `slow` tag) under `test/plugins/tdd/`:
- `red_classifier_test.dart` — fixture matrix of canned runner outputs →
  expected class, covering all six classes (spec SC-001).
- `runner_test.dart` — profile substitution + capture contract, using a tiny
  real `dart test` fixture project in a temp dir (mirrors existing
  `CliRunner` + `Directory.systemTemp` conventions).
- `verify_red_command_test.dart` — end-to-end command contract: certified
  red writes a complete log entry and exits 0; each dishonest class exits
  non-zero with an unchanged log; read-only guarantee verified by checksums
  (spec SC-002/SC-003).
