# Bug Test Notes: 1720-vpc-usecase-casing-dry-run

- **Slug**: 1720-vpc-usecase-casing-dry-run
- **Test file**: `test/regression/issue_1720_usecase_casing_dry_run_test.dart`
- **Cycle evidence**: ./tdd/cycle-log.md (red → green → mutation)
- **Raw logs**: ./tdd/red-evidence.log, ./tdd/red-repro-cli.log, ./tdd/green-evidence.log

---

## Strategy

One regression suite drives the public plugin APIs (no string-template
coupling) against temp projects whose usecases already exist on disk — the
issue's repro state. Every token form from the issue's table is covered at
every fixed site.

## Behaviors → Tests (see tdd/test-list.md for the full matrix)

- **parseUseCaseInfo** (6 tests): `login` → `LoginUseCase`;
  `sign_in_with_google` → `SignInWithGoogleUseCase`; `LoginUseCase` not
  doubled; `loginUseCase` normalized; fieldName contract unchanged for
  `login` and `sign_in_with_google`.
- **Presenter** (2 tests): DI-mode presenter emits `getIt<LoginUseCase>()`,
  `late final SignInWithGoogleUseCase _sign_in_with_google;`, no mangled refs;
  full-class-name tokens not doubled; import path unchanged.
- **Test builder** (2 tests): real fakes for existing usecases
  (`class FakeLoginUseCase implements LoginUseCase`) with zero `placeholder`
  warnings captured via a print-intercepting Zone; full-class-name tokens not
  doubled.
- **DI plugin** (1 test): `di/usecases/auth_flow_usecase_di.dart` emits
  `getIt<LoginUseCase>()`.
- **Orchestrator usecase generator** (1 test):
  `final LoginUseCase _login;`, `final SignInWithGoogleUseCase _sign_in_with_google;`.

## Red → Green

- RED: 8 failed / 4 passed (guards) — tdd/red-evidence.log; CLI repro with
  correct fixtures independently reproduced both symptoms —
  tdd/red-repro-cli.log.
- GREEN: 12/12 — tdd/green-evidence.log.
- Mutation check: 3/3 mutants killed (normalizer suffix drop; parse ternary
  revert; test-builder interface revert) — see tdd/verification.md.

## Honest notes

- Two RED-phase fixture files initially declared `class Login` instead of
  `class LoginUseCase`; they were corrected during the cycle. The RED
  attribution does not depend on them: the CLI repro log (correct fixtures)
  independently demonstrates both the mangled refs and the spurious
  placeholder warnings pre-fix.
- `presenter_compile_test.dart` / `controller_compile_test.dart`
  (`@Tags(['flutter'])`) cannot run here — no Flutter SDK in this
  environment; excluded from the standard lane by `dart_test.yaml`.
- Suites run green in this session: patterns + test-plugin + regression
  (78), presenter + controller non-flutter (8), di + usecase + state (155),
  core + utils (831). The full `dart test` lane exceeds the environment's
  execution budget (heavy e2e lanes spawn AOT + pub-get subprocesses).
