# TDD Verification — bug #1503 (planner emitted uncertified mocks; engine's own spec-1001 preflight refused them)

Verification record for the bug-fix PR
`fix/1503-mock-create-certify-pipeline`. Every number below is from a
command actually executed in this session (Dart SDK 3.13.3 stable, Linux
x64, repo HEAD `c5d9bd1bc7e6`). Nothing is projected, copied, or
back-dated from another run.

## Fix scope (hard-constraint compliant)

Changed files — and ONLY these:

- `lib/src/plugins/tdd/services/generation_planner.dart` — BOTH entity
  pipeline arms now request the certified variant:
  - traced-entity arm (bug-#829 unit lane, non-stub): args
    `['mock', 'create', '--name', traced, '--certify']`
  - declared `GenerationSurface.entityPipeline` arm (`_declaredPlan`):
    args `['mock', 'create', '--name', name, '--certify']`
  Purpose strings updated in the same two constructors to name the
  certified contract (spec 1001 — bug #1503). No other production change.
- `test/plugins/tdd/services/generation_planner_test.dart` — the two argv
  pins that encoded the PRE-fix contract (U-829a `['mock', 'create',
  '--name', 'User']`; U-909 `['mock', 'create', '--name',
  'UserPreference']`) moved to the POST-fix certified contract.
- `test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart`
  — NEW suite, 4 behaviors (see `tdd/test-list.md`).

NOT changed: the spec-1001 gate (`run_command.dart` pre-start preflight),
the preflight refusal/journaling, `mock create` command implementation,
`create_mock_capability.dart` (standalone `--certify` stays opt-in,
default false), any engine file. Verified by the untouched gate-side
suites passing below.

## Red (before the fix) — ACTUAL

```
dart test test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart
→ 00:00 +1 -3: Some tests failed.
```

3 RED / 1 GREEN, failing for the RIGHT reason — the missing flag, verbatim
from the run:

- U-1503a: `Expected: ['mock', 'create', '--name', 'Task', '--certify']`
  / `Actual: ['mock', 'create', '--name', 'Task']` / "at location [4] is
  ['mock', 'create', '--name', 'Task'] which shorter than expected"
- U-1503b: same argv mismatch on the declared entityPipeline arm
- U-1503c: `Actual: ['mock', 'create', '--name', 'Task']` / "does not
  contain '--certify'"
- U-1503d (stub arm plans no mock step): already GREEN pre-fix — the
  guard holds on both sides of the change.

## Green (after the fix) — ACTUAL

```
dart test test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart
→ 00:00 +4: All tests passed!
```

4/4. Post-format re-run (dart format touched the new test file only):
`00:00 +4: All tests passed!` again.

## Chunked suite (only what the change can touch) — ACTUAL, all green

| Chunk | Command | Result |
|-------|---------|--------|
| planner + new bug suite | `dart test test/plugins/tdd/services/generation_planner_test.dart test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart` | 35/35 pass |
| other planner arms | `dart test test/plugins/tdd/services/generation_planner_declared_test.dart test/plugins/tdd/services/generation_planner_widget_950_test.dart test/plugins/tdd/services/generation_planner_ffi_835_test.dart` | 18/18 pass |
| real-CLI planner + standalone mock create | `dart test test/plugins/tdd/services/generation_planner_real_cli_test.dart test/plugins/mock/create_mock_capability_test.dart` | 13/13 pass |
| gate side (untouched, reconciliation intact) | `dart test test/plugins/tdd/commands/run_engine_command_test.dart test/plugins/tdd/commands/bug_1367_realize_mock_cert_fallback_test.dart` | 17/17 pass |

Total: 83 passed, 0 failed, 0 new failures. Standalone `mock create`
(opt-in `--certify`, default false) unchanged — its suite passes untouched.

## Static analysis + formatting — ACTUAL

```
dart analyze lib/src/plugins/tdd/services/generation_planner.dart \
  test/plugins/tdd/services/generation_planner_test.dart \
  test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart
→ No issues found!
```

(Re-checked after formatting: still "No issues found!".) `dart format` on
the three changed files: 1 changed (the new test file), 0 behavior.

## Cleanup — ACTUAL

`rm -rf .dart_tool/test/` + kernel artifacts removed after the verify
phase; disk at 13% used (8.2G free) at delivery.

## Not proved

- `dart analyze` / full-suite over the WHOLE repo (this record covers the
  changed files + their chunked suites per the verify protocol "only test
  what you changed").
- End-to-end `zfa tdd run` on a live todo-app fixture (the planner argv
  contract is pinned at the unit level; the run-loop path is exercised by
  the untouched `run_engine_command_test.dart` / #1367 suites).
