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

## Cycle 9: U6 an absent target spec is copied byte-for-byte

- test: `test/cli/services/corpus_importer_test.dart::U6 (FR-001): copy an
  absent target spec is copied byte-for-byte and reported imported` (new)
- red: `dart test test/cli/services/corpus_importer_test.dart`
  -> `Expected: ['001-clean', '002-no-scenarios', '003-speckit'] /
  Actual: []` (the importer scanned nothing) (1 failed)
- green: `_scanFeatures` (subdirectories carrying spec.md, hidden
  directories and non-feature entries ignored, lexicographic order,
  empty corpus rejected) + the absent-target copy through
  `FileUtils.writeFile` (dry-run/force plumbing in place). Existing
  targets deliberately throw `UnimplementedError` — that branch is US2's
  (U7/U8/U9) and stays unimplemented until their tests exist. File
  suite -> +3 All tests passed.
- refactor: none needed
- commit: see US1 slice

## Cycle 10: U10 tdd/ is created when absent

- test: `test/cli/services/corpus_importer_test.dart::U10 (FR-001): tdd/
  working directory a per-feature tdd/ directory is created when absent`
  (new)
- red: `dart test test/cli/services/corpus_importer_test.dart`
  -> `Expected: true / Actual: <false>` — `missing tdd/ working directory
  for 001-clean` (1 failed)
- green: per-feature `specs/<feature>/tdd/` creation (only when absent,
  skipped under dry-run; existing contents never touched — that side is
  U11's). File suite -> +4 All tests passed.
- refactor: none needed
- commit: see US1 slice

## Cycle 11: U12 the readiness mark equals the SpecParser verdict

- test: `test/cli/services/corpus_importer_test.dart::U12 (FR-006):
  loop-readiness mark the mark equals the SpecParser verdict and carries
  its reason` (new)
- red: `dart test test/cli/services/corpus_importer_test.dart`
  -> `Expected: <false> / Actual: <true>` — `mark for 002-no-scenarios
  must equal the SpecParser verdict` (the placeholder `ready: true`
  disagreed with the parser) (1 failed)
- green: `_readiness` — the exact `const SpecParser().parse` entry point
  `zfa tdd plan` uses (no second parser, no regex sniffing); a
  `StateError` becomes `not-ready` with `_compactReason` mapping the
  canonical refusal to `no acceptance scenarios` (any other parser
  failure keeps its first sentence as the one-line reason). File suite ->
  +5 All tests passed.
- refactor: none needed
- commit: see US1 slice

## Cycle 12: U13 foreign artifacts are ignored and reported

- test: `test/cli/services/corpus_importer_test.dart::U13 (FR-007):
  foreign artifacts foreign artifacts are reported and ignored — never
  copied, converted or deleted` (new)
- red: `dart test test/cli/services/corpus_importer_test.dart`
  -> `Expected: true / Actual: <false>` (`hasForeignArtifacts` never set)
  (1 failed)
- green: `_foreignArtifacts` — every source-feature entry other than
  `spec.md` is reported by name (sorted) and ignored; the target for
  003-speckit contains exactly `spec.md` + the empty `tdd/` import
  created, and the source's foreign artifacts are untouched. File suite
  -> +6 All tests passed.
- refactor: none needed
- commit: see US1 slice

## Cycle 13: U15 the per-feature report and summary line match the contract

- test: `test/cli/services/corpus_importer_test.dart::U15 (FR-005):
  report + summary line ...` (new)
- red: `dart test test/cli/services/corpus_importer_test.dart`
  -> `UnimplementedError` (reportLines/summaryLine stubs) (1 failed)
- green: `CorpusImportResult.reportLines` / `.summaryLine` — the
  contracts/corpus-import.md line shape: `<name>: <outcome>
  [foreign-artifacts-ignored (<entries>)][ not-ready (<reason>)]` and
  `corpus import: N features — X imported, Y skipped, Z divergent, R
  not-ready (manifest: <path>)`, `[dry-run] `-prefixed under dry-run;
  divergent lines carry both sha256 hashes. File suite -> +7 All tests
  passed; analyze clean after two interpolation-lint fixes.
- refactor: `dart format` pass over the touched files.
- commit: see US1 slice

## Cycles 14-16: U16 arg surface / U17 invalid source / U18 registration

- tests: `test/commands/corpus_command_test.dart::U16 (FR-001): import
  arg surface ...`, `::U17 (FR-001): invalid source fails with a message,
  not a crash`, `::U18 (FR-001): registration corpus is registered in
  the CLI runner (help lists it)` (new — all written before any command
  implementation, per tasks.md's "write first, watch fail")
- red: compile error (`Error when reading
  'lib/src/commands/corpus_command.dart': No such file or directory`),
  then with a registered no-op stub family:
  `Expected: contains 'dry-run' / Actual: {'help': ...}` (no flags),
  `Expected: contains 'required' / Actual: '❌ Could not find an option
  named "--project".'` (no source-required usage error),
  `Expected: contains 'not found'` (no invalid-source message),
  `Expected: contains 'corpus' / Actual: 'zfa - Zuraffa Code Generator
  v6.1.0'` (help lacks the corpus line) — 6 command-level tests red
- green: `lib/src/commands/corpus_command.dart` — `CorpusCommand` family
  + `CorpusImportCommand` (mandatory `source` positional, `--dry-run`,
  `--force`, `--project`/`--project-root`; prints report + summary;
  completes with exit 0), registered in `_addCoreCommands`, plus the
  `corpus import <dir>` line in the hand-written top-level help.
  File suite -> +4 passing with A1-A3 still red.
- refactor: none needed
- commit: see US1 slice

## Cycle 17: US1 outer loop closes — A1, A2, A3 green

- With U16-U18 green, the A-tests ran end-to-end and failed only on the
  missing manifest emission:
  `PathNotFoundException: Cannot open file, path =
  '/tmp/zfa_corpus_app_*/.zfa/manifests/corpus-manifest.json'`
  (A1/A2/A3 red on the manifest contract — the last US1 gap).
- green: the importer now emits the `CorpusManifest` (every feature,
  name/ready/reason, source corpus, importedAt; regenerated on every
  import; `dryRun` honored) after the per-feature pass.
  `dart test test/commands/corpus_command_test.dart` -> +7 All tests
  passed (A1, A2, A3 GREEN — US1 complete end-to-end: import → spec
  copies → tdd/ dirs → readiness marks → manifest → report →
  `zfa tdd plan` succeeds on the ready feature and refuses the
  not-ready one with the manifest's reason).
- full feature-scope suite: `dart test test/cli/services/ test/commands/
  test/core/project/` -> 71 passed, 0 failed (53 baseline + 18 feature
  tests). `dart analyze` on the touched trees: No issues found.
- refactor: `dart format` pass; A2's plan-refusal assertions confirmed
  the SpecParser-parity contract holds through the real CLI.
- commit: see US1 slice