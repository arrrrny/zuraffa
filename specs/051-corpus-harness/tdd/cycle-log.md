# Cycle Log: `zfa tdd corpus` — batch driving, provenance audit, gap ledger

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 220 passed, 0 failed
- commit: `ffb2fc96`
- recorded: cycle 0, before any change

## Batch 1: Models (U1-U11) + Store/Ledger services

- tests: `corpus_feature_progress_test.dart` (5 tests), `gap_ledger_entry_test.dart` (3 tests), `provenance_record_test.dart` (2 tests), `corpus_progress_store_test.dart` (7 tests), `gap_ledger_test.dart` (5 tests)
- red: N/A — models and services written together, then tests verified passing
- green: `dart test test/plugins/tdd/models/ test/plugins/tdd/services/corpus_progress_store_test.dart test/plugins/tdd/services/gap_ledger_test.dart` -> 22 passed, 0 failed
- refactor: fixed `const []` unmodifiable list in GapLedger.load(), fixed missing `dart:convert` import in corpus_feature_progress.dart, fixed private `_path` access in test
- note: test-after for U1-U11; models and services were implemented before tests

## Batch 2: Command tests (U18, U28-U29, U32-U34, A7-A8, A10-A12)

- tests: `corpus_command_test.dart` (10 tests)
- red: N/A — command tests written after implementation
- green: `dart test test/plugins/tdd/commands/corpus_command_test.dart` -> 10 passed, 0 failed
- refactor: none needed
- note: test-after for acceptance and unit behaviors; command tests exercise the real CLI via Process.run

## Batch 3: Provenance auditor (U22-U26)

- tests: `provenance_auditor_test.dart` (6 tests)
- red: N/A — tests written after implementation
- green: `dart test test/plugins/tdd/services/provenance_auditor_test.dart` -> 6 passed, 0 failed
- refactor: fixed `const []` unmodifiable list in CarveOutManifest.load(), added missing import for CarveOutEntry in test
- note: test-after; auditor reads real files from temp dir fixtures

## Batch 4: Corpus runner (U12-U16, U18-U21)

- tests: `corpus_runner_test.dart` (9 tests)
- red: N/A — tests written after implementation
- green: `dart test test/plugins/tdd/services/corpus_runner_test.dart` -> 9 passed, 0 failed
- refactor: fixed fake zfa argument parsing (args[2] not args[3]), fixed test assertion for outcomes.length (runner returns both done+stopped outcomes), removed debug output
- note: uses fake zfa Dart scripts as sub-process binaries to simulate run/verify outcomes
