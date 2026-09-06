# TDD Cycle Log: pr-1210-ci-red

Engine: manual red-green-refactor (zfa tdd cannot address `.specify/bugs/`
dirs — see test-list.md engine note). Runner per `.specify/memory/tdd-profile.md`.

## Baseline — 2026-09-06

- Commit: 350e2d8e (fix/pr-1210-ci-red branched from master)
- Upstream RED evidence: master CI run 34027280435 — `dart_core` failure,
  5381 passed / 3 failed, all three in
  `test/regression/issue_891_example_meta_resolution_test.dart`.

## Cycle 1 — RED → GREEN (A1, A2, A3)

**RED** — `dart test test/regression/issue_891_example_meta_resolution_test.dart`

Pre-fix file on the current tree (override absent since #1206):

```
00:00 +0 -1: example package declares a meta dependency_override (issue #891) [E]
  Expected: <Instance of 'Map'> Actual: <null>
00:00 +0 -2: the meta override floor covers analyzer ≥13.1.0 (meta ^1.18.3) [E]
  type 'Null' is not a subtype of type 'Map<dynamic, dynamic>' in type cast
00:00 +0 -3: the meta override is a VERSION override, not a path: override [E]
  type 'Null' is not a subtype of type 'Map<dynamic, dynamic>' in type cast
00:00 +1 -3: Some tests failed.
```

Fails for the right reason: the old contract demands the override #1206
removed. Matches master CI run 34027280435 exactly.

**GREEN** — rewrote `test/regression/issue_891_example_meta_resolution_test.dart`
to the flipped contract (A1 file exists / A2 zero dependency_overrides / A3
delegation target `tools/flutter_smoke_gate.sh` present and covering example/):

```
00:00 +3: All tests passed!
```

**Refactor** — no further churn: the rewrite dropped the now-dead
`_versionFloor` helper and moved the #891 → #1189 → #1206 history into the
doc comment while green. Post-format re-run: `+3: All tests passed!`
`dart format` applied (1 file), `dart analyze` clean.

## Verdict

- A1, A2, A3: DONE (red → green evidence above)
- AC-4 (history in doc comment): satisfied in the rewrite, review-level

