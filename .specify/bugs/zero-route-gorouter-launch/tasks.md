# Tasks: zero-route-gorouter-launch

Test tasks (mandatory, non-skippable) drive the fix; implementation tasks follow each behavior's green test.

## Tests (TDD loop — driven by `zfa tdd run`)

- [ ] [behavior: A1] Test: emitted GoRouter installs `errorBuilder` + runtime empty-table fallback (widget lane, kind: presence) — traces AC-1
- [ ] [behavior: A2] Test: initial `/` resolution renders the placeholder instead of throwing (widget lane) — traces AC-2
- [ ] [behavior: A3] Test: skin-audit variant carries the same `errorBuilder` / fallback alongside the observer — traces AC-3
- [ ] [behavior: A4] Test: runtime empty-check leaves a real route table untouched — traces AC-4
- [ ] [behavior: A5] Test: placeholder survives `routing/index.dart` regeneration (fallback is runtime-side in app_router.dart) — traces AC-5
- [ ] [behavior: A6] Test: pure-Dart smoke test stays router-free — traces AC-6
- [ ] [behavior: A7] Test: Flutter day-zero smoke test pumps the app shell and asserts `/` resolves (widget lane) — traces AC-7
- [ ] [behavior: A8] Test: golden tests assert the new `errorBuilder` / fallback output — traces AC-8

## Implementation (non-behavior work — driven by `zfa tdd run` / implement)

- [ ] [behavior: A1..A8] Remediate `AppShellBuilder.buildAppRouter()` (bare + skin-audit) to emit `errorBuilder` + empty-table fallback route
- [ ] [behavior: A7] Extend `SmokeTestWriter` Flutter flavor to pump the shell / resolve `/`
- [ ] [behavior: A8] Update golden tests: `test/plugins/app_shell/app_shell_builder_test.dart`, `test/plugins/app_shell/app_shell_skin_audit_test.dart`, `test/integration/day_zero_smoke_gate_test.dart`, `test/cli/writers/tdd/smoke_test_writer_test.dart`, `test/skew/bug_1197_two_end_matrix_test.dart`
