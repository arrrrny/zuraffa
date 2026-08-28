# Bug Assessment: `zfa test` orchestrator (and repo/service) generation throws when dependency source files are absent

- **Slug**: test-command-orchestrator-test-composed
- **Created**: 2026-08-28
- **Source**: pasted text (automated triage, no human in the loop)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

```
Failing test (Linux): test/commands/test_command_test.dart:163
Test name: "TestCommand generates orchestrator test with composed usecases"
Assertion failure:
  Expected: true
    Actual: <false>
No extra output was captured in the run log. The test exercises the `zfa test` /
TestCommand generator and asserts a generated orchestrator test (with composed
usecases) is produced/valid.
Environment: Linux x64, Dart SDK 3.13.1. Reference: macOS suite = 1640 pass /
1 skip / 9 fail; this Linux run = 1681 pass / 1 skip / 8 fail.
```

## Symptom

`TestCommand.execute(...)` returns `GeneratorResult(success: false)` for the
orchestrator test case, so `expect(result.success, isTrue)` (test line 163)
fails with `Expected: true / Actual: <false>`. The generator throws while trying
to build a fake for a composed child use case whose source file does not exist
in the workspace. The same failure also breaks the two sibling tests
(lines 75 and 117) which depend on a repository / service source file that the
test does not write.

## Reproduction

1. `dart test test/commands/test_command_test.dart` (or just `-n "generates orchestrator test with composed usecases"`).
2. The `setUp` writes only `lib/src/domain/usecases/checkout/process_checkout_usecase.dart`
   (a use case composing `ValidateCartUseCase` + `CreateOrderUseCase`) into a temp
   workspace — the child usecase sources are intentionally not present.
3. The test invokes `TestCommand(...).execute(['ProcessCheckout', '--output', ..., '--domain', 'checkout', '--dry-run'])`.
4. `plugin.buildConfigFromUseCase` parses the file, detects composed use cases,
   returns an orchestrator `GeneratorConfig` with `usecases = [ValidateCart, CreateOrder]`.
5. `generate` → `isOrchestrator` is true → `generateOrchestrator` runs, which for
   each composed use case calls `discovery.findFileSync('validate_cart_usecase.dart')`
   → `null` → `_requireFakeClassForDependency(filePath: null)` throws `StateError`.
6. `TestCommand.execute` catches the exception and returns `success: false`.

Reproduced locally: all three `TestCommand` tests fail identically with
`Expected: true / Actual: <false>` (lines 75, 117, 163).

## Suspected Code Paths

- `lib/src/plugins/test/builders/test_builder_helpers.dart:112-141` — `_requireFakeClassForDependency` **throws** `StateError` when `filePath` is `null`. This is the proximate throw that flips `success` to `false`.
- `lib/src/plugins/test/builders/test_builder_orchestrator.dart:62-74` — for every composed use case it calls `discovery.findFileSync('${usecaseSnake}_usecase.dart')`; if the child source is absent it passes `null` and triggers the throw. Also emits `Fake${usecase}UseCase` (lines 67, 93, 104) while the test expects `Mock${usecase}UseCase`.
- `lib/src/plugins/test/builders/test_builder_custom.dart:69,91,115` — same `null`-path throw for missing repository / service / params sources; also emits `Fake*` while the test expects `Mock*`. Note line 23-28 already demonstrates the *intended* pattern: when the usecase file itself is missing, `generateCustom` prints a warning and returns a `skipped` `GeneratedFile` instead of throwing.
- `lib/src/plugins/test/builders/test_builder_polymorphic.dart:57-58` — same throw pattern for missing repository sources.
- `lib/src/plugins/test/test_plugin.dart:198-250` — `buildConfigFromUseCase` correctly infers the orchestrator config; not at fault.
- `lib/src/commands/test_command.dart:134-152` — `execute` wraps `plugin.generate` in try/catch and stores the error into `GeneratorResult(success: false, errors: [e.toString()])`; this is why the test sees `success: false` rather than an unhandled crash.
- Regression origin: commit `5b2655bf` "Remove mocktail; generate native zuraffa mocks in all tests (#524)" by Ahmet TOK, **2026-08-28** (today). It replaced `mocktail`-based `Mock*` generation (which needed no source files) with AST-parsed native `Fake*` generation that requires the dependency source file to exist on disk.

