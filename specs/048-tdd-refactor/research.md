# Research: `zfa tdd refactor`

Phase 0 findings, resolved against master@`43841d0c` (046 merged, 047 not
yet). No NEEDS CLARIFICATION remain.

## Decision 1: Mirror post-43841d0c `verify_red_command.dart` conventions

- **Decision**: `--project` flag (resolve to absolute, else
  `Directory.current`), `print()` summary line, `dart:io exitCode`
  assignment, misfire-stop try/catch with the summary always last.
- **Rationale**: one convention across the loop; 047's `make` mirrors the
  same shape.
- **Alternatives considered**: extracting a shared base command — rejected
  again; premature until `run` lands and the trio's shape is proven.

## Decision 2: Fixed, idempotent pass set instead of drift detection

- **Decision**: v1 passes are: (1) `zfa build` (codegen normalization),
  (2) `dart format` on `lib/`, (3) `dart fix --apply` on `lib/`. Each is
  idempotent; "drift" is measured by before/after tree snapshots, not by
  predicting what the generator would emit.
- **Rationale**: research found NO reliable drift detector — generated-file
  headers are inconsistent (~10 different patterns), no persistent drift
  tracker exists, and `zfa make --dry-run` doesn't expose planned contents.
  Idempotent passes + snapshot diff give the same audit outcome ("what
  changed, via which command") with zero fragile inference.
- **Alternatives considered**: header-regex ownership scan + regenerate-diff
  — rejected as v1 scope; fragile and unnecessary when passes are
  idempotent. A `drift-manifest.json` may grow later under the epic's gap
  protocol.

## Decision 3: Tree snapshot promoted to a shared service

- **Decision**: `tree_snapshot.dart` generalizes
  `verify_red_command.dart`'s private `_ReadOnlyTreeSnapshot`
  (path → `file:<sha256>` / `directory` / `link:<target>` maps, `changedPaths`
  diff). Refactor uses it twice: `test/` before/after (must be identical —
  FR-004) and `lib/` before/after (every change must map to a recorded pass —
  FR-005).
- **Rationale**: verify-red already proved the pattern; duplicating it
  privately again would be the third copy.
- **Alternatives considered**: git-diff-based attribution — rejected; would
  require the target project to be a git repo, which the spec doesn't
  assume.

## Decision 4: Suite runs go through the profile, with an injectable executor

- **Decision**: extend `runner.dart` with `loadSuiteTemplate()` /
  `runSuite()` (the same extension 047 plans — whichever lands first owns it,
  the other rebases); the command takes an injectable suite-executor override
  for tests, mirroring `MutationAuditor`'s `_runPreflightOverride` pattern.
- **Rationale**: FR-001 (profile is the only command source) plus fast
  unit-testability without real `dart test` subprocess runs.
- **Alternatives considered**: direct `Process.run('dart', ['test'])` like
  the auditor's preflight — rejected; bypasses the profile (spec FR-001) and
  Flutter projects need `flutter test`.

## Decision 5: `CycleEntryKind.refactor` + relaxed assert + actions list

- **Decision**: add `refactor` to `CycleEntryKind`; change the assert to
  `kind != red || classification != null`; fix `toMarkdown()`'s hardcoded
  red/green label; add `refactorActions` (list of recorded
  `RefactorAction(command, outcome, filesChanged)`) rendered in the entry.
  A no-op run writes an entry only with an explicit `clean` marker.
- **Rationale**: spec FR-007/FR-008; the current binary kind and assert would
  mislabel or crash on refactor entries.
- **Alternatives considered**: recording refactors as green entries with
  synthetic data — rejected; corrupts the red/green evidence semantics the
  audit relies on.

## Decision 6: Test-directory immutability is absolute, `lib/` changes must be attributed

- **Decision**: after all passes, (a) `test/` snapshot diff must be empty →
  else hard failure; (b) every path in the `lib/` snapshot diff must appear
  in at least one recorded pass's `filesChanged` → else hard failure
  (unattributed edit).
- **Rationale**: FR-004/FR-005 made mechanically checkable (SC-002/SC-003).

## Testing approach

- Fast: `refactor_passes_test.dart` (pass registry order, per-pass capture,
  failure stops remaining passes), `tree_snapshot_test.dart`, cycle-entry
  extension tests.
- Slow (`@Tags(['slow'])`, `TddFixture`-based): command tests + scenarios
  sc_010 (red-suite refusal), sc_011 (tool-only + test immutability), sc_012
  (re-proof + evidence + no-op clean path).
- Baseline recorded at planning time in the cycle log.
