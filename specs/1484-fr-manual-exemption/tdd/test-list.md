---
feature: 1484-fr-manual-exemption
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 5
planned_at: 94048e31
updated_at: 94048e31
suite_baseline: green
---

# Test List: FR manual exemption — route inherently non-unit FRs out of the unit behaviour lane

**Feature**: 1484-fr-manual-exemption
**Template**: zuraffa-1.0
**Generated**: 2026-09-11

This test list traces every testable behavior to its source criterion (acceptance criteria from the user stories / success criteria of `spec.md`). The feature is a pure-Dart CLI change (`spec_parser.dart` + `requirement_scan.dart` + `plan_command.dart`), so the loop is inside-out: no user-visible surface, every behavior is a unit-level example against the parser/gate/command.

---

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| A1 | Planning a spec with a `**Type**: manual` FR exits 0, emits no unit row for it, and records it under the traceability `manual:` section | US1-AC1, US1-AC2, SC-001, SC-003 | example | DONE | `test/plugins/tdd/commands/plan_fr_manual_1484_test.dart::explicit marker routes manual end-to-end` |
| A2 | Planning a spec with an untraced unmarked FR exits 0 with a warning naming the FR and both remedies, and no unit row | US2-AC1, US2-AC2, SC-002 | example | DONE | `test/plugins/tdd/commands/plan_fr_manual_1484_test.dart::defaulted FR warns and routes manual end-to-end` |
| A3 | Planning an all-FR-traced spec yields unit rows byte-identical to the pre-1484 derivation | US3-AC3, SC-004 | example | DONE | `test/plugins/tdd/commands/plan_fr_manual_1484_test.dart::all-traced spec backwards compat` |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/spec_parser.dart`

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U1 | `parseFrRoutings` reports each FR's id, unit id, spec line, marker flag, trace tokens and raw text from bullet and FR-table grammars | FR-001 | example | DONE | `test/plugins/tdd/services/spec_parser_fr_manual_1484_test.dart::parseFrRoutings facts` |
| U2 | An FR whose block carries `**Type**: manual` consumes its unit id but derives no unit behaviour row; the traced sibling keeps its id | FR-002 | example | DONE | `test/plugins/tdd/services/spec_parser_fr_manual_1484_test.dart::marker FR consumes id emits no row` |
| U3 | An FR with no `traces:` binding and no marker derives no row; a marker+trace contradiction routes manual (declaration outranks trace); fenced-block markers are documentation | FR-003 | example | DONE | `test/plugins/tdd/services/spec_parser_fr_manual_1484_test.dart::unbound FR defaults manual / marker outranks trace / fenced marker ignored` |
| U4 | `_extractUnit` still strips `[persistent]` tags and derives rows for traced FRs exactly as before | FR-007 | example | DONE | `test/plugins/tdd/services/spec_parser_fr_manual_1484_test.dart::traced FR unchanged with persistence tag` |

### `lib/src/plugins/tdd/services/requirement_scan.dart`

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U5 | `CoverageGate.evaluate` counts manual FR ids as covered (no gap) while unaccounted FRs still gap | FR-006 | example | DONE | `test/plugins/tdd/services/spec_parser_fr_manual_1484_test.dart::gate counts manual FRs covered` |
| U6 | `TraceabilityMatrix.render` marks manual FRs `manual` in the main table, renders the `## manual:` section with full text + tag, and counts them in the machine block | FR-005 | example | DONE | `test/plugins/tdd/services/spec_parser_fr_manual_1484_test.dart::matrix renders manual section and counts` |

### `lib/src/plugins/tdd/commands/plan_command.dart`

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U7 | Plan warns for every defaulted FR naming the FR and the two remedies, and warns nothing for explicitly-marked FRs | FR-004 | example | DONE | `test/plugins/tdd/commands/plan_fr_manual_1484_test.dart::warning names FR and remedies; explicit marker silent` |
| U8 | Plan writes the manual declarations into `tdd/traceability.md` and the test list contains no row for manual FRs (`zfa tdd run` untouched — it only sees plan'd rows) | FR-005, FR-008 | example | DONE | `test/plugins/tdd/commands/plan_fr_manual_1484_test.dart::traceability artifact carries manual declarations` |

## Invariants and edge cases still to place

- FR-table row (`\| FR-001 \| ... \|`) with a `**Type**: manual` continuation line routes manual — placed in U1/U3.
- `traces:` line whose tokens all drop (signatures) binds nothing → defaulted manual + #1319 warning — placed in U3 (tokens empty ⇒ unbound).
