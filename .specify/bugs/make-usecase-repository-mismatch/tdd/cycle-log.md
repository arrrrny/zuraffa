# TDD Cycle Log: zfa make Task usecase/repository interface mismatch (bug #921)

- **Slug**: make-usecase-repository-mismatch
- **Date**: 2026-09-03
- **Branch**: fix/921-make-usecase-repository-mismatch
- **Baseline**: master @ 31b3ad62

All commands and outputs below were executed and observed in this session.
Environment: Dart SDK 3.13.1 (stable, CI-pinned), Linux x64.

## R-1 — Product-level red (reproduction of the issue, pre-fix binary)

Compiled the CLI from unmodified master and reproduced the issue's exact
scenario in a disposable sandbox (`zfa setup task_demo2 --dart`, plugins
usecase/repository/datasource enabled, `zfa entity create -n Task --field
id:String --field title:String --field completed:bool`).

Step 1 — repository generated with a CRUD-only method set (the "prior run"):

```text
$ zfa make Task --methods=get,getList,create,update,delete
✅ Generation complete:
  ✨ lib/src/domain/usecases/task/get_task_usecase.dart
  ✨ lib/src/domain/usecases/task/get_task_list_usecase.dart
  ✨ lib/src/domain/usecases/task/create_task_usecase.dart
  ✨ lib/src/domain/usecases/task/update_task_usecase.dart
  ✨ lib/src/domain/usecases/task/delete_task_usecase.dart
  ✨ lib/src/domain/repositories/task_repository.dart
  ...
```

The generated interface (matches the issue verbatim):

```text
  Future<Task> get(QueryParams<Task> params);
  Future<List<Task>> getList(ListQueryParams<Task> params);
  Future<Task> create(Task task);
  Future<Task> update(UpdateParams<String, TaskPatch> params);
  Future<void> delete(DeleteParams<String> params);
```

Step 2 — usecase regeneration with the default set (get, update, **toggle**)
against that repository, pre-fix binary:

```text
$ zfa make Task usecase
✅ Generation complete:
  ✨ Created: 1 files
  ✨ lib/src/domain/usecases/task/toggle_task_usecase.dart
```

Step 3 — the compile error, identical to the one reported in the issue:

```text
$ dart analyze
  error - lib/src/domain/usecases/task/toggle_task_usecase.dart:20:24
    - The method 'toggle' isn't defined for the type 'TaskRepository'. ...
    - undefined_method
analyze exit: 3
```

Generated call site (pre-fix):

```dart
return _repository.toggle(params);   // toggle_task_usecase.dart:20
```

## R-2 — Unit-level red (regression test vs unmodified source)

With the fix stashed (`git stash push lib/.../entity_usecase_generator.dart`
+ guard file removed) and the three new tests in
`test/plugins/usecase/entity_usecase_generator_test.dart`:

```text
$ dart test test/plugins/usecase/entity_usecase_generator_test.dart
  test/plugins/usecase/entity_usecase_generator_test.dart: issue #921 —
  conservative repository-interface guard skips usecases whose method is
  missing from the existing repository
  ... Some tests failed.
```

The 'skips usecases whose method is missing from the existing repository'
test failed on baseline because the baseline generator emitted
`toggle_task_usecase.dart` against a repository interface that does not
declare `toggle` — the exact defect.

## G-1 — Green (fix applied)

Unit level (fix restored, 5 tests = 2 pre-existing + 3 new):

```text
$ dart test test/plugins/usecase/entity_usecase_generator_test.dart
00:00 +5: All tests passed!
```

Product level, same sequence as R-1 with the fixed binary:

```text
$ zfa make Task usecase
  Skip toggle_task usecase: TaskRepository has no 'toggle' method
  (issue #921) — pass --methods to control the usecase set, or add
  'toggle' to TaskRepository.
✅ Generation complete:
  ⏭ Skipped: 6 files
✅ Done.
```

No `toggle_task_usecase.dart` was created. Build gate:

```text
$ zfa build
🔎 Running dart analyze on lib/...
Analyzing lib...
No issues found!
   ✅ dart analyze: no errors
zfa build exit: 0
```

Fail-open and same-run paths (behavior preservation):

```text
$ zfa make Task            # fresh project, repository in the same plan
  → repository created with get/update/toggle; all 3 usecases generated; analyze 0 errors
$ zfa make Task usecase    # no repository file on disk
  → all 3 default usecases generated (guard fails open), unchanged behavior
```

## M-1 — Deliberate mutants (rubric: no mutation tool → targeted mutants)

Two mutants applied to `lib/src/utils/source_interface_guard.dart`, one at a
time, each restored byte-identical afterwards (`diff -q` verified) and the
suite re-run green.

Mutant 1 — filtering dropped (guard returns the method set unchanged):

```text
--- MUTANT 1 (filtering dropped) verdict:
00:00 +4 -1: Some tests failed.
```

Killed by: 'skips usecases whose method is missing from the existing
repository'.

Mutant 2 — fail-closed over-filter (guard returns [] when the interface
exists):

```text
--- MUTANT 2 (fail-closed over-filter) verdict:
00:00 +3 -2: Some tests failed.
```

Killed by: 'generates usecases for methods that exist on the repository
interface' AND 'fails open when the repository interface does not exist'.

Restore verification:

```text
diff -q /tmp/guard_original.dart lib/src/utils/source_interface_guard.dart
→ IDENTICAL
00:00 +5: All tests passed!
```
