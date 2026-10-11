# Spec 1117 — [ENGINE] Trust-tier generator tests for UseCase/Service/Repository/DataSource/MockProvider

Issue: https://github.com/arrrrny/zuraffa/issues/1117
Branch: `spec/1117-engine-trust-tier-tests`

## Problem

#1003 (closed without merge) targeted the UI trust tier
(view/controller/presenter/state/cache). The 005-login-engine pilot
exposed that the ENGINE trust tier is even more under-tested: UseCase,
Service, Repository, DataSource, MockProvider — the five generators
every `zfa make engine` cycle run exercises. The pilot relied on these
generators' correctness and found at least three subtle bugs by
hand-reading the generated code:

- `login_usecase_di.dart` — generated, NOT idempotent, caught by hand
  (the second `setupDependencies` call threw "already registered";
  fixed by #1102's unregister-first guard, but never pinned by a test
  in the generator's own tier).
- `auth_mock_provider.dart` — generated, worked (by luck, not by
  test).
- `skin_harness.dart` — the pilot hand-wrote `_FailingAuthService` to
  test the failure path, exactly the double a `--fail` preset (#1110)
  now owns; the test for that double is the test for the UseCase
  generator's failure-path contract.

The engine is the locomotive of the TDD pipeline: every engine cycle
run exercises these generators, so a bug in any of them is a systemic
risk. `test/plugins/use_case/` did not exist; the existing
`usecase`/`service`/`repository`/`datasource`/`mock` dirs carry
plugin-tier and spec-1003 coverage, but nothing pins the ENGINE preset
shape (the custom-usecase/service chain the pilot drove), the
compile bar for the full engine method set, or the behavioral
contracts.

## What was built

One test tier per generator, under `test/plugins/<name>/`
(`use_case` — new —, `service`, `repository`, `datasource`, `mock`),
each generator getting 2+ tests:

1. **Structural** — generate into a throwaway dir via the in-process
   plugin API with the engine preset's config shapes; assert file
   count + key content (class name, imports, method signatures,
   expected stub body for the mock).
2. **Compile** — write into a self-contained pure-Dart fixture package
   (path dependency on this repo), `dart pub get`, `dart analyze
   --no-fatal-warnings lib` → exit 0.
3. **Behavioral (UseCase — the most complex)** — generate LoginUseCase
   + AuthService + DI into the fixture, then EXECUTE an inner
   `package:test` suite through the tdd-profile-resolved runner
   (issue #1044 — never a literal `dart test`):
   (a) returns the Service's `Future<T>` (the exact instance surfaces
   as `Success`), (b) surfaces `Result.failure` when the Service
   throws, (c) the failure path goes through the same sealed
   `AppFailure` (the pilot's `_FailingAuthService` shape:
   `ServerFailure` surfaces AS `ServerFailure`), (d) the generated DI
   registration is idempotent — `registerLoginUseCase(getIt)` twice,
   unregister-first.
4. **Behavioral (MockProvider — second most complex)** — generate
   AuthMockProvider and EXECUTE it: (a) every method satisfies the
   contract (`isA<AuthService>` + returns the entity), (b) the delay
   constructor parameter is honored (the certified 100 ms default;
   `Duration.zero` short-circuits it), (c) the per-method fixture
   selector routes on the params discriminator (#1034).
5. **Repository + DataSource** — the append/sync/simple variants each
   get a 1-test "generates the right CRUD shape" test pinned to the
   engine preset's default method set
   (get/getList/create/update/delete), plus a compile bar for the full
   set (including the zorphy `update`/Patch member).

Shared plumbing lives in `test/helpers/engine_tier_fixture.dart`
(fixture package creation, entity scaffolding, the #1044
profile-resolved runner).

## Why the fixture scaffolds what it scaffolds (disclosed, not hidden)

- The fixture entities are named `AuthSession`/`LoginParams` (not
  `Session`) because zuraffa's public barrel exports its own `Session`
  class — an entity named `Session` produces `ambiguous_import`
  diagnostics in any consumer.
- The repository/datasource compile fixtures hand-define the zorphy
  `<Entity>Patch` type (a `build_runner` product in real projects) as
  pre-existing fixture state, mirroring `zfa entity create --build`.
- The mock fixtures hand-write the mock-data pair the provider imports
  (target entity + params entity) and hand-augment the target's
  `forMethod` selector — the sanctioned AUGMENTED escape hatch
  (mock-data VALUES only; provider ROUTING stays 100% generated, per
  #1034).
- The provider generation for the fixture-selector lane runs with
  `force: false` so the pre-existing (augmented) mock data survives —
  skip-if-exists is the documented semantics.

## Success criteria

1. 5 engine trust-tier generators, each with 2+ tests in
   `test/plugins/<name>/`, all green. (use_case 5, service 2,
   repository 4, datasource 4, mock 5 — 20 tests total.)
2. `flutter test test/plugins/use_case test/plugins/service
   test/plugins/repository test/plugins/datasource
   test/plugins/mock` exits 0.
3. The UseCase behavioral test catches the setupDependencies
   non-idempotency bug (asserts the unregister-first pattern,
   structurally + executably).
4. The MockProvider behavioral test catches the per-method fixture
   selector regression (per #1034), structurally + executably.

## Related

- #1013 (ENGINE-PIPELINE, parent), #1109 (engine v2), #1110
  (cert-gate), #1003 (CLOSED, not merged — the UI trust-tier
  predecessor), #1034/#1035 (mock provider bugs these tests would have
  caught), #1044/#1045 (the preflight `dart test` literal is wrong —
  the runner must resolve from the tdd profile).
