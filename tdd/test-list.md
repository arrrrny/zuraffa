# TDD test list — Bug #1636 the running compiled binary outranks the PATH tier

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1636-b1 | test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart | unit | the cache-exe driver (the #864 native-AOT shape, `script == resolvedExecutable`) with a zfa on PATH resolves the RUNNING binary, not the PATH install — the issue's repro at the tier level | issue #1636 criterion 1 | GREEN |
| U-1636-b2 | test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart | unit | the cache-exe driver with an unusable script (the stale-dill shape) and a zfa on PATH still resolves the running binary | issue #1636 criterion 1 | GREEN |
| U-1636-b3 | test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart | unit | the `dart run` driver (VM `resolvedExecutable`) keeps the #690 order — the PATH tier still fires (backward compatible) | issue #1636 criterion 2 | GREEN |
| U-1636-b4 | test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart | unit | the `dartaotruntime` snapshot driver keeps the #690 order — the PATH tier still fires (backward compatible) | issue #1636 criterion 2 | GREEN |
| U-1636-b5 | test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart | unit | the cache-exe driver with a non-executable PATH candidate resolves the running binary without consulting PATH | issue #1636 criterion 3 (tier order per driver shape) | GREEN |
| U-1636-p1 | test/plugins/tdd/services/step_runner_test.dart | unit | PATH tier re-labeled tier 5 for a VM driver — unchanged by #1636 | issue #1636 criterion 3 (order documented + pinned) | GREEN |
| U-1636-p2 | test/plugins/tdd/services/step_runner_test.dart | unit | the running compiled binary is the entrypoint when the script is unusable and nothing is on PATH (tier 4 — the #690 final fallback promoted) | issue #1636 criterion 3 | GREEN |
| U-1636-p3 | test/plugins/tdd/services/step_runner_test.dart | unit | a usable `Platform.script` still wins for a REAL JIT-snapshot driver (VM `resolvedExecutable`) when nothing is on PATH (tier 6 preserved; the pre-#1636 synthetic mixed shape is unreachable in production per #864) | issue #1636 criterion 3 | GREEN |
| U-1636-p4 | test/plugins/tdd/services/step_runner_test.dart | unit | a non-executable PATH candidate is skipped: a VM driver with nothing else resolvable throws the honest cannot-resolve error (executable bit contract, #665) | contract preservation | GREEN |

## Red evidence (pre-fix, this session)

Verbatim runs preserved in
`.specify/bugs/1636-refactor-build-resolves-path-zfa/red-evidence.md`:

- Suite 1 (new, pre-fix): `00:00 +3 -2: Some tests failed.` — B1 and B2
  resolved the PATH fixture (`/tmp/zfa1636_path*/zfa`) instead of the
  driving binary (`/tmp/zfa1636_cache*/zfa_exe`), the issue's exact bug;
  B3/B4/B5 green pre-fix (the backward-compat guards already held).

## Green evidence (post-fix, this session)

- `dart test test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart`
  → `00:00 +5: All tests passed!`
- `dart test test/plugins/tdd/services/` (step_runner, refactor_passes,
  #1371, and every neighbor)
  → `01:42 +1104: All tests passed!`
- `dart test test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart
  test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart` (the #1472
  pin through `zfaBuildCommand`'s delegation)
  → `00:00 +18: All tests passed!`
- `dart test test/utils/dart_toolchain_resolver_test.dart
  test/plugins/tdd/bug_1329_step_failure_diagnostics_test.dart
  test/plugins/tdd/bug_1159_baseline_timeout_test.dart`
  → `00:02 +18: All tests passed!`
- `dart test test/core/no_jit_zfa_spawn_scan_test.dart` (the no-JIT sweep)
  → `00:00 +5: All tests passed!`

## Suite placement note

The tier suite lives in `test/plugins/tdd/services/` beside its neighbor
`bug_1371_entrypoint_existence_test.dart` (fast tier, injected
`script`/`resolvedExecutable`/`environment`, no real binary compiled — the
same convention the #690 group in `step_runner_test.dart` uses). The build
pass is exercised through its existing suites: `refactor_passes_test.dart`
(#689/#717) and the #1472 gate suites prove the delegation and the pin are
unchanged for every driver shape the tests can reach under `dart test`
(a VM driver), while the new suite pins the compiled-driver shapes the
`zfaBuildCommand` call site inherits from `StepRunner.resolveEntrypoint`.
