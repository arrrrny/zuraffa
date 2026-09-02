fix(723): tdd make routes unit behaviors to plain-function generator (v2)

zfa tdd make dispatched unit behaviors (U*) to the entity/CRUD generators whenever their description carried entity/use-case/service keyword prose — the slugified behavior id (u5) went to `zfa make` as an entity name (or `zfa entity create` fired for entity prose) and the run loop stopped at U5:make with `outcome=generation-error` (re-report of #718, confirmed on v6.1.0).

## Changes

- `lib/src/plugins/tdd/commands/make_command.dart` (+49 lines)
- `lib/src/plugins/tdd/services/generation_planner.dart` (+81 lines)
- `test/plugins/tdd/make_command_test.dart` (+123 lines)
- `test/plugins/tdd/services/generation_planner_test.dart` (+86 lines)

GenerationPlanner now dispatches on the behavior's loop kind BEFORE description matching: kind=unit plans `zfa tdd func <id>` + `build` — the #657/#660 plain-function surface gen pairs with every unit behavior's subject stub. MakeCommand resolves the kind from the test-list row (TestListReader, the kind source of truth) with the A<n>/U<n> id convention as fallback and null keeping the pre-#723 description-keyed dispatch (the #696 contract for kindless summaries).

## TDD evidence (red → green)

- **RED** (pre-fix): U-723a planned `['make','u5','--no-entity']` vs expected `['tdd','func','U5']`; U-723e reproduced the issue's exact failure shape.
- **GREEN** (post-fix): skip-transition, safe-failure control, terminal-only scope, amended A15.

## Assessment

Assessment: `.specify/bugs/tdd-make-still-fails-unit-behaviors/assessment.md`

Closes #723
