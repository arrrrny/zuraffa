# TDD Test List — Spec 1645-pipeline-running-binary-tier

Red pre-fix: A1, A2 **assertion red** on the current binary (the defect
itself: the PATH install wins for a compiled driving binary). U1–U3 green
pre- and post-fix (backward-compat guards the fix must not disturb). U4/U5
are RE-SHAPES of the existing bug-#864 tier pins (fake VM stand-in renamed
`dart-vm` → `dart`): green under pre-fix code with the real VM name, and
kept green post-fix by the promoted tier's VM-name check — without the
re-shape they would flip red post-fix for a shape no production VM launch
produces (#1643 precedent). U6–U10 are covered by existing suites and are
pinned by the verification pass, not new tests.

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`.

| id | suite | kind | behavior | traces | state |
| -- | ----- | ---- | -------- | ------ | ----- |
| A1 | test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart | unit | B1, the issue's repro at the tier level: cache-exe driver (the #864 native-AOT shape, script == resolvedExecutable, real executable fixture) with a fake `zfa` on PATH → `result.entrypoint` is the RUNNING binary, never the PATH install; the fake-zfa argv log shows the driving binary spawned the plan's step alone. | AC-1 / FR-001 / SC-001 | PENDING |
| A2 | test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart | unit | B2: cache-exe driver with an UNUSABLE script path (stale-snapshot shape) and a `zfa` on PATH → the running binary still wins. | AC-2 / FR-001 / SC-001 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md` (plus the re-shape rows).

| id | suite | kind | behavior | traces | state |
| -- | ----- | ---- | -------- | ------ | ----- |
| U1 | test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart | unit | B5: cache-exe driver with a NON-executable PATH candidate → the running binary wins; the non-executable PATH candidate never does (outcome pin). | FR-001 / AC-3 | PENDING |
| U2 | test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart | unit | B3: `dart run` driver (VM basename `dart`) with a `zfa` on PATH → the PATH install still wins (backward compatible; green pre- and post-fix). | FR-002 / AC-4 | PENDING |
| U3 | test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart | unit | B4: `dartaotruntime` snapshot driver with a `zfa` on PATH → the PATH install still wins (backward compatible). | FR-002 / AC-4 | PENDING |
| U4 | test/plugins/tdd/services/pipeline_runner_test.dart | unit | RE-SHAPE U16 ("PATH wins over the snapshot fallback"): fake VM stand-in renamed `dart-vm` → `dart` (a REAL VM name); intent and assertions unchanged. Green throughout with the honest shape; flips red post-fix only if left synthetic. | FR-002 / SC-002 / AC-4 | PENDING |
| U5 | test/plugins/tdd/services/pipeline_runner_test.dart | unit | RE-SHAPE U17 ("compiled snapshot keeps the `<vm> <snapshot>` shape"): same rename; the argv log keeps showing `<vm> <snapshot> <args>`. Green throughout. | FR-006 / SC-002 / AC-5 | PENDING |
| U6 | test/plugins/tdd/services/pipeline_runner_test.dart (existing) | unit | COVERED-EXISTING: the `--zfa-bin` override stays tier 1 (the U8 override group drives it via the argv log). | FR-003 / AC-8 | COVERED |
| U7 | test/plugins/tdd/services/pipeline_runner_test.dart (existing) | unit | COVERED-EXISTING: U15 pins the source tier — `bin/zfa.dart` compiles and the artifact runs alone (VM driver, injected compile seam). | FR-004 / FR-005 / AC-6 | COVERED |
| U8 | test/core/no_jit_zfa_spawn_scan_test.dart (existing) | unit | COVERED-EXISTING: the no-JIT sweep — no tier resolution may spawn the bare Dart VM. | FR-005 | COVERED |
| U9 | test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart + bug_1472_refactor_gate_errors_only_test.dart (existing) | unit | COVERED-EXISTING: the #1472 pin contract — equal versions keep, provably-different swap, unresolvable fail open. Untouched by this feature. | FR-007 / AC-9 | COVERED |
| U10 | test/plugins/tdd/services/pipeline_runner_test.dart (existing) | unit | COVERED-EXISTING: U14 pins native-AOT self-resolution with PATH missing (the binary path is never doubled). | FR-001 / FR-005 | COVERED |

## Red protocol

```
dart test test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart
# expected pre-fix: A1/A2 FAIL (Actual = the PATH fixture), U1–U3 pass,
# U4/U5 not yet re-shaped — re-shape lands with the same test commit.
```
