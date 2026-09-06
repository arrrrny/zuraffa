# TDD Verification — feature `1117-engine-trust-tier-tests`

Written from the ACTUAL runs performed on this branch (every command below
was executed; outputs are quoted from the transcripts, not asserted).
Toolchain: Dart 3.13.2 (stable) / Flutter 3.47.2 on linux_x64
(`flutter --version`; Dart via the Flutter SDK's bundled toolchain).

## Gate

- gate: `passed`
- analyze: `dart analyze lib test` → **0 errors, 0 warnings** (104
  info-level lints, all pre-existing in untouched files —
  `lib/tdd/0966-*` subject naming and type-literal idioms; the
  full-repo `dart analyze` also reports 31 errors confined to
  `examples/todo_tdd/` — pre-existing, untouched by this branch)
- fast suite (chunked): the environment reaps detached processes, so
  the run was driven in seven foreground ranges via
  `tools/run_chunks_range.sh` (1-1, 2-15, 16-30, 31-45, 46-60, 61-75,
  76-91) → **91/91 chunks, 0 failed, 3,573 tests passed** (84 chunks
  reported `All tests passed!`, 6 reported the runner's SKIP
  "no fast-tier tests", chunk 1 ran in the foreground first: +233
  `All tests passed!`)
- success-criteria command (the exact five-dir invocation):
  `flutter test test/plugins/use_case test/plugins/service
  test/plugins/repository test/plugins/datasource
  test/plugins/mock` → **+270: All tests passed!**, exit 0 (01:35
  wall)
- rebase note: master advanced (PRs #1205/#1212/#1213 merged after the
  branch started; the new commits touch `test/plugins/slice/` and
  workflow tooling — none of the five generator surfaces this tier
  covers), so the branch was rebased onto the new tip and the gate
  re-proved there: `dart analyze lib test` → 0 errors/warnings (104
  info), and the same five-dir command → **+270: All tests passed!**,
  exit 0 (01:40 wall)
- format: `dart format .` → formatted this spec's 13 new files (+
  one leftover probe, deleted); re-run → 0 changed;
  `git diff --stat` → empty (zero remaining formatting diffs)

## Red → green evidence (the loop, honestly)

### RED (reproduced on the pre-change tree)

```
$ flutter test test/plugins/use_case
  Failed to load "/home/z/my-project/zuraffa/test/plugins/use_case": Does not exist.
  00:00 +0 -1: Some tests failed.
  Failing tests:
    /home/z/my-project/zuraffa/test/plugins/use_case: loading .../test/plugins/use_case
$ ls test/plugins/ | grep -c use_case        → 0
```

The engine trust tier had zero engine-preset-shaped tests: the
existing `usecase`/`service`/`repository`/`datasource`/`mock` dirs
carry plugin-tier and spec-1003 (UI-tier lineage) coverage — nothing
pins the engine preset's custom-usecase/service chain (the
005-login-engine pilot config), the compile bar for the full engine
method set, or the behavioral contracts below.

### GREEN (the same commands on this branch)

1. **Per-generator tiers (all green, per-file runs):**

   ```
   dart test test/plugins/use_case/                                  → 5/5
     use_case_engine_structural_test.dart   (2: usecase shape; DI unregister-first)
     use_case_engine_compile_test.dart      (1: analyze zero errors)
     use_case_engine_behavior_test.dart     (2: inner suite +4 under profile runner; analyze)
   dart test test/plugins/service/service_engine_*                  → 2/2
   dart test test/plugins/repository/repository_engine_*            → 4/4
   dart test test/plugins/datasource/datasource_engine_*            → 4/4
   dart test test/plugins/mock/mock_provider_engine_*               → 5/5
   ```

