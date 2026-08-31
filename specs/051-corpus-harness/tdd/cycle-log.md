# Cycle Log: `zfa tdd corpus` — batch driving, verify gate, provenance audit, gap ledger

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 227 passed, 0 failed (fast tier)
- analyze: `dart analyze` -> No issues found!
- commit: `64705f26`
- recorded: cycle 0, before any change

## Cycle 1: T001 — the corpus command family registers (scaffolding)

- test: `test/plugins/tdd/tdd_command_smoke_test.dart::zfa tdd --help lists the corpus family (051, T001)` + `::zfa tdd corpus --help lists run, status, audit (051, T001)` (new)
- red: `dart test --preset=all test/plugins/tdd/tdd_command_smoke_test.dart`
  -> `Expected: contains 'corpus'` (2 failed: corpus family + corpus --help;
  the help output listed only the eight 041 subcommands)
- green: created `lib/src/plugins/tdd/commands/corpus{_,_run,_status,_audit}_command.dart`
  (usage-printing skeletons, `--project`/`--zfa-bin` flags declared) and
  registered `CorpusCommand` in `lib/src/commands/tdd_command.dart`.
  Suite `dart test --preset=all test/plugins/tdd/tdd_command_smoke_test.dart`
  -> `00:00 +7: All tests passed!`; `dart analyze lib/src/plugins/tdd/commands/`
  -> No issues found
- refactor: none needed (skeletons only; the first assertion draft demanded
  `status`/`audit` inside `zfa tdd --help`, which lists only first-level
  subcommands — the observable was corrected to the corpus line + the
  dedicated `corpus --help` test, before any implementation landed)
- commit: (this commit)
- notes: T001 is scaffolding (no A/U marker): the command family exists and
  is smoke-tested; the driving/status/audit logic lands with the behavior
  cycles below.

## Cycle 2: U1 + U2 — the manifest model decodes in order, rejects malformed

- test: `test/plugins/tdd/models/corpus_models_test.dart::CorpusManifest (U1) decodes features in file order with optional provenance` + 5 siblings (U1 pair + U2 malformed matrix)
- red: `dart test test/plugins/tdd/models/corpus_models_test.dart`
  -> `UnimplementedError` / `Which: threw UnimplementedError:<UnimplementedError>` (6 failed against the minimal stub — order, optional fields, and every malformed shape unpinned)
- green: implemented `CorpusManifest.fromJson` + `CorpusFeature` +
  `CorpusManifestException` (message names corpus-manifest.json + recovery)
  in `lib/src/plugins/tdd/models/corpus_manifest.dart`.
  Suite -> `00:00 +6: All tests passed!`;
  `dart analyze lib/src/plugins/tdd/models/` -> No issues found
- refactor: dropped an `unnecessary_cast` the analyzer flagged; no other
  change needed
- commit: (this commit)


## Cycle 3: U3 + U4 + U5 — the manifest store reads manifest, carve-out, waivers

- test: `test/plugins/tdd/services/corpus_manifest_store_test.dart` (U3 manifest reading x3, U4 carve-out x3, U5 waivers x3, + the path-constants test)
- red: `dart test test/plugins/tdd/services/corpus_manifest_store_test.dart`
  -> `Which: threw UnimplementedError:<UnimplementedError>` (7 of 10 failed against the store stubs; the path-constants test passed — pure plumbing already pinned)
- green: implemented `readManifest` (absent -> `CorpusManifestMissingException`
  naming the path + #627 remediation; invalid JSON -> corrupt), `readCarveOut`
  (absent -> empty; `{carveouts: [{path, reason}]}` validated), `readWaivers`
  (absent -> empty; row shape validated) + `CarveOutEntry` /
  `CorpusManifestMissingException` models and the full `.zfa/` path constants.
  Suite (models + store) -> `00:00 +16: All tests passed!`;
  `dart analyze lib/src/plugins/tdd/` -> No issues found
- refactor: dropped an `unnecessary_cast`; nothing else needed
- commit: (this commit)
## Cycle 4: U6 + U7 + U8 + U9 + U10 — progress model round trip + atomic store

- test: `test/plugins/tdd/services/corpus_progress_store_test.dart` (U6 round trip x2, U7 atomicity, U8 corruption x3, U9 refusal x2, U10 dropped, + save/load integration x2)
- red: `dart test test/plugins/tdd/services/corpus_progress_store_test.dart`
  -> `UnimplementedError` (10 of 11 failed against the stubs — round trip, atomicity, corruption, refusal, dropped all unpinned; the path test passed)
- green: implemented `CorpusProgress.fromJson` (strict shape validation) +
  mutable state helpers + `CorpusProgressStore` (temp+rename atomic save,
  load corruption gate with recovery, pid in-flight refusal with injectable
  probe, dropped computation retaining entries). Suite (models + stores)
  -> `00:00 +79: All tests passed!`; `dart analyze lib/src/plugins/tdd/`
  -> No issues found
- refactor: removed two `unnecessary_cast`s; made the model's in-flight/
  dropped fields mutable (a runner-held state object saved by the store)
- commit: (this commit)
## Cycle 5: U11 + U12 + U13 + U14 — ledger totals + append-only store

- test: `test/plugins/tdd/models/corpus_models_test.dart::GapLedger totals (U11) computes found / filed / merged / blocking from entries` + `test/plugins/tdd/services/gap_ledger_store_test.dart` (U12 x3, U13, U14)
- red: `dart test test/plugins/tdd/services/gap_ledger_store_test.dart test/plugins/tdd/models/corpus_models_test.dart`
  -> `UnimplementedError` (6 failed against the stubs — totals, monotonic ids, append stability, resolution semantics)
- green: implemented `GapLedgerTotals.fromEntries` (found/filed/merged/
  blocking; a gap resolves via status resolved/merged OR a resolution entry)
  + `GapLedgerStore` (load with corrupt gate, `gap-###`/`res-###` monotonic
  ids, atomic temp+rename persist with fixed field order for byte-stable
  appends). Suite -> `00:00 +12: All tests passed!`;
  `dart analyze lib/src/plugins/tdd/` -> No issues found
- refactor: none needed
- notes: the U11 test's first draft expected 1 blocking gap; the
  data-model definition ("unresolved gaps whose feature is not done/waived")
  makes a filed-but-unmerged gap still blocking — the expectation was
  corrected to 2 (gap-001 open + gap-002 filed-not-merged) BEFORE the
  implementation was accepted, and the reason is recorded here.
- commit: (this commit)
## Cycle 6: U15 + U16 + U17 + U18 — the corpus step runner

- test: `test/plugins/tdd/services/corpus_step_runner_test.dart` (U15 run spawn/parse x3, U16 verify x2, U17 missing line, U18 spawn failure)
- red: `dart test test/plugins/tdd/services/corpus_step_runner_test.dart`
  -> `UnimplementedError` (7 failed against the stubs)
- green: implemented `CorpusStepRunner` (argv contracts `tdd run <f>
  --project <dir>` / `tdd verify --feature <f> --project <dir>`, `.dart`
  entrypoints through `dart`, injectable spawner, last-`<verb>:` line
  parsing, success = exit 0 AND token agreement, missing-line and spawn
  failures as runner-error misfires). Suite -> `00:00 +7: All tests
  passed!`; `dart analyze` -> No issues found
- refactor: moved the default spawner back inside the class after a
  misplaced brace; no behavior change
- commit: (this commit)
