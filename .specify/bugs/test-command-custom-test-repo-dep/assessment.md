# Bug Assessment: `zfa test` custom-mode generation fails (success:false) when a use-case dependency source file is missing; test also expects stale `Mock*` fakes

- **Slug**: test-command-custom-test-repo-dep
- **Created**: 2026-08-28
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Failing test (Linux): `test/commands/test_command_test.dart:75`
Test name: "TestCommand generates custom test with repository dependency"
Assertion failure:
```
  Expected: true
    Actual: <false>
```
No extra output was captured in the run log. The test exercises the `zfa test` / TestCommand generator and asserts a generated test file (custom test with repository dependency) is produced/valid. Read the test at `test/commands/test_command_test.dart:75` to recover the exact expectation, then locate the suspected generator code in `lib/src`.
Environment: Linux x64, Dart SDK 3.13.1. Reference: macOS suite = 1640 pass / 1 skip / 9 fail; this Linux run = 1681 pass / 1 skip / 8 fail.

## Symptom

`zfa test` custom-mode generation returns `GeneratorResult(success: false)` — i.e. no test file is produced — when the use case under test references a dependency (repository / service / composed use case) whose source file is not present in the project. In the failing test the temp workspace contains only `fetch_user_usecase.dart`; the custom-test builder needs `user_repository.dart` to AST-parse the `UserRepository` interface and throws a `StateError` when it is absent, which `TestCommand.execute` swallows into `success: false`.

## Reproduction

1. Run `dart test test/commands/test_command_test.dart`.
2. The `TestCommand` group writes a use-case file `domain/usecases/account/fetch_user_usecase.dart` (class `FetchUserUseCase extends UseCase<User, NoParams>` with `final UserRepository _repository;`, no `user_repository.dart`).
3. It invokes `TestCommand(TestPlugin(...)).execute(['FetchUser', '--output', <dir>, '--domain', 'account', '--dry-run'], exitOnCompletion: false)`.
4. `expect(result.success, isTrue)` fails: actual `false`.

Note: the same `success == false` failure also reproduces for the "stream test with service dependency" (`test_command_test.dart:117`) and "orchestrator test with composed usecases" (`:163`) cases in the same file — all three custom-mode tests are broken by the same root cause.

## Suspected Code Paths

- `lib/src/plugins/test/builders/test_builder_helpers.dart:112-141` — `_requireFakeClassForDependency` throws `StateError('Cannot generate $className: source for $interfaceName was not found.')` when `filePath == null`. This is the throw that propagates into a failed result.
- `lib/src/plugins/test/builders/test_builder_custom.dart:80-100` — the repository loop calls `_requireFakeClassForDependency(className: 'FakeUserRepository', interfaceName: 'UserRepository', filePath: discovery.findFileSync('user_repository.dart')?.path)`. In the test workspace the repository file does not exist, so `filePath` is null → throws.
- `lib/src/plugins/test/builders/test_builder_custom.dart:102-124` — the analogous service branch (same guard) for the stream-service test case (`order_service.dart`).
- `lib/src/plugins/test/builders/test_builder_orchestrator.dart:62-74` — the orchestrator branch calls the same guard for each composed use-case file (`<snake>_usecase.dart`), which is also absent in the test workspace.
- `lib/src/plugins/test/builders/test_builder_polymorphic.dart:55-58` — polymorphic builders use the same guard (same latent exposure, not exercised by the reported test).
- `lib/src/commands/test_command.dart:134-152` — `plugin.generate(config)` is wrapped in try/catch; the thrown `StateError` is caught and returned as `GeneratorResult(success: false, errors: [e.toString()])`. The test does not inspect `errors`, so the only visible symptom is `success == false`.
- `lib/src/plugins/test/test_plugin.dart:198-250` — `buildConfigFromUseCase` infers `repo: 'UserRepository'` from the use-case source (regex `final\s+(\w+)Repository\s+(\w+)`), selecting the custom builder and routing into the repo-fake generation path.

### Secondary defect (latent — would fail even if `success` were true)

