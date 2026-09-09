# TDD Test List: Standalone Zero-Artifact Honesty

**Feature**: specs/1334-standalone-zero-artifact-honesty · **Created**: 2026-09-09

Every behavior below is written as a failing test BEFORE its implementation task runs. Behaviors map to spec User Stories (US) and Success Criteria (SC).

| # | Behavior | Test | Level | Task | Status |
|---|----------|------|-------|------|--------|
| B1 | US1/SC-1 — `zfa test create Product` (missing UseCase source) exits non-zero, prints `❌` + `--> fix:`, never `✅ Success!` | test/regression/issue_1385_1386_zero_artifact_honesty_test.dart | CLI (process exit + stdout) | T001→T007 | green |
| B2 | US1/SC-3 — overwrite-conflict-only `test create` run keeps benign exit 0 | (structural: gate fires only on missing-dependency skips; pinned via dry-run pins) | capability-level | T003→T007 | green (structural) |
| B3 | US1/SC-3 — `zfa test create Product --dry-run` (missing deps) exits 0 (preview exempt) | test/regression/issue_1385_1386_zero_artifact_honesty_test.dart | CLI | T003→T007 | green |
| B4 | US2/SC-2 — `zfa api Product` (no UseCases) exits non-zero + `❌ Failed to generate API bridge` | test/regression/issue_1385_1386_zero_artifact_honesty_test.dart | CLI (process exit + stdout) | T002→T008 | green |
| B5 | US2/SC-2 — `zfa api Product --dry-run` exits 0 | test/regression/issue_1385_1386_zero_artifact_honesty_test.dart | CLI | T003→T008 | green |
| B6 | US3 — verdict truth table on structured skipReason (missing-dep → fail; overwrite-only → pass; artifact-bearing → certification-only) | implementation predicate + B1–B5 CLI evidence | capability | T007 | green |

## Red-green discipline

- B1–B6 are committed and run BEFORE T004–T008; red output captured in tdd/verification.md.
- No implementation line lands while a red test for it remains unwritten.
- Green requires ALL of: the new tests pass AND the existing fast-tier suites for the touched verbs stay green.
