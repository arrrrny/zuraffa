# Quickstart: 1645-pipeline-running-binary-tier

Validation guide — prove the pipeline resolves the running compiled
binary ahead of PATH for compiled drivers, and that VM drivers are
untouched. All commands run from the repo root on the feature branch.

## Prerequisites

- Dart SDK ^3.11.0 (3.13.x verified). No Flutter SDK needed (pure-Dart
  package). `dart pub get` once if `.dart_tool/` is absent.

## The behaviors (fast tier, no real AOT compile)

```sh
# The new tier suite (B1–B5) — red pre-fix, green post-fix
dart test test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart

# The re-shaped bug-#864 tier group + every services neighbor
dart test test/plugins/tdd/services/
```

Expected: `All tests passed!` for both (post-fix).

## Regression scope

```sh
# The #1472 pin is untouched and must stay green
dart test test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart \
          test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart

# The no-JIT sweep — a resolution never spawns the bare VM
dart test test/core/no_jit_zfa_spawn_scan_test.dart
```

Expected: `All tests passed!` for both.

## Static gates

```sh
dart analyze lib/src/plugins/tdd/services/pipeline_runner.dart \
             test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart \
             test/plugins/tdd/services/pipeline_runner_test.dart
dart format --output=none --set-exit-if-changed \
            lib/src/plugins/tdd/services/pipeline_runner.dart \
            test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart \
            test/plugins/tdd/services/pipeline_runner_test.dart
```

Expected: `No issues found!` and `0 changed`.

## What "fixed" looks like

- B1/B2 (compiled driver + PATH install): `result.entrypoint` is the
  driving binary, never the PATH fixture. Pre-fix these two fail with
  the PATH fixture as `Actual` — that is the red evidence.
- B3/B4 (`dart run` / `dartaotruntime` drivers): the PATH install still
  wins — unchanged from pre-fix.
- U16/U17 (re-shaped): a real-VM-named driver still resolves PATH and
  keeps the `<vm> <snapshot>` spawn shape in the argv log.
