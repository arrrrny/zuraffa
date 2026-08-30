# Quickstart: validating `zfa tdd make`

Runnable end-to-end validation. Prerequisites: repo checkout on branch
`047-tdd-make`, Dart SDK on PATH, `zfa` resolvable (repo checkout).

## 1. Unit suite (fast)

```bash
dart test test/plugins/tdd/services/generation_planner_test.dart \
          test/plugins/tdd/services/pipeline_runner_test.dart \
          test/plugins/tdd/services/suite_guard_test.dart \
          test/plugins/tdd/models/cycle_entry_test.dart
```

Expected: all pass, no `slow` tags.

## 2. Command + scenario suite (slow, subprocess)

```bash
dart test --tags slow test/plugins/tdd/make_command_test.dart \
     test/plugins/tdd/scenarios/sc_005_turns_red_green_test.dart \
     test/plugins/tdd/scenarios/sc_006_requires_certified_red_test.dart \
     test/plugins/tdd/scenarios/sc_007_regression_guard_test.dart \
     test/plugins/tdd/scenarios/sc_008_misfire_stop_test.dart
```

Expected: all pass. These drive the real CLI against `TddFixture` projects.

## 3. Manual smoke: certified red → green

From the zuraffa repository root, targeting a fixture project with a `gen`'d,
`verify-red`-certified behavior:

```bash
dart run bin/zfa.dart tdd make --project /path/to/fixture B-001
echo "exit=$?"   # expect exit=0
tail -20 /path/to/fixture/specs/<f>/tdd/cycle-log.md
```

Expected: exit 0; summary line `make: behavior=B-001 outcome=green ...`; the
green entry lists the exact pipeline commands (contract:
[contracts/make.md](contracts/make.md)); the behavior's test file is
byte-identical to its pre-`make` content.

## 4. Preconditions and guards

```bash
# no red evidence -> refused before generating
dart run bin/zfa.dart tdd make --project /path/to/fixture B-999
echo "exit=$?"   # non-zero, outcome=...

# regression guard: fixture with a sibling that the generation breaks
# -> non-zero, names the regressed test, no green entry appended
```

Expected: each rejection names its outcome class and remediation; the cycle
log gains entries ONLY for certified greens.

## 5. Misfire honesty

```bash
# behavior whose implementation the pipeline cannot express
dart run bin/zfa.dart tdd make --project /path/to/fixture B-042
echo "exit=$?"
```

Expected: non-zero, `outcome=unexpressible`, the unmet capability named in
behavior terms, test file and cycle log untouched.
