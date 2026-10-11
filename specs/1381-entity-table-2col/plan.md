# Plan — Spec 1381 entity table 2-column grammar

**Branch**: `1381-entity-table-2col` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`spec_parser.dart`: add `_entityTableHeader2Col` + `_entityTableRow2Col`;
`parseKeyEntities` tracks the table's column count and parses rows with
the matching regex (purpose empty for 2-column rows).
`plan_command.dart`: after `parseKeyEntities`, warn (stdout, issue-
referenced) when entities is empty AND the spec declares a
`## Key Entities` heading — the silent loss becomes visible.

## Test strategy

Unit: `bug_1381_entity_table_2col_test.dart` (B1 2-col extraction, B2
3-col guard). Plan-level: `bug_1381_plan_warns_on_unparsed_entities_test.dart`
(a 1-column table no grammar accepts → the warning). Scoped pin:
spec_parser suite + analyze.
