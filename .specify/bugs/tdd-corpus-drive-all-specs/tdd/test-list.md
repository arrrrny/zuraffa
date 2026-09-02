# Test list — tdd-corpus-drive-all-specs (#836)

Canonical 4-column rows; ids match the groups in
`test/plugins/tdd/commands/corpus_run_plan_test.dart`.

## Inner loop:

| B-001 | --plan orders dependent manifest features after their declared dependencies (markdown rewrite-plan, → and -> edges) | FR-836-1 | DONE |
| B-002 | independent features keep manifest order under the stable topological sort; a no-edge plan is a valid no-op | FR-836-1 | DONE |
| B-003 | a TUPEC inventory.json plan orders by its dependencies (id→name mapping) | FR-836-1 | DONE |
| B-004 | a plan edge naming an unknown feature stops honestly (exit 2) with nothing driven | FR-836-1 | DONE |
| B-005 | a dependency cycle stops honestly (exit 2) with nothing driven | FR-836-1 | DONE |
| B-006 | a missing plan file stops honestly (exit 2) with nothing driven | FR-836-1 | DONE |
| B-007 | the machine summary carries order=topological in plan mode (machine contract preserved) | FR-836-1 | DONE |
| B-008 | resume with --plan: done features are never re-driven and the remaining order stays topological (resume token) | FR-836-1 | DONE |

## Inner loop (provenance):

| B-009 | a done feature's progress records the sha256 of its specs/<f>/spec.md | FR-836-2 | DONE |
| B-010 | spec drift on a done feature stops the next run with exit 3 BEFORE driving anything (evidence binds to intent) | FR-836-2 | DONE |
| B-011 | pre-#836 progress rows without a recorded hash never false-positive drift | FR-836-2 | DONE |

## Inner loop (gap ledger):

| B-012 | a declared criterion with no behavior lands in the gap ledger (step=plan, outcome=missing_behavior, expected_result=behavior) | FR-836-3 | DONE |
| B-013 | a covered criterion is never ledgered | FR-836-3 | DONE |
| B-014 | plan gaps do not duplicate across resume runs (append-only dedupe) | FR-836-3 | DONE |
| B-015 | a criterion becoming covered resolves the open plan gap as a NEW resolution entry (never an edit) | FR-836-3 | DONE |
| B-016 | the machine summary counts plan gaps in gaps= | FR-836-3 | DONE |

## Inner loop (composition + regression):

| B-017 | a feature composing another feature's subject never drives before its composed dependency (cross-feature ordering, #827 namespacing) | FR-836-4 | DONE |
| B-018 | without --plan the manifest-order contract (051 FR-001) is byte-for-byte unchanged; no order= token in the summary | FR-836-5 | DONE |
