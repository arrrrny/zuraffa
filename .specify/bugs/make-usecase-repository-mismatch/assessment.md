# Bug Assessment: zfa make Task usecase/repository interface mismatch

- **Slug**: make-usecase-repository-mismatch
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/921
- **Verdict**: valid
- **Severity**: high

> NOTE: Materialized from the issue's own root-cause section on 2026-09-03 because the
> expected pre-committed assessment was absent on `master`. No independent re-triage was
> performed; all statements below are transcriptions/structurings of issue #921 content.

## Report (verbatim or summarized)

`zfa make Task` generates 16 usecases referencing 8+ non-existent repository methods (toggle, claim, complete, cancel, resume, pause, message, heartbeat, sweep_stale_heartbeats). The build fails, the make step returns `outcome=regression`, and the run stops. (issue #921)

## Symptom

Generated use case files under `lib/src/domain/usecases/task/` call `repository.toggle(params)`, `repository.claim(params)`, `repository.complete(params)`, etc., but the auto-generated `TaskRepository` interface only declares the CRUD set (get, getList, create, update, delete). `dart analyze` / build fails with "The method 'toggle' isn't defined for the type 'TaskRepository'."

## Root cause (per issue #921)

Use case templates are hardcoded for a "task lifecycle" pattern that doesn't match the entity's actual repository interface. The `--methods` flag only controls the entity's CRUD methods, not the usecase's action vocabulary. The default usecase set is broad and assumes repository methods that were never generated.

## Remediation options (per issue #921)

1. **Conservative (chosen)**: `zfa make Task` only generates use cases for methods that exist on the repository — matches the current repository interface.
2. Extension: `zfa make Task` also generates the missing repository methods as part of the same command (creates the full lifecycle).
3. A `--usecases` flag (or preset) limits which use case templates are generated, defaulting to "only the CRUD set + methods that exist".

## Hard constraints

- Generated use cases must compile against the existing repository.
- Build step must exit 0 after make.
- One PR for this bug only.
- STOP-ON-ROADBLOCK per zuraffa/AGENTS.md.
