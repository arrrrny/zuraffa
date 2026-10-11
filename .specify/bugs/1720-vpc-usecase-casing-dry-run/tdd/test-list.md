# TDD Test List: BUG 1720 — `--usecases` identifier casing + dry-run detection

**Feature**: 1720-vpc-usecase-casing-dry-run
**Generated**: 2026-09-18
**Branch**: fix/1720-vpc-usecase-casing-dry-run
**Mode**: bug TDD (spec-whole), fallback audit (`.zfa.json` absent)

## Test List Format
- **Behavior ID**: A1… (acceptance) / U1… (unit) / E1… (regression/edge)
- **Status**: DONE (test written, red→green) | PENDING | BLOCKED

---

## Acceptance Behaviors (issue repro-level)

| ID | Type | Source | Status | Test Name | Test Path | Notes |
|---|---|---|---|---|---|---|
| A1 | acceptance | issue.md Repro — presenter/controller type refs | DONE | lowercase tokens emit PascalCase getIt type refs | test/regression/issue_1720_usecase_casing_dry_run_test.dart | `getIt<LoginUseCase>()`, `late final LoginUseCase _login;`; CLI repro in tdd/red-repro-cli.log + green-evidence.log |
| A2 | acceptance | issue.md token table — no suffix doubling | DONE | full class name tokens are not suffix-doubled (presenter) | test/regression/issue_1720_usecase_casing_dry_run_test.dart | `LoginUseCase` token → `LoginUseCase`, not `UseCaseUseCase` |
| A3 | acceptance | issue.md Additionally — dry-run detects existing usecases | DONE | lowercase tokens produce real fakes for existing usecases | test/regression/issue_1720_usecase_casing_dry_run_test.dart | asserts zero `placeholder` warnings + `class FakeLoginUseCase implements LoginUseCase` (print-capture zone) |
| A4 | acceptance | issue.md Additionally — no doubling in test fakes | DONE | full class name tokens are not suffix-doubled (test builder) | test/regression/issue_1720_usecase_casing_dry_run_test.dart | kills `FakeLoginUseCaseUseCase` emission |

## Unit Behaviors (component level)

| ID | Type | Source | Status | Test Name | Test Path | Notes |
|---|---|---|---|---|---|---|
| U1 | unit | CommonPatterns.parseUseCaseInfo | DONE | snake_case token login → LoginUseCase / sign_in_with_google → SignInWithGoogleUseCase / LoginUseCase not doubled / loginUseCase normalized | test/regression/issue_1720_usecase_casing_dry_run_test.dart | 4 tests, one per token form in the issue table |
| U2 | unit | parseUseCaseInfo fieldName contract (unchanged) | DONE | fieldName derivation is unchanged (login → login / sign_in_with_google) | test/regression/issue_1720_usecase_casing_dry_run_test.dart | locks minimal-fix behavior: only class refs change |
| U3 | unit | DiPlugin._generateOrchestratorUseCaseDI | DONE | lowercase tokens emit PascalCase type refs in DI registrations | test/regression/issue_1720_usecase_casing_dry_run_test.dart | `getIt<LoginUseCase>()` in `di/usecases/auth_flow_usecase_di.dart` |
| U4 | unit | CustomUseCaseGenerator orchestrator | DONE | lowercase tokens emit PascalCase field types | test/regression/issue_1720_usecase_casing_dry_run_test.dart | `final LoginUseCase _login;` in generated orchestrator |

## Regression/Edge Behaviors

| ID | Type | Source | Status | Test Name | Test Path | Notes |
|---|---|---|---|---|---|---|
| E1 | regression | assessment.md constraint — import paths unchanged | DONE | import path assertion inside A1 test | test/regression/issue_1720_usecase_casing_dry_run_test.dart | `import '../../../domain/usecases/auth/login_usecase.dart';` still emitted |
| E2 | regression | constraint — already-correct Pascal tokens unaffected | DONE | full class name tokens are not suffix-doubled (presenter + test builder + DI + orchestrator `isNot(contains('UseCaseUseCase'))`) | test/regression/issue_1720_usecase_casing_dry_run_test.dart | these assertions passed pre-fix too (guards) |

## Coverage matrix (fix site → behaviors)

| Fix site | Behaviors |
|---|---|
| `StringUtils.normalizeUseCaseClassName` (new) | U1, U2 (via parseUseCaseInfo), A1–A4 (transitively) |
| `CommonPatterns.parseUseCaseInfo` | U1, U2, A1, E1 |
| `test_builder_orchestrator.dart` fake names | A3, A4 |
| `di_plugin.dart` `_generateOrchestratorUseCaseDI` | U3 |
| `custom_usecase_generator_orchestrator.dart` | U4 |
