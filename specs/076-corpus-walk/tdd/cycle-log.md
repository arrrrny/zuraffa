# TDD Cycle Log — 076-corpus-walk

## Loop profile

outside-in; acceptance behaviors (the CLI surface) first, unit
behaviors proven inside the same command-level tests. All tests drive
the real entry point (`CliRunner.runCapturing`) — the command surface
is the contract.

## RED — 2026-09-05

Tests written first against the not-yet-existing commands:

```
dart test test/commands/corpus_catalog_command_test.dart \
          test/commands/corpus_run_walk_command_test.dart \
          test/commands/corpus_ledger_command_test.dart
```

**+0 passed / -43 failed** — every failure the same shape: the corpus
family only knows `import` (`zfa corpus catalog --project …` ->
`Could not find an option named "--project"`; the catalog/run/ledger
subcommands do not exist; no committed catalog/ledger artifacts; no
CORE/SKIN classification anywhere in the repo).

RED evidence for the epic's step-2 (reproduce): before this feature —
no corpus walk command, no ledger, no CORE/SKIN classification.

## GREEN — 2026-09-05

Implementation (one service per contract, following the corpus-import
layering):

- `lib/src/cli/services/corpus_catalog.dart` — the catalog model,
  deterministic CORE/SKIN classifier, committed-catalog store,
  preservation of manual edits (#1015)
- `lib/src/cli/services/corpus_walker.dart` — the walker (green/
  partial/blocked) over the spec 051 spawn contract, failure-budget
  parsing (#1016)
- `lib/src/cli/services/corpus_walk_ledger.dart` — the committed
  ledger, the diff (regression/renewed/added/removed), the gate (#1017)
- `lib/src/commands/corpus_command.dart` — `catalog` / `run` / `ledger`
  subcommands registered beside `import`
- `test/commands/helpers/corpus_walk_fixture.dart` — the shared fixture

After implementation: **43 passed / 0 failed** (13 catalog + 16 run +
14 ledger). Existing corpus family tests re-run green (16/16 import +
4/4 setup) — no regressions in the modified `corpus` command family.

## Defects caught by the red tests (honesty log)

| # | Defect caught by a red test | Fix |
|---|---|---|
| 1 | `corpus run`/`ledger` caught `CorpusCatalogException` but `requireCatalog` throws `CorpusWalkException` — the misfire escaped to the generic handler, printed `❌ Error:` and left exitCode 0 (the guidance test caught it: expected 2, actual 0) | Catch both exception types in both commands |
| 2 | An empty manifest errored inside the CATALOG, so the walk's "empty catalog" misfire was unreachable — the A6 test expected the walk-level refusal (`no features`) | The manifest path writes an empty catalog; the walk (run/ledger) refuses an empty catalog with exit 2 |
| 3 | The walker recorded the CATALOG's stale spec hash instead of hashing the spec at walk time — a spec that evolved between cataloging and walking produced no diff (the renewal test caught it: expected `renewed`, got a silent `clean`) | The walker hashes `specs/<f>/spec.md` at WALK TIME (renewal/drift detection is the ledger's currency) |

## REFACTOR

None required — the three services are already one-contract-per-file;
the command layer stays thin (arg surface + outcome mapping), the same
layering the corpus importer established.
