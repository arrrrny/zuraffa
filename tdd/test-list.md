# TDD test list — Bug #1486 Key Entities fields silently dropped without backticks

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1486-b1 | test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart | unit | a 3-column row with plain pairs parses ALL fields — the issue's exact repro (`Task`, `id/title/isCompleted/createdAt`), purpose intact | FR-1486, SpecParser.parseKeyEntities, _parseFieldCell | GREEN (RED pre-fix) |
| A-1486-b2 | test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart | unit | the 2-column table (#1381 grammar) accepts plain pairs | FR-1486, SpecParser._parseFieldCell | GREEN (RED pre-fix) |
| A-1486-b3 | test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart | unit | a mixed cell (backticked + plain) parses both, in source order | FR-1486, SpecParser._parseFieldCell | GREEN (RED pre-fix) |
| A-1486-b4 | test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart | unit | GUARD: the backticked 3-col grammar is unchanged (names + purpose) | FR-1486, backwards compat | GREEN |
| A-1486-b5 | test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart | unit | generic types with top-level commas survive the plain split (`Map<String, int>`, `List<List<int>>` verbatim) | FR-1486, depth-aware comma split | GREEN (RED pre-fix) |
| A-1486-b6 | test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart | unit | nullable types parse as plain pairs (`String?`) | FR-1486, SpecParser._parseFieldCell | GREEN (RED pre-fix) |
| A-1486-b7 | test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart | unit | evidence-but-zero cells are REPORTED, never silent: `1id: String` and a prose backtick span yield anomalies (entity, verbatim cell, 1-based line); no-evidence and parsing cells yield none | FR-1486, SpecEntityFieldAnomaly | GREEN (compile-red pre-fix) |
| A-1486-b8 | test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart | unit | GUARD: bullet prose keeps the strict backticked-only grammar — plain prose invents NOTHING | FR-1486, false-positive guard | GREEN |
| A-1486-b9 | test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart | unit | `entityFieldNamesFromDartSource` reads the on-disk entity shape (final/late final in; constructor params and assignment-initialised locals out) | FR-1486, phase-0 reuse mismatch | GREEN (compile-red pre-fix) |

Signal paths (print-only, exercised by the suites above + the #1381 plan suite):

- plan: `SpecEntityFieldAnomaly` rows → per-row `zfa tdd plan: WARNING` (#1486 sibling of #1381's zero-entity warning) — plan_command.dart
- run: phase-0 reuse branch logs declared-vs-on-disk field mismatch — run_driver_core.dart `_logPhaseZeroFieldMismatch`
