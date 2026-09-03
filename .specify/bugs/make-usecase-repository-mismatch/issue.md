# Bug Issue: fix(zfa make) — Task entity generation produces usecases that call methods not on TaskRepository

> NOTE: This record was materialized verbatim from GitHub issue #921 (fetched 2026-09-03 via API)
> because the expected pre-committed copy under `.specify/bugs/` was absent on `master` (31b3ad62).

- **Slug**: make-usecase-repository-mismatch
- **Fetched**: 2026-09-03
- **Issue**: 921
- **URL**: https://github.com/arrrrny/zuraffa/issues/921
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

### Summary

`zfa make Task` generates use case files that call methods not declared on `TaskRepository`. The compile error stops the build step, and the new use cases (`toggle_task_usecase.dart`, `update_task_usecase.dart`, etc.) reference `repository.toggle(params)`, `repository.claim(params)`, `repository.complete(params)`, etc. — none of which exist on the auto-generated `TaskRepository` interface.

### Reproduction

```bash
# After enabling usecase/repository/service/di/test/mock plugins and running:
zfa make Task
# Generates:
#   lib/src/domain/usecases/task/toggle_task_usecase.dart
#   lib/src/domain/usecases/task/update_task_usecase.dart
#   lib/src/domain/usecases/task/claim_task_usecase.dart
#   lib/src/domain/usecases/task/complete_task_usecase.dart
#   lib/src/domain/usecases/task/cancel_task_usecase.dart
#   ... 16 usecases total
#
# But TaskRepository has only:
#   Future<Task> get(...);
#   Future<List<Task>> getList(...);
#   Future<Task> create(...);
#   Future<Task> update(...);
#   Future<void> delete(...);
```

Compile error in `lib/src/domain/usecases/task/toggle_task_usecase.dart`:

```
lib/src/domain/usecases/task/toggle_task_usecase.dart:20:24: Error: The method 'toggle' isn't defined for the type 'TaskRepository'.
   return _repository.toggle(params);
```

### Root cause

`zfa make Task` generates a default CRUD set of use cases plus lifecycle-specific use cases (toggle, claim, complete, cancel, resume, pause, message, heartbeat, sweep_stale_heartbeats) without checking which methods exist on the entity's repository. The use case templates are hardcoded for a "task lifecycle" pattern that doesn't match the entity's actual repository interface.

The `--methods` flag on `zfa make` (per the AGENTS.md example) only controls the **entity's** CRUD methods, not the **usecase's** action vocabulary. The default usecase set is broad (toggle, claim, complete, cancel, etc.) and assumes the repository has those methods.

### Expected

Either:
- `zfa make Task` only generates use cases for methods that exist on the TaskRepository (conservative — matches the current repository)
- `zfa make Task` also generates the missing repository methods as part of the same command (extension — creates the full lifecycle)
- A `--usecases` flag (or preset) limits which use case templates are generated, defaulting to "only the CRUD set + methods that exist"

### Actual

`zfa make Task` generates 16 usecases that reference 8+ non-existent repository methods. The build fails, the make step returns `outcome=regression` (because the new use cases introduce new test load failures), and the run stops.

### Verification

- A `zfa make Task` run produces only use cases that compile against the existing TaskRepository
- OR `zfa make Task` also extends the TaskRepository with the missing methods, and everything compiles
- A test run after `zfa make Task` exits 0 from the build step

### Context

Discovered 2026-09-03 while running `zfa tdd run 004-cloud-agent-task-dispatch` with the entity-bearing plan enabled. The run reached U behaviors and fired the plan: `entity Task -> reused; zfa tdd wire U<n> --entity Task; zfa build`. The build failed because `zfa make Task` from a prior run had generated use cases with non-existent method calls. The `unexpressible` misfires on acceptance behaviors, the regression on U behaviors, and the cycle stalled at the build step.

Following STOP-ON-ROADBLOCK from zuraffa/AGENTS.md.
