# TDD Verification Report: BUG 1720 — `--usecases` PascalCase refs + dry-run detection

**Feature**: 1720-vpc-usecase-casing-dry-run
**Verified**: 2026-09-18
**Branch**: fix/1720-vpc-usecase-casing-dry-run (on top of master @ d4d7ec93)
**Mode**: fallback LLM-guided audit (engine detection: `zfa` present via
`dart run bin/zfa.dart`, but `.zfa.json` absent → ZFA_MISSING → fallback per
`/speckit.tdd.verify` Step 0)
**Toolchain**: Dart 3.13.4 (stable) — Flutter SDK not available in this
environment (see Environmental Failures)

---

## Verdict: **PASS**

All 10 behaviors (4 acceptance + 4 unit + 2 regression guards) are covered by
tests that were driven red → green in this session, the suite is green, and
3/3 targeted mutants on the changed files were killed.

---

## Test Coverage Summary

| Category | Total | DONE | PENDING | BLOCKED |
|---|---|---|---|---|
| Acceptance (outer loop) | 4 | 4 | 0 | 0 |
| Unit (inner loop) | 4 | 4 | 0 | 0 |
| Regression/Edge guards | 2 | 2 | 0 | 0 |
| **Total** | **10** | **10** | **0** | **0** |

Red phase: 8 failed / 4 guard-passed (tdd/red-evidence.log)
Green phase: **12/12 passed** (tdd/green-evidence.log)

---

## Test Evidence (all run in this session)

### Acceptance Behaviors
- **A1** `lowercase tokens emit PascalCase getIt type refs` — presenter plugin
  driven in-process against a temp project with existing usecases. Also proved
  end-to-end via the real CLI (see CLI Evidence below).
- **A2** `full class name tokens are not suffix-doubled (presenter)` —
  `LoginUseCase` token → `getIt<LoginUseCase>()`, `isNot(contains('UseCaseUseCase'))`.
- **A3** `lowercase tokens produce real fakes for existing usecases` —
  TestPlugin orchestrator path with `class LoginUseCase` on disk; asserts
  `class FakeLoginUseCase implements LoginUseCase` AND zero `placeholder`
  warnings captured via a print-intercepting Zone (the issue's dry-run symptom).
- **A4** `full class name tokens are not suffix-doubled (test builder)` —
  kills the `FakeLoginUseCaseUseCase` emission.

### Unit Behaviors
- **U1** parseUseCaseInfo token normalization: `login` → `LoginUseCase`,
  `sign_in_with_google` → `SignInWithGoogleUseCase`, `LoginUseCase` →
  `LoginUseCase` (no doubling), `loginUseCase` → `LoginUseCase`.
- **U2** fieldName contract unchanged: `login` → `login`,
  `sign_in_with_google` → `sign_in_with_google` (minimal-fix lock).
- **U3** DI plugin: `di/usecases/auth_flow_usecase_di.dart` emits
  `getIt<LoginUseCase>()`, `getIt<LogoutUseCase>()`.
- **U4** Orchestrator usecase generator: `final LoginUseCase _login;`,
  `final SignInWithGoogleUseCase _sign_in_with_google;`.

### Regression/Edge
- **E1** import path derivation unchanged (`domain/usecases/auth/login_usecase.dart`).
- **E2** already-correct Pascal tokens unaffected (guards passed pre-fix AND post-fix).

---

## Implementation Coverage Verification

✅ `StringUtils.normalizeUseCaseClassName` (lib/src/utils/string_utils.dart) —
   strips one trailing `UseCase`, Pascal-cases via `convertToPascalCase`
   (handles snake_case/camelCase), appends exactly one `UseCase`.
✅ `CommonPatterns.parseUseCaseInfo` (lib/src/core/builder/patterns/common_patterns.dart:195) —
   className normalized; fieldName/snake keep raw-token derivation.
✅ `TestBuilder.generateOrchestrator` (lib/src/plugins/test/builders/test_builder_orchestrator.dart) —
   fake class/interface/variable identifiers derived from the normalized name;
   class-declaration check in `test_builder_helpers.dart` now matches real
   declarations → existing usecases detected, placeholder path reserved for
   genuinely-missing sources.
✅ `DiPlugin._generateOrchestratorUseCaseDI` (lib/src/plugins/di/di_plugin.dart:1112) —
   registration type refs normalized.
✅ `CustomUseCaseGeneratorOrchestrator` (lib/src/plugins/usecase/generators/custom_usecase_generator_orchestrator.dart:44) —
   field/param types normalized.

## Mutation Testing (changed files, real runs, each mutant reverted after)

| Mutant | Mutation | Result | Killed by |
|---|---|---|---|
| M1 | normalizer returns base without `UseCase` suffix | **killed** — 10/12 fail | U1 (all token forms), A1–A4 transitively |
| M2 | `parseUseCaseInfo` reverts to raw-token ternary | **killed** — 4/12 fail | U1 lowercase/normalization tests, A1 |
| M3 | test-builder `interfaceName` back to `'${usecase}UseCase'` | **killed** — 2/12 fail | A3, A4 (placeholder warnings return, doubling returns) |

No surviving mutants. Restoration verified: suite back to 12/12 after each mutant.

---

## CLI Evidence (real `zfa make` runs, same session)

- **RED** (`tdd/red-repro-cli.log`): `zfa make Login --no-entity --domain auth
  --with=vpc,state,route,di,test --usecases=login,logout,sign_in_with_google,sign_in_with_apple,sign_anonymously
  --without=repository,datasource,cache,usecase` against a project whose
  usecases exist → 5× placeholder warnings; presenter
  `getIt<loginUseCase>()`; 10 bug-caused `dart analyze` errors.
- **GREEN** (`tdd/green-evidence.log`): same command re-run post-fix →
  0 placeholder warnings; presenter `getIt<LoginUseCase>()`;
  `class FakeLoginUseCase implements LoginUseCase`; bug-caused analyze errors
  **0**. In a fully-resolvable pure-Dart project (zuraffa path dep, `dart pub
  get`), the generated orchestrator usecase + DI registration analyze with
  **0 errors** (2 `unused_field` warnings are inherent to the generated
  TODO-stub orchestrator design, present regardless of this fix).

---

## Environmental Failures (pre-existing, unrelated to this change)

- `test/plugins/presenter/presenter_compile_test.dart` and
  `test/plugins/controller/controller_compile_test.dart` fail at `setUpAll`
  with `ProcessException: No such file or directory — flutter pub get`:
  they are `@Tags(['flutter'])` suites excluded from the standard lane per
  `dart_test.yaml` (`--exclude-tags "flutter || e2e"`) and require a Flutter
  SDK that is not installed in this environment.

## Verification Commands (exact)

```bash
dart analyze lib test                       # No issues found (baseline, unchanged)
dart analyze <changed files>                # No issues found
dart test test/regression/issue_1720_usecase_casing_dry_run_test.dart   # 12/12
dart test test/core/builder/patterns/ test/plugins/test/ test/regression/          # 78 pass
dart test test/plugins/presenter/ test/plugins/controller/                          # 8 pass, 2 flutter-tagged env failures
dart test test/plugins/di/ test/plugins/usecase/ test/plugins/state/               # 155 pass
dart test test/core/ test/utils/                                                    # 831 pass
dart format --output=none --set-exit-if-changed .   # 0 changed (exit 0)
```

Full-suite `dart test` was not run to completion in this environment
(exceeds 10-minute execution budget: the repo's heavy lanes spawn AOT
compilation + `dart pub get` subprocesses per spec). Per the change-scope
protocol, all suites touching the changed code paths were run and are green.