2. **The UseCase behavioral suite (the pilot's skin-harness lesson,
   executed):** the inner fixture suite
   (`test/login_engine_behavior_test.dart` in a throwaway package with
   a path dependency on this repo) runs through the tdd-profile
   resolved runner and prints:

   ```
   +4: All tests passed!
     (a) returns the Service's Future<T> - the exact instance surfaces as Success
     (b) surfaces Result.failure when the Service throws
     (c) the failure path goes through the same sealed AppFailure (the pilot's _FailingAuthService shape)
     (d) the generated DI registration is idempotent - registerLoginUseCase twice, unregister-first
   ```

   The failing double is the pilot's exact shape: `throw
   AppFailure.server('invalid credentials', statusCode: 401)` — and
   (c) asserts the surfaced failure is `isA<ServerFailure>` with the
   same message (the sealed type travels unwrapped, not generically
   re-wrapped).

3. **The MockProvider behavioral suite:**

   ```
   +4: All tests passed!
     (a) every method satisfies the contract - the provider is an AuthService
     (b) the delay constructor parameter is honored (the certified 100 ms
         default; Duration.zero short-circuits it)
     (c) the per-method fixture selector routes on the params discriminator (#1034)
     (d) the stub bodies log through the framework Loggable mixin
   ```

4. **Issue #1044 discipline (no literal `dart test`):** every
   behavioral spawn resolves its argv through
   `SingleTestRunner().loadFileTemplate(workingDirectory: repoRoot)` →
   the profile's `file:` key (`dart test {file}` today) →
   `SingleTestRunner.splitCommand`. Grep proof over the new tier:

   ```
   $ grep -rn "dart test\|dart', 'test" test/plugins/use_case test/plugins/mock/*engine* test/helpers/engine_tier_fixture.dart
     → matches only inside prose comments ("never a literal dart test");
       no spawn site hard-codes the runner
   ```

## Mutation-style strength probes (test-first discipline)

The spec demands the two named bug classes be CAUGHT, not just
described. Each probe mutated ONE generator on this branch, re-ran the
new tier, and reverted (verified byte-identical to HEAD afterwards):

1. **The setupDependencies non-idempotency bug (the pilot's lesson
   4).** Mutation: `RegistrationBuilder.buildRegistrationFile` with the
   guard emission removed
   (`..statements.addAll(registeredTypes.map(unregisterFirstGuard))`
   deleted) → the pre-change `login_usecase_di.dart` shape (no
   `if (getIt.isRegistered<LoginUseCase>())` guard):

   ```
   $ dart test test/plugins/use_case/use_case_engine_structural_test.dart
     the generated DI file registers LoginUseCase through the
     unregister-first pattern (the pilot's non-idempotency bug pinned)  [E]
   → exit 1 (test FAILED — the bug is caught)   … generator reverted
   ```

   The executable half is pinned by the inner behavioral test (d):
   `registerLoginUseCase(getIt)` twice + `getIt<LoginUseCase>()` — the
   exact sequence that threw "already registered" in the pilot.

2. **The per-method fixture selector regression (#1034).** Mutation:
   `_perMethodCannedValue` forced to return `null` (selector threading
   disabled → the single-fixture `sampleAuthSession` shape):

   ```
   $ dart test test/plugins/mock/mock_provider_engine_structural_test.dart
     #1034: threads the per-method fixture selector
     (AuthSessionMockData.forMethod(params.kind)) …               [E]
   → exit 1 (test FAILED — the regression is caught) … generator reverted
   ```

   The behavioral half (c) executes the routed fixtures (`admin` →
   `admin-token`, `guest` → `guest-token`) through the generated
   provider, so a silent fall-back to the default fixture fails it.

## Pre-existing quirks disclosed (not fixed by this spec, out of scope)

- The generated custom-usecase mock provider imports the params
  entity's mock-data file (`login_params_mock_data.dart`), which the
  mock chain itself never generates in that lane — the fixtures
  hand-write it as pre-existing project state (documented in
  `test/helpers/engine_tier_fixture.dart` and the spec). A future spec
  may want the entity-graph builder to seed it.
- `examples/todo_tdd/` carries 31 pre-existing analyze errors (needs
  `build_runner` outputs) — identical on master; untouched here.
- Under `flutter test`, tests that spawn
  `Platform.resolvedExecutable run …` (e.g.
  `test/plugins/usecase/usecase_command_grammar_test.dart`) hang:
  resolvedExecutable is `flutter_tester` under the Flutter harness.
  None of the five target dirs use that pattern (verified by grep);
  the new tier spawns plain `dart` and is harness-agnostic.

## Acceptance-criteria coverage

| Issue requirement | Covered by | Status |
| --- | --- | --- |
| 5 engine trust-tier generators, each with 2+ tests in `test/plugins/<name>/`, all green | use_case 5, service 2, repository 4, datasource 4, mock 5 (20 tests; chunked fast suite + flutter five-dir run both green) | PROVED |
| `flutter test test/plugins/use_case test/plugins/service test/plugins/repository test/plugins/datasource test/plugins/mock` exits 0 | +270: All tests passed!, exit 0 (transcript above) | PROVED |
| The UseCase behavioral test catches the setupDependencies non-idempotency bug (asserts the unregister-first pattern) | mutation probe 1 (structural FAIL under guard removal) + behavioral test (d) (executable double-registration) | PROVED |
| The MockProvider behavioral test catches the per-method fixture selector regression (per #1034) | mutation probe 2 (structural FAIL under threading removal) + behavioral test (c) (executable routing) | PROVED |
| Structural test: temp dir + engine preset shapes, file count + key content (class name, imports, method signatures, expected stub body for mock) | use_case_engine_structural (2), service_engine_structural (1), repository_engine_crud_shape (3), datasource_engine_crud_shape (3), mock_provider_engine_structural (2) | PROVED |
| Compile test: temp + `dart analyze`, zero errors (runner resolved from the tdd-profile per #1044) | one compile test per generator (5); every behavioral spawn resolves the runner via SingleTestRunner | PROVED |
