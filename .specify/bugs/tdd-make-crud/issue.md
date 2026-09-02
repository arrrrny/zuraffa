# Bug Issue: tdd make: CRUD-keyword acceptance behaviors cannot reach green — make ends with generation-error (subject never implemented)

- **Slug**: tdd-make-crud
- **Fetched**: 2026-09-02
- **Issue**: 758
- **URL**: https://github.com/arrrrny/zuraffa/issues/758
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd make <acceptance-id>` (CRUD-keyword acceptance path), reached via `zfa tdd gen A1 && zfa tdd verify-red A1 && zfa tdd make A1`

## What was expected

An acceptance behavior whose Then-clause mentions CRUD keywords (e.g. *"the Todo repository service persists a todo item."*) should either (a) reach green — i.e. the routed `make <slug> (+ --no-entity), build` plan should also implement the acceptance subject — or (b) be rejected at `plan` time with an actionable message.

## What returned

```
make: behavior=A1 outcome=generation-error feature=001-crud-probe
```

The pipeline steps in the plan succeed, but nothing implements the acceptance subject (`lib/tdd/<id>_subject.dart` still throws `UnimplementedError`), so the post-generation target run stays red and `make` honestly stops with `generation-error`. The loop is blocked for a natural spec phrasing.

## Root cause

`GenerationPlanner.plan()` routes descriptions containing `crud` / `use case` / `repository` / `service` to the CRUD branch, but for acceptance-kind rows that branch never implements the subject. Spec-052 composition fallback does not engage (the plan IS expressible), and acceptance behaviors run before any unit behavior is green, so no composable anchors exist in a single pass.

## Suggested direction

For acceptance-kind rows routed to the CRUD branch, append a subject-implementation step (e.g. `tdd wire <id> --entity <Name>` when the description names an entity that exists, else engage the composition fallback), or fail fast at `plan` time.

## Evidence

Reproduced in a throwaway project during the end-to-end TDD cycle verification (commit `14651299`, Dart 3.13.3, pure-Dart project). Full context: `REPORTS/tdd-cycle-end-to-end-verification.md` (finding F1, severity: high).

## Comments

None.
