# TDD Verification — Bone Working Slice (feature 042)

**Date**: 2026-08-29
**Suite baseline**: `dart test test/plugins/skeleton/` (feature scope) + full-repo chunked run
**Result**: feature scope **140 tests pass, 0 fail** (baseline before this feature: 57 tests).
Full repository: **2701 tests pass, 0 code failures** (one `-1` in `test/commands` under `-j 4`
was the repo's documented parallel CWD-cascade flake, issue #506; serial `-j 1` rerun of that
scope passes +235 — pre-existing infra flake, unrelated to this change). Five scopes
(`benchmark`, `fixtures`, `helpers`, `integration`, `property`) run zero tests under the
default tag selectors (`exclude_tags: slow`) — by design, not failures.

## Red → green evidence (042 cycle)

- **Red** (tests written first against the not-yet-existing 042 APIs):
  `dart test test/plugins/skeleton/` → **+28 passed / -22 failed**, with 92 compile errors on
  the new symbols (`DiChoice`, `EntityField.nullable`, slice builders, `--di/--flutter/
  --include-deps/--export`, pubspec-aware validate, field parsing). Every 042 behavior was red
  before implementation; the 28 green were the untouched 020 behaviors.
- **Green**: after implementation, the same scope runs **+140 / -0**. Intermediate defects
  found and fixed by the red tests are recorded below (honesty log):

| # | Defect caught by a red test | Fix |
|---|---|---|
| 1 | Nullability syntax: fixture wrote `email: String?`, parser only accepted `email?: String` | Support both forms |
| 2 | Mock/firebase datasources did not import their sibling interface file | Add sibling import |
| 3 | `user.fromJson(...)` — camel used for a type constructor | Use Pascal entity |
| 4 | `services.updateuser` — verb+camel produced wrong getter names | verb+Pascal (`updateUser`) |
| 5 | Delete use case carried an unused entity import (analyze warning) | Skip import for delete |
| 6 | DI choice/flutter duplicated on `Bone` and `BoneManifest` (drift → missing `di/`) | Manifest = single source of truth |
| 7 | Firestore URI lost the `/` between `(default)` and `documents` | Fixed adjacent literals |
| 8 | Flutter import lines inside generator templates tripped the issue-495 core-purity regression | Emit via string constants (repo convention) |
| 9 | `'$scratch/…'` interpolated `Directory.toString()` (garbage path) in the analyze helper | Use `scratch.path` |

## 1. Coverage

Every implemented unit has at least one passing test: models (`bone_models_test`), spec reader
field parsing (7 cases incl. both nullability syntaxes), entity builder (7), repository /
usecase / datasource / injection / app-entry / presentation builders (18), di resolver (5),
manifest builder (4 new + 7 legacy), bone command flags & validate (6 new + 12 legacy),
bone generator (3 new + 7 legacy), scaffold builder (4 rewritten), and the end-to-end
scenario `sc_005` (28 acceptance behaviors A1–A28). Coverage tooling not invoked (the repo's
tdd-profile declares coverage opt-in); test mapping is complete, but coverage is unmeasured.

## 2. Mutation

No mutation audit was run in this PR. Precedent: feature 041 wired `mutation_test` scoped to
its own files; running it here against the full skeleton scope would require per-file test
commands and kernel-cleanup plumbing that this PR does not add (sandbox disk constraints made
per-mutant full-scope runs infeasible during verification). **Honest gap**: test strength for
042 is evidenced by the red→green cycle above, not by mutation scoring. Follow-up: scope a
`mutation-test.xml` section for `lib/src/plugins/skeleton/**` in a dedicated chore.

## 3. Success criteria — PROVED vs not (issue #592)

| Criterion | Status | Evidence |
|---|---|---|
| SC-001 `--flutter --di mock` bone contains a Flutter app module (runnability unmeasured) | **PARTLY PROVED (structure + pure-Dart core)** | A10–A13, A1–A3 structurally verify pubspec + lib/main.dart + presentation page + widget test + entities/domain/data/DI/tests for exactly one feature. The Flutter module was not executed or analyzed because no Flutter SDK was available. |
| SC-002 Bone compiles / analyzes with zero errors | **PROVED for the pure-Dart core; NOT PROVED for flutter-mode widget files** | A25 executes `dart analyze` on a scratch package containing entities/domain/data/di/tests → "No issues found". `flutter analyze` was **not** run — no Flutter SDK in this environment; widget files are verified by content assertions only |
| SC-003 Mock bones work without external services | **PROVED** | A22 runs each generated test with `dart <file>` — no `pub get`, no network, zero package deps — all exit 0 (`user test: PASS`, `post test: PASS`, `di test: PASS`) |
| SC-004 Firebase bones work with real Firebase credentials | **PARTLY PROVED** | Generated code + wiring + credential plumbing proven (A6, U22–U24, and A24's runtime StateError check inside `di_test`). A **live Firestore round-trip was NOT executed** (no credentials/network in CI) |
| SC-005 Bone < 50KB compressed | **PROVED** | A23 asserts the tar.gz is < 50 KB (actual ≈ 6–8 KB for the two-entity profile fixture) |
| SC-006 Multiple bones without conflicts | **PROVED** | A20: two features generated + exported into the same bones dir; A28: atomic regeneration |

## 4. Verification commands and actual results

```bash
dart analyze lib/src/plugins/skeleton test/plugins/skeleton   # No issues found!
dart test test/plugins/skeleton/                              # +140: All tests passed!
dart format .                                                 # 0 changed (second run)
# full repo (chunked, kernel-cleanup between scopes):
#   49 scopes "All tests passed", 2701 tests, 0 code failures
```

Repo-wide `dart analyze` retains 100+ pre-existing error-level findings in `examples/**` and
`zikzak_session/**` (nested packages that need their own `pub get`) — present on `master`
before this branch, untouched by this feature.
