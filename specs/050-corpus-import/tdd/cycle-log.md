# Cycle Log: `zfa corpus import`

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/commands test/core/project` -> 53 passed, 0 failed
  (fast tier; `test/cli/services/` is created by this feature)
- commit: `2a6246f3`
- recorded: cycle 0, before any change

## Notes and deviations

- All tests are fast tier (file-I/O only); no subprocess/slow suites.
- Blocks on nothing in the loop; #628's batch driver consumes this
  feature's manifest contract.
- Consumes issue #627 (feature origin) and plan decisions from
  `specs/050-corpus-import/research.md`.
- Session start point: master@`bd90a04f` merged into `ffb2fc96`
  (origin/050-corpus-import) — plan/tasks/test-list artifacts already
  committed there; `dart analyze` pristine (0 issues), fast tier 53/53
  green before cycle 1.
- Outer loop opened first (A1-A3 acceptance tests written and observed
  red before any unit implementation), per `loop: outside-in`.

## Cycle 1: A1 N-feature corpus import (RED — outer loop open)

- test: `test/commands/corpus_command_test.dart::A1 (US1.AC1): N-feature
  corpus import copies every spec.md, creates per-feature tdd/ dirs, and
  lists all N features deterministically in the manifest` (new)
- red: `dart test test/commands/corpus_command_test.dart`
  -> `Expected: true / Actual: <false>` (spec.md missing under the app's
  specs/) — CLI output shows why: `❌ Could not find an option named
  "--project".` (no `corpus` command is registered; the args fall through
  to the global parser) (1 failed)
- green: not yet — the acceptance test stays red until US1's units
  (U1-U18) land; state RED in the test list.
- refactor: n/a
- commit: (evidence committed with the US1 slice)

## Cycle 2: A2 loop-plannability after import (RED — outer loop open)

- test: `test/commands/corpus_command_test.dart::A2 (US1.AC2):
  loop-plannability after import ...` (new)
- red: `dart test test/commands/corpus_command_test.dart`
  -> `Expected: true / Actual: <false>` — CLI output:
  `❌ Error: Bad state: zfa tdd plan: spec not found` (the import never
  happened, so the imported feature has no spec.md to plan from) (1 failed)
- green: not yet (outer loop open)
- refactor: n/a

## Cycle 3: A3 not-loop-ready specs (RED — outer loop open)

- test: `test/commands/corpus_command_test.dart::A3 (US1.AC3):
  not-loop-ready specs a no-scenario feature is imported verbatim AND
  reported not-ready ...` (new)
- red: `dart test test/commands/corpus_command_test.dart`
  -> `Expected: true / Actual: <false>` (002-no-scenarios/spec.md never
  imported); CLI output: `❌ Could not find an option named "--project".`
  (1 failed)
- green: not yet (outer loop open)
- refactor: n/a

## Cycle 4: U1 round-trips through toJson/fromJson

- test: `test/core/project/corpus_manifest_test.dart::U1 (FR-002): json
  round-trip round-trips features, sourceCorpus and importedAt` (new)
- red: `dart test test/core/project/corpus_manifest_test.dart`
  -> compile error `Error: 'CorpusManifest' isn't a type` (the language
  requires the symbols; minimal stubs added with `UnimplementedError`
  bodies), re-run -> `UnimplementedError` (1 failed)
- green: `lib/src/core/project/corpus_manifest.dart` — `toJson`/`fromJson`
  on `CorpusFeature` and `CorpusManifest`. File suite:
  `dart test test/core/project/corpus_manifest_test.dart` -> +1 All tests
  passed. Fast tier `dart test test/commands test/core/project` -> 54
  passed, 3 failed (A1-A3, red by design — outer loop open).
- refactor: none needed (two small symmetric methods)
- commit: see US1 slice

## Cycle 5: U2 features serialize in deterministic lexicographic order

- test: `test/core/project/corpus_manifest_test.dart::U2 (FR-002):
  deterministic lexicographic order features serialize in lexicographic
  order however constructed` (new)
- red: `dart test test/core/project/corpus_manifest_test.dart`
  -> `Expected: ['001-clean', '002-no-scenarios', '003-speckit'] /
  Actual: ['002-no-scenarios', '001-clean', '003-speckit']` (1 failed)
- green: `CorpusManifest`'s constructor now defensively sorts its feature
  list lexicographically (the model enforces the invariant however it is
  constructed). File suite -> +2 All tests passed.
- refactor: U1's assertion was relaxed from list-order to set-equality
  BEFORE this cycle's implementation (order is U2's behavior, not U1's —
  a test-shape correction, made before the behavior change as the
  discipline requires; recorded here as a deviation).
- notes: first green attempt failed to compile (`'features' was already
  initialized by this constructor`) — fixed by taking the list as a plain
  parameter and sorting in the initializer; suite re-run green.
- commit: see US1 slice

## Cycle 6: U3 write→read stable except importedAt

- test: `test/core/project/corpus_manifest_test.dart::U3 (SC-004):
  manifest stability write→read is byte-stable across identical
  re-imports except importedAt` (new)
- red: `dart test test/core/project/corpus_manifest_test.dart`
  -> `UnimplementedError` (write/read stubs) (1 failed)
- green: `CorpusManifest.write` (deterministic indented JSON, creates
  `.zfa/manifests/`, honors `dryRun` by skipping the write) +
  `CorpusManifest.read`. File suite -> +3 All tests passed;
  `dart analyze` on the touched files: No issues found.
- refactor: none needed
- commit: see US1 slice

## Cycle 7: U4 a missing manifest reads as null

- test: `test/core/project/corpus_manifest_test.dart::U4 (FR-002):
  missing manifest reads as null (not an error) on a fresh project` (new)
- red: immediate pass — the behavior already exists in U3's natural
  `read` implementation (`if (!file.existsSync()) return null`).
  Deliberate-mutant check per the playbook: mutated `read` to
  `throw StateError('missing manifest')` on a missing file ->
  `Bad state: missing manifest` (U4 failed, 1 failed) — the test catches
  the mutant. Restored the code exactly; suite -> +4 All tests passed.
- verdict: mutant-verified immediate pass (recorded honestly; the
  behavior was a byproduct of U3's implementation, not written after U4).
- commit: see US1 slice

## Cycle 8: U5 corpus root accepted, single-feature path rejected

- test: `test/cli/services/corpus_importer_test.dart::U5 (FR-001):
  source validation accepts a corpus root` +
  `... rejects a single-feature path with a clear message` (new)
- red: `dart test test/cli/services/corpus_importer_test.dart`
  -> `UnimplementedError` (import stub) (2 failed)
- green: `lib/src/cli/services/corpus_importer.dart` —
  `_validateSource`: not-found / file-not-a-corpus-root / single-feature
  (spec.md directly inside) rejections with clear messages; a corpus root
  returns an (empty, U6-pending) result. File suite -> +2 All tests
  passed; analyze: No issues found.
- refactor: none needed
- deviation: the validation logic was accidentally drafted in the first
  stub file before the red run; it was reverted to `UnimplementedError`,
  the red observed and recorded, then the validation re-applied — the
  red-before-green sequence above is the real one.
- commit: see US1 slice