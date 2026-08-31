# Cycle Log: bug #609 — tdd make planner omits `-n` (name) flag

Append only. Newest last. Every entry's `red` block is the evidence that
the test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` (--preset=all) -> 345 passed, 0 failed
- commit: `00ed1451` (fix/609 branch base; master compile damage resolved
  by the repo's `fix/tdd-plugin-compile-errors` commit — see PR note)
- recorded: cycle 0, before any change

## Cycle 1: planner emits real-CLI-valid entity argv (bug #609)

- behavior: the `GenerationPlanner` entity plan step carries the exact
  argv the real `EntityCommand` parses — including `-n/--name` — so the
  real pipeline can execute step 0 (fake-zfa drift can no longer hide a
  malformed plan).
- tests:
  - `test/plugins/tdd/services/generation_planner_test.dart` U3 tightened
    from first-two-token assertions to an exact-argv pin
    `['entity', 'create', '-n', 'User']` (fast tier).
  - `test/plugins/tdd/services/generation_planner_real_cli_test.dart`
    (new, slow+integration tier): plans "create entity User with email",
    spawns the planner-emitted argv verbatim against the REAL
    `bin/zfa.dart entity create` in a temp project, asserts exit 0 and
    absence of the name-required error.
- red: `dart test test/plugins/tdd/services/generation_planner_test.dart
  test/plugins/tdd/services/generation_planner_real_cli_test.dart` -> 2
  failures:
  - U3: `Expected: ['entity', 'create', '-n', 'User'] Actual:
    ['entity', 'create', 'User'] Which: at location [2] is 'User'
    instead of '-n'`
  - drift guard: `Expected: <0> Actual: <1> the real zfa CLI rejected
    the planner-emitted argv ([entity, create, User]) — planner/CLI
    drift: Error: Entity name is required. Use -n or --name to specify.`
  That real-CLI rejection is the live reproduction of the production
  failure in the assessment (pipeline step 0, exit 1).
- green: `args: ['entity', 'create', '-n', name]` at
  `lib/src/plugins/tdd/services/generation_planner.dart` (the one-line
  fix). Re-run: fast tier 6/6 passed; integration tier 1/1 passed (real
  CLI accepted `[entity, create, -n, User]`, exit 0). Full plugin suite
  `dart test --preset=all test/plugins/tdd/` -> 345 passed, 0 failed.
- refactor: none required — the emission is a single literal argv list.
- deliberate mutant (mutation sampling, no mutation tool in profile):
  the red phase itself is the mutant — dropping `-n` from the emitted
  argv was caught by both the U3 pin and the real-CLI drift guard;
  restoring `-n` returned the suite to green. 1 mutant, 1 caught.
- commit: `db00ff5e`
