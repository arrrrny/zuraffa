# Test — #1486: entity fields — accept unbackticked pairs; warn on
# positive-evidence-empty

- **Slug**: 1486-entity-fields-backtick-parsing
- **Suite**: `test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart`
- **Method**: bug TDD — RED first (failures captured in `red-evidence.md`),
  then GREEN, then the chunked regression sweep (no new failures).

## Behavior table

| # | Behavior | Kind | Pre-fix |
|---|---|---|---|
| B1 | A 3-column row with plain pairs parses ALL fields — the issue's exact repro (`Task`, `id/title/isCompleted/createdAt`), purpose intact | red | FAIL `[]` |
| B2 | The 2-column table (#1381 grammar) accepts plain pairs | red | FAIL `[]` |
| B3 | A mixed cell (`` `id: String`, token: String ``) parses both, in source order | red | FAIL `[id]` |
| B4 | GUARD: the backticked 3-col grammar is unchanged (names + purpose) | guard | pass |
| B5 | Generic types with top-level commas survive the plain split (`Map<String, int>`, `List<List<int>>` types verbatim) | red | FAIL `[]` |
| B6 | Nullable types parse as plain pairs (`String?`) | red | FAIL `[]` |
| B7 | Evidence-but-zero cells are REPORTED: `1id: String` (identifier shape) and `` `see the docs` `` (backtick span) yield anomalies naming entity + verbatim cell + 1-based line; no-evidence (`—`) and parsing cells yield none | red | compile red (new API) |
| B8 | GUARD: bullet prose keeps the strict backticked-only grammar — backticked pairs parse, plain prose invents NOTHING | guard | pass |
| B9 | `entityFieldNamesFromDartSource` reads the on-disk entity shape: `final`/`late final` members in; constructor params and assignment-initialised locals out | red | compile red (new API) |

Stage-2 red (B7/B9) is a compile failure against the not-yet-existing API —
captured in the transcript; stage-1 red (B1–B6) is behavioral, in
`red-evidence.md`.

## Regression surface (all run green post-fix)

- `spec_parser_test.dart`, `spec_parser_declarations_test.dart`,
  `spec_parser_hardening_1196_test.dart`, `spec_parser_traces_1319_test.dart`,
  `spec_parser_fr_manual_1484_test.dart`,
  `spec_parser_contract_files_1485_test.dart` — the parser's full corpus
  (116 tests with the #1486 suite, 0 new failures).
- `bug_1381_entity_table_2col_test.dart` + `bug_919_reader_test.dart` — the
  table grammars #1486 extends (backwards compat).
- `bug_1381_plan_warns_on_unparsed_entities_test.dart` +
  `plan_command_*` suites — the warning block #1486 extends.
- `pipeline_runner_test.dart`, `runner_*`, `step_runner`,
  `corpus_step_runner`, `suite_guard` — the run-driver surfaces the reuse
  log lives in.
- Full chunked fast-tier sweep via the repo's own
  `tools/run_tests_chunked.sh` (kernel cache purged between chunks —
  see #1507), then the identical run on a clean `master` worktree; failure
  sets must match (environmental-only deltas).
