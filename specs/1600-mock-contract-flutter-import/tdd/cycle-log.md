# TDD Cycle Log — Spec 1600 (append-only)

## Baseline (pre-loop)

- Feature: specs/1600-mock-contract-flutter-import (issue #1600, #1513 sibling).
- Suite state before any behavior work: fast tier green on `master`
  (b621f38b); the defect lives in generated-project output, not this repo's
  suite — the repo has no Flutter-SDK dependency (tdd-profile).
- Test list: 10 behaviors (B1–B10). Guards: B2 (golden byte-stability,
  green pre-fix by design). Assertion reds expected pre-fix: B5, B8 (the
  defect reproduced in-process through the real create/certify paths).
  Missing-API reds expected pre-fix: B1, B3, B4, B6, B7. Slow tier: B9,
  B10 (skip honestly without the Flutter SDK; run locally — SDK installed).

## Cycle C1 — the mock contract writer honors the host test framework

- **RED** (pre-fix, recorded before the fix):
  - B2 FIRST, alone: `dart test test/plugins/mock/certification/bug_1600_mock_contract_flutter_import_test.dart`
    → `+1: All tests passed!` — the golden guard is GREEN on the current
    binary (live default render == committed pre-fix golden
    `test/fixtures/baseline_outputs/bug_1600_mock_contract_default_render.txt`,
    captured from the unmodified binary via a throwaway capture script,
    deleted after use).
  - B1 added: same file → **load-error red for the right reason** —
    `No named parameter with the name 'flutterTest'` at
    `MockContractTestWriter(flutterTest: ...)` (the missing API surface
    itself; same red shape as #1513's writer reds).
- **GREEN**: `mock_contract_test_writer.dart` — `flutterTest` field
  (default false) + `testImport` getter; `render()` interpolates the
  resolved import. `+8: All tests passed!` (B1+B2 + the existing
  `mock_contract_test_writer_test.dart` suite untouched).

## Cycle C2 — the sandbox proves a Flutter-shaped test with the Flutter toolchain

- **RED**: B3+B4 added → load-error red for the right reason —
  `Member not found: 'MockCertificationSandbox.pubspecFor'`,
  `Member not found: 'MockCertificationSandbox.toolchainFor'`,
  `No named parameter with the name 'flutterTest'`.
- **GREEN**: `mock_certification_sandbox.dart` — `flutterTest` (default
  false); branched manifest (`pubspecFor`) + toolchain selection
  (`toolchainFor` / `toolchain`); every exec site and `runner` field now
  records the toolchain that ran. Fast suites green (certification dir +
  receipt + registry, 41 tests).

## Cycle C3 — the certifier is shaped by the host; both capabilities thread it

- **RED**: B5/B6/B8 added (`bug_1600_certifier_for_project_test.dart`) →
  load-error red for the right reason —
  `Member not found: 'MockCertifier.forProject'`,
  `Member not found: 'MockCertificationSandbox.flutterOnPath'`.
- **GREEN**: `mock_certifier.dart` — `forProject(projectRoot)` factory
  (pubspec read + `DependencyWirer.isFlutterProject`, unreadable/absent →
  pure-Dart default); `create_mock_capability.dart` and
  `certify_mock_capability.dart` construct through it; the certify
  capability's degradation path (probe false → exit 0, nothing written,
  warning naming the fix) proven in-process inside B8's drive of the REAL
  `CertifyMockCapability.run`. `+3: All tests passed!`

## Cycle C4 — honest degradation + red-stays-red guards

- **RED**: B7 added (probe seam semantics + stubbed-red proof) → compile
  red while the seam shape settled (probe scan + receipt shape), then:
- **GREEN**: `flutterExecutableOnPath` pure PATH scan + assignable
  `flutterOnPath` seam; the capability-level checks (both capabilities)
  consult it before the sandbox runs; the sandbox keeps an honest
  defense-in-depth refusal for direct library use. `+4: All tests passed!`

## Cycle C5 — the live Flutter-toolchain proof (slow tier, local)

- **RED→fix loops** (real machinery, real SDK):
  1. The sandbox Flutter manifest initially declared
     `flutter_test` AND `test: ^1.25.0` → `flutter pub get` in the sandbox
     is UNSOLVABLE: flutter_test pins matcher 0.12.20 / test_api 0.7.12 and
     no published `test` version resolves beside them in the framework's
     graphql graph — the same #1189 conflict. Fixed: the Flutter branch
     declares flutter_test only (pinned by B3).
  2. **Pre-existing pubspec regression surfaced by the red**: the working
     tree carried an uncommitted move of `test: ^1.32.0` from
     dev_dependencies to a REGULAR `test: any` dependency — exactly the
     issue #1189 failure mode its own comment documents ("As a REGULAR
     dependency it made every Flutter consumer unresolvable"). It made the
     FIXTURE's own `flutter pub get` fail too. Reverted to the committed
     #1189 state (flagged for the maintainer + the PR description).
  3. The stripped-PATH degradation proof needed a faithful environment:
     dart and flutter share a bin dir here, so the test mirrors the real
     PATH minus `flutter*` executables, and resolves the fixture as a
     pure-Dart project before swapping in the Flutter pubspec (a host
     without the SDK cannot have run `flutter pub get`; the degradation
     contract promises a GENERATION-governed exit, so the generation gate
     must be green).
  4. B10 needed the same package-config setup (its `mock create` must pass
     the generation structural gate before the drift can be proven).
- **GREEN**: `dart test --preset=integration test/integration/bug_1600_mock_certification_flutter_e2e_test.dart`
  → `+3: All tests passed!` (~7 min, Flutter 3.47.4):
  - B9: fixture `flutter pub get` → real CLI `mock create Login
    --certify` → exit 0, receipt all-satisfied, committed test imports
    flutter_test (never package:test) AND passes `flutter test
    test/mock/login/login_mock_contract_test.dart` in the host — the
    #1600 symptom (the xzx dogfood load error) is gone.
  - B10: interface drift → `mock certify Login` → exit 3, stderr names
    the drift, the on-disk receipt honestly records unsatisfied methods.
  - Degradation: stripped PATH → ⚠️ warning naming the missing SDK + fix,
    NO receipt, exit 0 (generation-governed).
- Dogfood repro (manual, /tmp fixture): same shape as the xzx evidence in
  the issue — the committed contract test passes 4/4 under the host
  runner.

## Refactor

None needed beyond the cycle fixes: the flag mirrors the #1513 shape, the
sandbox keeps ONE code path with a swappable manifest + toolchain, and the
factory is the single host-detection seam for both capabilities.

## Mutation sampling (rubric fallback, no CI mutation gate)

- M1 — threading removed (`MockCertifier()` instead of
  `MockCertifier.forProject(projectRoot)` in a capability): B5/B8 red
  (the certified source goes back to package:test) → **killed**.
- M2 — default drift is covered by B2's byte-for-byte golden (any change
  to the default render fails SC-1 immediately).
- M3 — degradation removed (the capability check deleted): the B8
  in-process capability drive reds (receipt would be attempted / exit
  drifts) → **killed**.
