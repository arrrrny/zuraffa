# TDD Test List — Spec 1375

Regression pin: preservation on both paths + idempotence. Red would be a
regeneration regression on master (not observed).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | gen --adopt preserves the authored bytes | FR-1 / AS-1 | test/plugins/tdd/commands/bug_1375_adopt_preserves_refined_test.dart |
| B2 | Plain gen preserves (progression guard) | FR-2 / AS-2 | test/plugins/tdd/commands/bug_1375_adopt_preserves_refined_test.dart |
| B3 | Idempotence | FR-3 / AS-3 | test/plugins/tdd/commands/bug_1375_adopt_preserves_refined_test.dart |