## Root Cause Hypothesis

PR #524 removed `mocktail` and switched the test generators to build fake classes
by AST-parsing the dependency's source file via `_requireFakeClassForDependency`.
Mocktail previously generated `MockXxx` mocks purely from type signatures and did
not need the source present, so `zfa test` worked even when a repository / service
/ child use case had not yet been generated. The new AST path hard-requires the
source to exist and **throws** when it is missing, instead of degrading gracefully
like `generateCustom`'s own usecase-file guard. Additionally the generated class
names changed from `Mock*` to `Fake*`, diverging from both the test expectations
(`MockUserRepository`, `MockValidateCartUseCase`, `MockCreateOrderUseCase`) and the
rest of the repo's convention (`${entityName}MockDataSource`, `${entityName}MockData`
in `test_builder_entity.dart`). Confidence: **high** — reproduced locally; the
throw path and the today's commit are both confirmed.

## Proposed Remediation

**Preferred**: Restore graceful degradation for missing dependency sources and keep
the `Mock*` naming:

- Make `_requireFakeClassForDependency` (and its callers) not throw when the source
  is absent. For an orchestrator that still needs concrete fake instances to
  construct the use case, emit a minimal `Mock{Name}` class that `implements` the
  interface with `UnimplementedError()` bodies (no AST parse required), so
  generation succeeds and the resulting test compiles/runs. For repo/service cases
  the existing `generateCustom` skip-guard pattern (line 23) is the right model —
  skip the fake + its injected variable rather than throw.
- Rename generated fake classes from `Fake*` to `Mock*` in
  `test_builder_orchestrator.dart`, `test_builder_custom.dart`, and
  `test_builder_polymorphic.dart` to match the `MockXxx` convention the tests and
  `test_builder_entity.dart` already use.

**Alternatives**:
- Revert #524's mocktail removal and restore `mocktail`-based `Mock*` generation
  (simplest, but undoes the "native mocks" intent and re-adds the `mocktail` dep).
- Have `buildConfigFromUseCase` / the test setup write the dependency sources first;
  undesirable because real `zfa test` users often generate a test before the
  dependency exists.

**Files likely to change**:
- `lib/src/plugins/test/builders/test_builder_helpers.dart` (null-safe fake generation)
- `lib/src/plugins/test/builders/test_builder_orchestrator.dart` (rename `Fake`→`Mock`, guard missing source)
- `lib/src/plugins/test/builders/test_builder_custom.dart` (rename `Fake`→`Mock`, reuse skip-guard)
- `lib/src/plugins/test/builders/test_builder_polymorphic.dart` (rename `Fake`→`Mock`, guard)

**Tests to add or update**:
- `test/commands/test_command_test.dart` already encodes the expected `Mock*` output
  and the "no dependency source present" scenario — keep it as the regression guard;
  it will pass once generation degrades gracefully and emits `Mock*`.
- Consider adding a unit test that asserts `zfa test` succeeds (and emits `Mock*`)
  for a use case whose repo/service/child sources are absent.

## Risks & Considerations

- Renaming `Fake*` → `Mock*` changes generated class names, but `Fake*` was only
  introduced today in #524, so the external blast radius is small; no released
  users depend on `Fake*` yet.
- Emitting `UnimplementedError()` placeholder fakes means the generated test will
  fail at runtime if the fake is exercised — acceptable for a *generated scaffold*
  and matches mocktail's prior behavior (mocks default to throwing).
- `zfa test` is a documented, commonly used command; this regression breaks a very
  common workflow (generate a test before its dependencies exist), so it should be
  fixed before the #524 change is considered stable.

## Open Questions

- [NEEDS CLARIFICATION]: Was the `Mock*` → `Fake*` rename in #524 intentional, or an
  oversight? The tests (and `test_builder_entity.dart`) expect `Mock*`, suggesting
  the rename should be reverted to `Mock*`.
- [NEEDS CLARIFICATION]: Should missing dependency sources cause a `skipped` file
  (like `generateCustom`'s usecase guard) or a best-effort placeholder `Mock*`? For
  orchestrators a placeholder is required to keep the generated test constructible.
