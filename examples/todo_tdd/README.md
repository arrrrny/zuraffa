# todo_tdd — a pure-Dart todo app built entirely with the `zfa tdd` cycle

This example is a complete, functional todo application whose domain layer was
produced **only** by the Zuraffa TDD pipeline — no hand-written domain or
architecture code. It is the end-to-end verification artifact for the
`zfa setup` → `zfa tdd init` → `zfa tdd plan` → `zfa tdd run` workflow
(specs 041/044/046/047/049) on a pure-Dart (non-Flutter) project.

## What the cycle generated

| Artifact | Produced by | Behavior |
| --- | --- | --- |
| `lib/src/domain/entities/todo/` | `zfa entity create` (make step) | A1 (AC-1) |
| `lib/src/domain/entities/todo_stats/` | `zfa entity create` (make step) | A2 (AC-2) |
| `lib/tdd/a3_subject.dart` | `zfa tdd func` (make step) | A3 (AC-3) |
| `lib/tdd/u1..u6_subject.dart` | `zfa tdd func` (make step) | U1–U6 (FR-001..006) |
| `test/tdd/a*_test.dart`, `test/tdd/u*_test.dart` | `zfa tdd gen` | all behaviors |
| `specs/001-todo-app/tdd/cycle-log.md` | `zfa tdd verify-red` / `make` / `refactor` | red→green evidence |

Behavior → pipeline routing (GenerationPlanner): acceptance prose carrying
`create entity <Name> with …` routed to `entity create` + `tdd wire` + `build`;
acceptance prose carrying a function-intent verb and every unit behavior routed
to `tdd func` + `build`.

The entity **field schemas** were applied through the explicit CLI surface
(`zfa entity create --field …`) after the cycle completed — see
"Known limitations" below.

## Reproduce from scratch

```bash
dart pub global activate zuraffa          # or run from the repo: dart run bin/zfa.dart

zfa setup todo_tdd --dart --no-git        # scaffold a pure-Dart app
cd todo_tdd
zfa tdd init                              # TDD baseline (Dart profile)

# write specs/001-todo-app/spec.md (committed in this example)
zfa tdd plan 001-todo-app                 # 3 acceptance + 6 unit behaviors

zfa tdd run 001-todo-app                  # gen → verify-red → make → refactor
# → run: feature=001-todo-app result=complete pending=0 red=0 green=0 done=9
```

## Run it

```bash
dart pub get
dart test                     # 11 tests, all green
dart run bin/todo_app.dart    # prints the todo list from generated domain
```

## Known limitations discovered by this verification

1. **Entities are generated field-less.** The planner emits
   `entity create -n <Name>` without `--field` flags, so cycle-generated
   entities are empty shells; schemas must be applied via an explicit
   `zfa entity create --field …` (or `add-field`) pass. Field types cannot be
   inferred from spec prose safely, so this is by-design minimal generation —
   but it is worth documenting.
2. **`zfa entity add-field` corrupts empty-body entities** (zorphy
   `EntityCreator._insertFields`): when the `$Entity` class body is empty
   same-line braces (`abstract class $Todo {}`), the insert position resolves
   to `0` and the new getters are prepended *above* the imports, producing
   invalid Dart. Repro + root cause in
   `REPORTS/tdd-cycle-end-to-end-verification.md`. Workaround: use
   `zfa entity create --field …` (the template path) instead of `add-field`
   on empty shells.
3. **CRUD-keyword acceptance behaviors dead-end honestly.** An acceptance
   behavior whose description contains `repository` / `service` / `use case`
   / `crud` routes to `zfa make <Name>` + `build`, which generate scaffolds
   but never implement the behavior's acceptance subject, so `tdd make`
   stops with `generation-error` ("target test still fails after
   generation"). The composition fallback (spec 052) does not engage because
   the plan is expressible. Design specs for the loop around the
   entity/function surfaces until this surface gains a subject-implementation
   step.
4. **Behavior test paths are flat across features** (`test/tdd/<id>_test.dart`),
   so two features in one project collide on `A1`/`U1` ids (the per-feature
   ownership registry then reports an ownership conflict on `gen`). One
   feature per project (this example) or per-project feature sequencing
   avoids it.
