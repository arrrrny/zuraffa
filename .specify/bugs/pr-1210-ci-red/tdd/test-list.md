# TDD Test List: issue_891 regression test must assert the post-#1206 zero-overrides contract

**Feature**: pr-1210-ci-red (bug dir — issue [#1211](https://github.com/arrrrny/zuraffa/issues/1211))
**Generated**: 2026-09-06
**Planned at commit**: 350e2d8e
**Mode**: outer-only (no plan.md exists)
**Engine note**: derived via the LLM-guided fallback — `.zfa.json` absent and
`zfa tdd plan` resolves features only under `specs/`, which cannot address a
`.specify/bugs/<slug>/` directory. Runner commands come from
`.specify/memory/tdd-profile.md`.

## Test List Format
- **Behavior ID**: Unique identifier (A1, A2... for acceptance; U1, U2... for unit)
- **Type**: acceptance | unit | integration | property
- **Source**: spec.md section or plan.md component
- **Status**: DONE | DONE | BLOCKED
- **Test Name**: Exact test name as it appears in test files
- **Test Path**: File path relative to repo root
- **Notes**: Any relevant context

---

## Acceptance Behaviors (from spec.md)

| ID | Type | Source | Status | Test Name | Test Path | Notes |
|---|---|---|---|---|---|---|
| A1 | acceptance | AC-1, AC-2 | DONE | example/pubspec.yaml exists (the file-shape guard needs it) | test/regression/issue_891_example_meta_resolution_test.dart | Retained from old test 1's first assertion |
| A2 | acceptance | AC-2, AC-5 | DONE | example/pubspec.yaml carries ZERO dependency_overrides (issue #891 contract flipped by #1206) | test/regression/issue_891_example_meta_resolution_test.dart | Flips old tests 1–3 (override REQUIRED → FORBIDDEN). Subsumes the path-override prohibition: no section → nothing can override via path:. |
| A3 | acceptance | AC-3 | DONE | the zero-overrides resolution proof is delegated to tools/flutter_smoke_gate.sh | test/regression/issue_891_example_meta_resolution_test.dart | Replaces old test 4's analyzer-floor heuristic; pins that the delegated #1206 proof is present |

## Non-asserted constraints (review-level)

| Source | Constraint | How verified |
|---|---|---|
| AC-4 | Doc comment preserves the #891 → #1189 → #1206 history (why the override existed, why it was dropped) | Code review of the rewritten file |

---

## Notes

- **RED state is already proven upstream**: master CI run 34027280435 (5381
  passed / 3 failed) shows old tests 1–3 red on the current tree. The loop
  re-proves it locally before rewriting.
- No `tasks.md` exists in a bug dir — the tasks.md sync step is a no-op here;
  the single implementation task is the rewrite itself, driven by the loop.
