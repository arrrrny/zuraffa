# Bug Fix: Published package 6.2.0/6.2.1 broken — anchor .pubignore benchmark/ to root; add publish-time export guard

- **Slug**: 1307-pubignore-benchmark-exclusion
- **Fixed**: 2026-09-08T13:05:00Z
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/verification.md

## Summary

Root-anchored the 8 dev-only directory patterns in `.pubignore` (gitignore
any-depth semantics made unanchored `benchmark/` exclude
`lib/src/core/benchmark/` and `lib/src/plugins/benchmark/` from the published
tarball while `lib/zuraffa.dart` still exported `src/core/benchmark/*`), and
added a publish-time export guard test that rebuilds the would-publish file
set from `.pubignore` and asserts every `export`/`part` target under
published `lib/**` resolves inside it.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `.pubignore` | modified | anchored `benchmark/`, `benchmarks/`, `coverage/`, `.worktrees/`, `specs/`, `contracts/`, `apps/`, `build/` → `/…/`; in-file comment records why (bug 1307) |
| `test/pubignore_export_guard_test.dart` | added test | publish-time export guard: B1 export targets ⊆ publish set, B2 regression wall (core/benchmark in, top-level harness out), B3 hygiene (no unanchored dir patterns) |
| `.specify/bugs/1307-pubignore-benchmark-exclusion/*` | bug records | issue.md, assessment.md, spec.md, fix.md, test.md, pr-body.md, tdd/* |

No changes to `lib/zuraffa.dart`, the publish process, or any other file
(hard constraints honored).

## Diff Highlights

```diff
-# Benchmark
-benchmark/
-benchmarks/
+# Benchmark
+/benchmark/
+/benchmarks/
```

Same anchoring applied to `coverage/`, `.worktrees/`, `specs/`, `contracts/`,
`apps/`, `build/`. `lib/tdd/`, `test/fixtures/`, `example/pubspec.lock`,
`examples/*/pubspec.lock`, `.zuraffa/plans/` were already root-anchored
(middle slash) and `.env` is intentionally any-depth — all kept as-is.

## Tests Added or Updated

- `test/pubignore_export_guard_test.dart::export guard` (B1/AC-1) — every
  `export`/`part` target in published `lib/**` must exist in the
  would-publish set; proven RED with exactly the 8 bug-1307 targets before
  the fix.
- `test/pubignore_export_guard_test.dart::would-publish set` (B2/AC-2) —
  `lib/src/core/benchmark/*.dart` included, `lib/src/plugins/benchmark/`
  included, top-level `benchmark/` harness excluded.
- `test/pubignore_export_guard_test.dart::.pubignore hygiene` (B3/AC-3) —
  rejects any future unanchored directory pattern (RED listed all 8
  pre-fix hazards).

## Local Verification

- Commands run:
  - `dart test test/pubignore_export_guard_test.dart` → RED 0/3 (pre-fix,
    exact 1307 targets) → GREEN 3/3 (post-fix).
  - `dart pub publish --dry-run` → tarball tree now contains
    `lib/src/core/benchmark/` and `lib/src/plugins/benchmark/`; 4 warnings +
    1 hint, all pre-existing layout advisories unrelated to 1307.
  - `dart analyze test/pubignore_export_guard_test.dart` → No issues found.
  - `dart format` (file-scoped check) → 0 changed.
  - Deliberate mutant sampling → unanchored-`benchmark/` mutant killed
    (suite RED), restore → GREEN.
- Manual checks: sibling-pattern audit — `find lib bin tool -type d` for
  every unanchored name; only `benchmark` hits
  (`lib/src/core/benchmark`, `lib/src/plugins/benchmark`).

## Deviations from Assessment

None in substance. Two test-harness refinements during the RED phase, both
recorded in `tdd/cycle-log.md`: the `FileSystemEntity.name` →
`p.basename(...)` compile fix, and skipping `$`-interpolated URIs
(code-generation template text, not real directives).

## Follow-ups

- Maintainer: republish 6.2.2 after merge so pub.dev serves the corrected
  tarball (out of scope for this PR per the bug record's hard constraints).
- The 3 unrelated pre-existing formatting-drift files surfaced by a repo-wide
  `dart format` (fixture/template text under `.specify/bugs/1256-*` and a
  zfa-generated project fixture) were left untouched to keep this PR minimal.