- The generators emit `Fake*` fakes: `test_builder_custom.dart:92` (`FakeUserRepository`), `:116` (`FakeOrderService`), and `test_builder_orchestrator.dart:67` (`FakeValidateCartUseCase`/`FakeCreateOrderUseCase`). The test assertions at `test/commands/test_command_test.dart:78` (`class MockUserRepository`), `:120` (`class MockOrderService`), `:166` (`class MockValidateCartUseCase`), `:167` (`class MockCreateOrderUseCase`) expect `Mock*` prefixes. The suite predates the generator's `Fake*` refactor (see `test_builder_helpers.dart:56` "Fake{Name}" and the `#354` Flutter/pure-Dart fakes work) and is stale. Even after the throw is fixed, these content assertions will still fail.

## Root Cause Hypothesis

The custom/orchestrator/polymorphic test builders were hardened during the `Fake*` refactor so that every dependency interface must be AST-parseable before a `Fake` is emitted (`_requireFakeClassForDependency`, throwing on a missing source file). This is correct for real projects where `repository`/`service`/`usecase` files already exist, but it is too strict for the `zfa test` workflow and the test harness: it throws, and `TestCommand.execute` swallows the exception into `success: false` with no actionable diagnostic, whenever a dependency source file is absent. Combined with stale `Mock*` content assertions in `test_command_test.dart`, the three custom-mode tests are broken. Confidence: high (verified by running the suite — all three tests fail with `success == false`; the throw site and the `Fake`/`Mock` mismatch are both present in source).

## Proposed Remediation

**Preferred**: Make dependency-fake generation tolerant of a missing source file.

- (a) Generator: when `filePath == null` (or the interface is not declared in the file), do not throw. Either (i) emit a best-effort stub `Fake` and record a clear warning in `GeneratorResult.errors` / `print`, keeping `success: true`; or (ii) if dependency sources are genuinely required, raise a structured, human-readable error instead of a swallowed `success: false`. (i) keeps generation usable; (ii) at least makes the failure visible. Because a compilable `implements` needs member signatures, a stub fake needs a documented fallback (known-method set or `UnimplementedError` bodies).
- (b) Test + harness: update `test/commands/test_command_test.dart` to also write the dependency source files (`user_repository.dart`, `order_service.dart`, the composed `validate_cart_usecase.dart` / `create_order_usecase.dart`) into the temp workspace so AST parsing succeeds, and change the `Mock*` content assertions to `Fake*`. This is the minimal change to green the suite and matches real project layout.

The robust, low-blast-radius fix is (a) (usable result + clear warning) paired with (b) for the suite. Do not change the `Fake*` naming convention itself — that would be a larger, intentional API change.

**Alternatives**:
- Only fix the test (option b) and leave the generator throwing: makes the suite pass but keeps the opaque `success: false` failure mode for real users who run `zfa test` before a dependency file exists.
- Revert the `Fake*` refactor to the old `Mock*` behavior: larger, likely unintended regression of the #354 fakes work.

**Files likely to change**:
- `lib/src/plugins/test/builders/test_builder_helpers.dart` (soften/replace the `StateError` throw in `_requireFakeClassForDependency`).
- `lib/src/plugins/test/builders/test_builder_custom.dart`, `test_builder_orchestrator.dart`, `test_builder_polymorphic.dart` (consistent missing-file handling).
- `test/commands/test_command_test.dart` (add dependency source files; change `Mock*` → `Fake*` assertions).

**Tests to add or update**:
- Update the three custom-mode tests in `test/commands/test_command_test.dart` (repo / service / orchestrator) as described.
- Add a unit test asserting that `zfa test` for a use case whose dependency source is absent still returns `success: true` (or a clearly-messaged error), locking in the regression fix.

## Risks & Considerations

- Behavior change: emitting a stub fake without the interface source may produce non-compiling generated tests if members are unknown — must be documented.
- `Fake` vs `Mock` convention: confirm `Mock*` was intentionally retired; if other tests/docs reference `Mock*` fakes, update them together.
- The command currently swallows exceptions; any fix should surface a diagnostic via `GeneratorResult.errors` / `print` so callers/tests can distinguish "generated with warnings" from "failed".

## Open Questions

- [NEEDS CLARIFICATION: was the `Mock*`→`Fake*` rename intentional, and should `zfa test` require dependency source files to exist, or generate best-effort stubs?]
- [NEEDS CLARIFICATION: in a real project, is `user_repository.dart` guaranteed to exist when `zfa test` runs for its use case?]
