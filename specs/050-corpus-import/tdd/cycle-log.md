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
- commit: `5efc0385`

## Cycles 18-20: A4 / A5 / A6 open US2's outer loop (RED)

- tests: `test/commands/corpus_command_test.dart::A4 (US2.AC1) re-import
  after corpus growth touches only the new features ...`,
  `::A5 (US2.AC2) tdd/ immutability re-import leaves existing tdd/ trees
  byte-identical (checksum-verified)`, `::A6 (US2.AC3) divergence a
  divergent spec is kept by default with both hashes reported; --force
  updates it` (new — written before any existing-target implementation)
- red: `dart test test/commands/corpus_command_test.dart`
  -> `Actual: '❌ Error: UnimplementedError'` for A4 and A6 (the
  existing-target branch was a deliberate stub from cycle 9); A5
  initially PASSED vacuously — its only assertion (tdd/ checksums)
  held because the failing import never touched anything — so it was
  strengthened BEFORE any implementation to also assert the re-import
  completes (`expect(out, isNot(contains('❌')))` + the skipped report
  line), after which A5 failed with the same `UnimplementedError`
  (3 failed)
- green: not yet — the units below drive it
- commit: see US2/US3 slice

## Cycle 21: U7 an identical existing spec is skipped

- test: `test/cli/services/corpus_importer_test.dart::U7 (FR-003):
  idempotent re-import an identical existing spec is skipped` (new)
- red: `dart test test/cli/services/corpus_importer_test.dart`
  -> `UnimplementedError` (1 failed)
- green: sha256-aware copy decision — absent -> imported (copy),
  identical -> skipped (nothing written). The divergent branch remains
  a deliberate stub for U8. File suite -> +8 All tests passed.
- refactor: the copy decision was extracted into one place (absent /
  identical / divergent-force branches) with the hashes computed once.
- commit: see US2/US3 slice

## Cycle 22: U8 a different existing spec is kept with both hashes

- test: `test/cli/services/corpus_importer_test.dart::U8 (FR-004):
  divergence a different existing spec is kept with both hashes
  reported` (new)
- red: `dart test test/cli/services/corpus_importer_test.dart`
  -> `UnimplementedError` (the divergent branch stub) (1 failed)
- green: divergent -> target kept, both sha256 hashes carried in the
  result and printed on the report line (`divergent (source
  sha256:<hex>, target sha256:<hex>)`). File suite -> +9 All tests
  passed.
- refactor: none needed
- commit: see US2/US3 slice

## Cycle 23: U9 --force replaces a divergent spec

- test: `test/cli/services/corpus_importer_test.dart::U9 (FR-004): force
  replaces a divergent spec (imported)` (new)
- red: `dart test test/cli/services/corpus_importer_test.dart`
  -> `UnimplementedError` (the force branch stub) (1 failed)
- green: `--force` writes the source content over the divergent copy
  (outcome `imported`); A4/A5/A6 closed green with it (command file ->
  +10 All tests passed — US2 complete end-to-end).
- refactor: the force write reuses the same `FileUtils.writeFile` call
  as the absent-target copy.
- commit: see US2/US3 slice

## Cycle 24: U11 existing tdd/ contents are never modified

- test: `test/cli/services/corpus_importer_test.dart::U11 (FR-003):
  tdd/ immutability existing tdd/ contents are never modified
  (checksum-verified)` (new; checks both a plain and a `--force`
  re-import leave a populated tdd/ tree byte-identical)
