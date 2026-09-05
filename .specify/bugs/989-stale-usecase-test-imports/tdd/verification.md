# TDD Verification — 989-stale-usecase-test-imports (#989)

- **Bug**: https://github.com/arrrrny/zuraffa/issues/989
- **Branch**: fix/989-stale-usecase-test-imports
- **Date**: 2026-09-05
- **Verdict**: PASS — the stale-import-after-#921-rejection gap is reproduced by failing tests on pre-fix code and is killed by the fix; the full fast suite is green.
- **Provenance note**: `.specify/bugs/989-stale-usecase-test-imports/issue.md` and `assessment.md` were NOT present on this branch (the task brief stated they were committed; they are not). The task brief's bug context (root cause, repro, expected behavior, hard constraints) was used as the sole issue input. `zfa tdd verify` was not dispatchable (no `.zfa.json` in the repo root → `ZFA_MISSING`), so per the speckit.tdd.verify fallback path this audit was produced by the LLM-guided process with real red/green evidence below.

## Counts

| Fact | Value |
|------|-------|
| Behaviors covered | 3 new tests (aggregate-file surgery, wholly-stale file deletion, no-rejection fail-open) |
| Red-phase proven | Yes — 2 of 3 tests failed on pre-fix code with the exact reported symptom |
| Test-after confirmed | Yes — same tests pass post-fix (3/3) |
| Existing suites re-run | full fast suite, chunked: 74/74 chunks executed — 70 OK, 4 SKIP (no fast-tier tests by design: test/benchmark, test/core/dependencies, test/integration, test/plugins/tdd/scenarios), 0 FAIL — ~2905 tests passed, 0 failed |
| Mutation gate | not_assessed (mutation_test not in scope for a CLI behavior fix; deliberate-mutant sampling below) |
| New smells introduced | none (fix is a self-contained cleaner invoked from the existing entity pipeline; no new abstractions) |

## Red phase (pre-fix evidence)

`dart test test/plugins/usecase/stale_usecase_test_imports_test.dart` on the
pre-fix tree (master @ 77e69f24 + test only, generator untouched):

```
  Expected: false
    Actual: <true>
  The import of the never-generated cancel_task_usecase.dart must be removed — the suite cannot load while it is present.

00:00 +0 -1: bug #989 — stale usecase test imports after #921 rejection deletes a wholly stale per-method usecase test file
  Expected: false
    Actual: <true>
  A test file whose only usecase import is non-existent is stale by construction and must be deleted so the suite can load.

00:00 +0 -2: Some tests failed.
```

The pre-fix pipeline ran the #921 rejection (`Skip create_task usecase:
TaskRepository has no 'create' method (issue #921)`) and left the stale test
files byte-identical: the aggregate file kept imports of
`cancel_task_usecase.dart` / `create_task_usecase.dart` (non-existent), and
the wholly-stale per-method file survived. That is the exact reported
failure: after a partial run, `dart test` dies at load on a missing use case
file and the suite never re-runs to a clean baseline.

## Fix (green phase)

- `lib/src/utils/stale_usecase_test_cleaner.dart` (new) — `StaleUsecaseTestCleaner`: when the caller reports that #921 rejected at least one use case, sweeps the project's `test/` tree for test files importing the package's own `*_usecase.dart` files that do not exist anywhere under `lib/`. For each affected file: removes the stale import directives and the `test`/`testWidgets` statements referencing the derived stale use case classes (string/comment-aware balanced-paren scanner); deletes the whole file when every use case import it has is stale (per-method test files are stale by construction) or when no executable test remains. Fails open when the package root or `pubspec.yaml` cannot be resolved, when `lib/` or `test/` do not exist, and never touches other packages' imports.
- `lib/src/plugins/usecase/generators/entity_usecase_generator.dart` — computes `rejectedMethods` (requested minus #921-effective) and invokes the cleaner after generation, only when `rejectedMethods` is non-empty and not in revert mode. **#921 rejection semantics unchanged**: the guard's filtering, its skip notices, and the generated surface are byte-for-byte the same as before; the cleaner only removes test-side debris the rejection leaves behind.

Post-fix run of the new file:

```
00:00 +2: bug #989 — ... deletes a wholly stale per-method usecase test file
  Skip toggle_task usecase: TaskRepository has no 'toggle' method (issue #921) — ...
  Deleted stale test file test/domain/usecases/task/cancel_task_usecase_test.dart: references non-existent usecase(s) cancel_task_usecase.dart (issue #921, bug #989).
00:00 +3: All tests passed!
```

Neighboring suites (rejection semantics untouched): `dart test test/plugins/usecase/` → 23/23 passed, including the three pre-existing `issue #921 — conservative repository-interface guard` tests.

## Mutation sampling (deliberate mutants)

| Mutant | Result |
|--------|--------|
| Remove the cleaner invocation entirely (= pre-fix code) | killed — red evidence above (2 tests fail with the exact load-time symptom) |
| Sweep unconditionally, dropping the rejection gate | killed — "leaves test files untouched when #921 rejects nothing" fails: the no-rejection fixture is asserted byte-identical |
| Remove only the referencing tests, keep the stale imports | killed — "removes stale imports ... while keeping the actually-existing surface" asserts `contains('cancel_task_usecase.dart')` is false |
| Delete only wholly-stale files, skip mixed-file surgery | killed — the aggregate-file test fails (stale imports must be removed while `get_task_usecase.dart` import and its test survive) |
| Treat existing use case imports as stale (no lib/ existence check) | killed — the aggregate-file test asserts `contains('get_task_usecase.dart')` is true post-run |

## Test-first evidence

The failing tests were committed to the working tree and executed BEFORE the
fix landed (see Red phase); the same tests were re-run unmodified after the
fix and pass (see green evidence). `dart analyze` on the changed tree
reports 31 errors / 20 warnings / 294 infos — byte-identical counts to
pristine master (all pre-existing, all under `examples/todo_tdd/`); the fix
introduces zero new analyzer findings. `dart format .` is clean
(`--set-exit-if-changed` exits 0).

## Hard-constraint audit

| Constraint | Status |
|------------|--------|
| Clean up stale test imports for non-existent use cases | PROVED — red→green tests above |
| Do not change the #921 rejection semantics | PROVED — `SourceInterfaceGuard` untouched; pre-existing #921 guard tests pass unmodified (23/23 in test/plugins/usecase/) |
| One PR for the bug | observed — single branch `fix/989-stale-usecase-test-imports` |
