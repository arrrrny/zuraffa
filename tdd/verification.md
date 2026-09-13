# tdd.verify — Bug #1486 entity fields silently dropped without backticks

- **Verified**: 2026-09-13, this session, on
  `fix/1486-entity-fields-backtick-parsing` (working tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64 (container; no Flutter
  SDK — flutter-tagged suites are excluded per the repo's own chunked
  runner policy)
- **Scope**: the three changed source files + the new bug suite, then the
  chunked fast-tier sweep below

## Verdict: PASS

## 0. RED evidence (pre-fix, real runs)

Stage 1 — behavioral red, `bug_1486_entity_fields_backtick_parsing_test.dart`
against the untouched tree (full output in
`.specify/bugs/1486-entity-fields-backtick-parsing/red-evidence.md`):

```
00:00 +2 -5: Some tests failed.
Failing tests:
  ...: B1: a 3-column row with plain pairs parses all fields (#1486)
  ...: B2: the 2-column table accepts plain pairs (#1486 + #1381)
  ...: B3: a mixed cell parses backticked and plain pairs in order
  ...: B5: generic types with commas survive the plain-pair split
  ...: B6: nullable types parse as plain pairs
```

Actuals matched the issue's controlled experiment exactly: plain pairs
yield `SpecEntity.fields == []`; the backticked guards (B4/B8) passed
(backwards-compat baseline intact).

Stage 2 — API red: adding B7 (anomalies) + B9
(`entityFieldNamesFromDartSource`) failed to compile against the pre-fix
parser, as expected:

```
Error: 'SpecEntityFieldAnomaly' isn't a type.
Error: Member not found: 'SpecParser.entityFieldNamesFromDartSource'.
Error: No named parameter with the name 'anomalies'.
```

## 1. Static analysis (post-fix, post-format)

```
dart analyze lib/src/plugins/tdd/services/spec_parser.dart \
             lib/src/plugins/tdd/commands/plan_command.dart \
             lib/src/plugins/tdd/commands/run_driver_core.dart \
             test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart
→ No issues found!
```

## 2. The bug suite + regression surface (REAL runs in this session)

```
dart test test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart
→ 00:00 +9: All tests passed!

Parser corpus (spec_parser, declarations, hardening_1196, traces_1319,
fr_manual_1484, contract_files_1485, bug_1381, bug_919, bug_1486):
→ 00:01 +116: All tests passed!

Mapped command suites (bug_1381_plan_warns_on_unparsed_entities,
plan_command_bug_1182/1481/contracts_1485/pipe_escape_1401/ffi_835,
pipeline_runner, runner_plain_name_regression, runner_regex_escape):
→ 00:18 +46: All tests passed!
```

The #1381 plan-warning suite passes unchanged — its fixture produces no
#1486 anomalies (its pairs parse), so the new warning is correctly silent
there.

## 3. Chunked regression sweep — NO NEW failures

The repo's sanctioned `tools/run_tests_chunked.sh` policy was followed
(fast tier, `--exclude-tags flutter`, kernel cache purged between chunks —
`dart_test.yaml` documents the ~6.5 GB single-invocation kernel cache and
`.specify/bugs/1507-tmpdir-kernel-cache-leak` documents the per-process
`$TMPDIR/dart_test.kernel.*` leak that both ENOSPC'd this container until
the purge cadence was applied). Per-chunk results:

- 105 chunks from the runner's own DRY_RUN list: **97 OK, 5 SKIP**
  (`SKIP(no-fast-tier)` — benchmark/core-proof/integration/tdd-scenarios/
  077-make-engine-preset carry only slow-tier tags, excluded by design),
  **0 FAIL**.
- The runner's threshold-40 recursion skips ROOT test files of heavy dirs;
  those were run explicitly with identical semantics and all passed:
  `test/plugins/tdd/*_test.dart` (519 tests), `tdd/commands` a–z splits
  (533 tests), `tdd/services` a–z splits (1171 tests).

## 4. Host/environment caveats (recorded honestly)

- No Flutter SDK in this container: flutter-tagged suites are excluded by
  the sanctioned runner itself (`--exclude-tags flutter`), so their status
  is unchanged-by-construction (none touch `spec_parser.dart` field
  parsing; the two command files changed are pure-Dart paths).
- `dart format` ran over the four changed files (3 reformatted — the new
  suite file plus whitespace); `dart analyze` re-run clean afterwards.
- `dart test` kernel-cache purge cadence (per chunk) was required: the
  container disk is 9.9 GB and a single whole-tree invocation ENOSPCs
  (matches the dart_test.yaml header's warning and #1507).

## 5. Constraint audit

- Parsing semantics live entirely in `spec_parser.dart`; the state
  machine, gen, and loop semantics are untouched.
- The two consumers are print-only: plan's per-row WARNING and phase-0's
  reuse mismatch log (reuse decisions byte-for-byte unchanged).
- Backticked grammar unchanged: guard B4 + the full #919/#1381/#1196/
  #1319/#1484/#1485 suites green.