- red: immediate pass — the importer never writes under `tdd/` by
  construction (U10's creation-only branch). Deliberate-mutant check:
  made the import write `tdd/marker.txt` unconditionally ->
  `+1 -10: Some tests failed` (U11 among them) — the test catches
  tdd/ mutation. Restored exactly; file suite -> +11 All tests passed.
- verdict: mutant-verified immediate pass.
- commit: see US2/US3 slice

## Cycle 25: U14 --dry-run writes nothing, manifest included

- test: `test/cli/services/corpus_importer_test.dart::U14 (FR-003):
  dry-run writes nothing, manifest included` (+ a second test: dry-run
  after a real import writes nothing new) (new)
- red: immediate pass — the dry-run plumbing (FileUtils `dryRun`, tdd/
  guard, manifest `dryRun`) landed with U6/U10/US1-close. Deliberate-
  mutant check: dropped `dryRun: dryRun` from the manifest write ->
  `U14 ... [E]` (manifest written under dry-run) — caught. Restored
  exactly; file suite -> +13 All tests passed.
- verdict: mutant-verified immediate pass.
- commit: see US2/US3 slice

## Cycle 26: A7 manifest marks every feature ready/not-ready

- test: `test/commands/corpus_command_test.dart::A7 (US3.AC1): manifest
  readiness marks manifest marks every feature ready/not-ready with a
  one-line reason` (new)
- red: immediate pass — the marks were driven by US1's close (A1/A3).
  Deliberate-mutant check: manifest emission dropped the reason
  (`reason: ''`) -> `A7 ... [E]` — caught. Restored exactly.
- verdict: mutant-verified immediate pass.
- commit: see US2/US3 slice

## Cycle 27: A8 the manifest mark is the consumer contract

- test: `test/commands/corpus_command_test.dart::A8 (US3.AC2): the
  manifest mark is the consumer contract a consumer (batch driving,
  #628) can rely on the manifest mark without re-deriving it` (new —
  simulates #628's batch driver deciding purely from the manifest JSON)
- red: immediate pass. Deliberate-mutant check: inverted the manifest's
  `ready` mark -> `A8 ... [E]` (drivable/blocked lists wrong) — caught.
  Restored exactly; command file -> +12 All tests passed.
- verdict: mutant-verified immediate pass.
- commit: see US2/US3 slice

## Cycle 28: T013/U12 readiness parity across 4 borderline shapes

- test: `test/cli/services/corpus_importer_test.dart::U12/T013
  (FR-006): readiness parity across borderline shapes the importer mark
  equals the plan parser verdict for 4 fixture shapes (full / no
  scenarios / no FRs / malformed)` (new — tasks.md T013's 4-shape
  matrix: full and no-FRs -> ready; no-scenarios and empty spec ->
  not-ready, exactly what `zfa tdd plan` does with the same files)
- red: immediate pass (U12's `_readiness` IS the parser call).
  Deliberate-mutant check: `_readiness` made to return always-ready
  without consulting the parser -> `+8 -2 ... [E]` (parity broken for
  s-noscen/s-malformed) — caught. Restored exactly; file suite -> +14
  All tests passed.
- verdict: mutant-verified immediate pass.
- US3 close: A7/A8 green; `dart test test/cli/services/ test/commands/
  test/core/project/` -> 83 passed, 0 failed; analyze clean.
- commit: `cac9c108`

## Cycle 29: U19 --specs triggers the import step after the TDD baseline

- test: `test/commands/setup_corpus_specs_test.dart::U19 (FR-001): --specs
  triggers the import step the corpus import runs after the TDD baseline
  step, with 8-step numbering when present` (+ `exposes the --specs
  option`) (new — fast tier, drives setup in --dry-run so the whole flow
  runs without subprocesses; setup's legacy test file is slow-tagged and
  stays untouched)
- red: `dart test test/commands/setup_corpus_specs_test.dart`
  -> `Expected: a value greater than or equal to <0> / Actual: <-1>` (no
  `[6/8]` step — the CLI output shows `❌ Could not find an option named
  "--specs".`) and `Expected: contains 'specs'` (option surface) (2
  failed; U20 passed — see below)
- green: `setup_command.dart` gained `--specs <dir>`; with it the flow
  numbers 8 steps, imports the corpus into the new app through the
  shared `CorpusImporter` (dry-run plumbed), and prints the report; the
  TDD-baseline step is [6/8], import [7/8], summary [8/8]. File suite ->
  +3 All tests passed.
- refactor: none needed (one guarded step + dynamic step total).
- commit: see implement slice

## Cycle 30: U20 setup without --specs behaves exactly as before

- test: `test/commands/setup_corpus_specs_test.dart::U20 (FR-001): setup
  without --specs is unchanged no corpus import step, legacy 7-step
  numbering, no corpus output` (new)
- red: immediate pass — U20 passed in cycle 29's red run (setup without
  the flag was untouched, which IS the behavior). Deliberate-mutant
  check: made the corpus-import step run unconditionally (guard removed)
  -> U20 failed (`Some tests failed`, corpus output leaked into the
  no-specs run) — caught. Restored exactly; file suite -> +3 All tests
  passed.
- verdict: mutant-verified immediate pass.
- commit: see implement slice

## Cycle 31: quickstart scenarios 1-5 executed verbatim (task T018)

- command: `dart run bin/zfa.dart corpus import /tmp/fx-corpus --project
  /tmp/fx-app` (a real 3-feature fixture corpus at /tmp/fx-corpus, fresh
  app at /tmp/fx-app)
- output (verbatim):
  `001-clean: imported` /
  `002-no-scenarios: imported not-ready (no acceptance scenarios)` /
  `003-speckit: imported foreign-artifacts-ignored (checklists, tdd)` /
  `corpus import: 3 features — 3 imported, 0 skipped, 0 divergent, 1
  not-ready (manifest: /tmp/fx-app/.zfa/manifests/corpus-manifest.json)`
  / `exit=0`
- scenario 3 (loop-readiness): `dart run bin/zfa.dart tdd plan
  001-clean --project /tmp/fx-app` -> `zfa tdd plan: wrote
  File: '/tmp/fx-app/specs/001-clean/tdd/test-list.md' with 1 acceptance
  + 1 unit behaviors (2 total).` `exit=0`; `tdd plan 002-no-scenarios`
  -> `❌ Error: Bad state: zfa tdd plan: cannot derive behaviors`
  `exit=1`, stderr carrying the parser's `contains no acceptance
  scenarios` message — the manifest's reason.
- scenario 4 (idempotency + divergence): re-import -> `001-clean:
  skipped` / `002-no-scenarios: skipped not-ready (...)` /
  `003-speckit: skipped foreign-artifacts-ignored (...)`, exit=0; after
  editing the source spec -> `001-clean: divergent (source
  sha256:7e426326..., target sha256:e1f91fdb...)` with the target kept
  (grep for the new content in the target: 0 matches); `--force` ->
  `001-clean: imported` and the target updated (1 match).
- scenario 5 (dry-run): fresh app, `--dry-run` -> `[dry-run] `-prefixed
  report, exit=0, and NEITHER `specs/` NOR `.zfa/` exists afterwards
  (zero writes, manifest included).
- setup wiring (dry-run end-to-end): `zfa setup demo_app --dart --no-git
  --dry-run --specs /tmp/fx-corpus` -> `[6/8] Skipping TDD baseline ...`
  `[7/8] Importing spec corpus from /tmp/fx-corpus...` + the [dry-run]
  report + `[8/8] Setup complete!`.
- commit: see implement slice