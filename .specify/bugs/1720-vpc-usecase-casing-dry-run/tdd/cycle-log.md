# TDD Cycle Log: 1720-vpc-usecase-casing-dry-run

- schema: 1
- branch: fix/1720-vpc-usecase-casing-dry-run
- baseline: d4d7ec93 (master)

## Cycle: 1720-red (RED)

- behavior: A1–A4, U1–U4, E1–E2 (see test-list.md)
- kind: red
- date: 2026-09-18
- command: `dart test test/regression/issue_1720_usecase_casing_dry_run_test.dart`
- result: **8 failed / 4 passed** (the 4 passes are the E-guard assertions that
  were already correct pre-fix: import paths, Pascal-token presenter refs)
- evidence: `tdd/red-evidence.log` (full runner output)
- live CLI repro (same session): `zfa make Login --no-entity --domain auth
  --with=vpc,state,route,di,test --usecases=login,logout,sign_in_with_google,...`
  → presenter emitted `getIt<loginUseCase>()` / `late final
  sign_in_with_googleUseCase _sign_in_with_google;` and 5×
  `⚠️ Generating placeholder Fake<token>UseCase ... interface not declared`
  for usecases that exist on disk; `dart analyze` reported 10 bug-caused
  errors (`undefined class`/`non_type_as_type_argument` on mangled names)
- evidence: `tdd/red-repro-cli.log`
- note: the failing-test fixtures were corrected during the cycle
  (`class Login` → `class LoginUseCase`); the RED failures attributed to the
  bug were reproduced independently and unchanged by that fixture correction
  (CLI repro in red-repro-cli.log uses correct fixtures throughout)

## Cycle: 1720-green (GREEN)

- behavior: A1–A4, U1–U4, E1–E2
- kind: green
- date: 2026-09-18
- fix: `StringUtils.normalizeUseCaseClassName` applied at 4 sites
  (common_patterns.dart, test_builder_orchestrator.dart, di_plugin.dart,
  custom_usecase_generator_orchestrator.dart)
- command: `dart test test/regression/issue_1720_usecase_casing_dry_run_test.dart`
- result: **12 passed / 0 failed**
- live CLI repro re-run: 0 placeholder warnings, presenter refs PascalCase,
  fakes `class FakeLoginUseCase implements LoginUseCase`, bug-caused analyze
  errors 10 → 0; fully-resolvable pure-Dart project analyzes the generated
  orchestrator + DI with **0 errors** (2 pre-existing-style `unused_field`
  warnings inherent to the TODO-stub orchestrator design)
- evidence: `tdd/green-evidence.log`

## Cycle: 1720-mutation (verify — mutation check)

- kind: verify
- date: 2026-09-18
- mutants (each applied via sed to the changed file, suite re-run, reverted):
  - M1: `normalizeUseCaseClassName` drops the `UseCase` suffix → **killed**
    (10/12 tests fail: U1 parse tests + A1–A4)
  - M2: `parseUseCaseInfo` reverts to raw-token ternary → **killed**
    (4/12 fail: U1 + A1)
  - M3: test-builder `interfaceName` reverts to unconditional
    `'${usecase}UseCase'` → **killed** (2/12 fail: A3 + A4)
- post-restore suite: 12/12 green
