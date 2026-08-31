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


