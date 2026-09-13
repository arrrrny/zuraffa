# Research — Spec 1600

All unknowns were resolved from the repo itself (issue #1600 evidence, the
#1513 sibling implementation, and the current mock-lane sources). No open
questions remain.

## D1 — Host detection signal

- **Decision**: read the project pubspec and reuse
  `DependencyWirer.isFlutterProject` (YAML `dependencies: flutter:` key).
- **Rationale**: the exact signal the tdd gen lane already resolves once per
  invocation (#1351/#1458); YAML-only, needs no Flutter SDK, keeps every
  lane's answer identical. `CreateMockCapability._certify` already resolves
  `projectRoot = Directory.current.path`, so the pubspec path is trivially
  available; `CertifyMockCapability.run` resolves `projectRoot` from
  `--project` / `ProjectRoot.find` the same way.
- **Alternatives considered**: spawning `flutter --version` (slow, requires
  SDK just to decide an import); keying off the committed test's existing
  import (a stale pure-Dart import must not pin the future — re-pin must be
  able to FIX it); annotating the receipt (schema change, out of scope).

## D2 — Writer flag shape

- **Decision**: `MockContractTestWriter({this.flutterTest = false})` + a
  public `testImport` getter, mirroring `ContractTestWriter`'s #1513 shape;
  `render()` interpolates `import '$testImport';`.
- **Rationale**: one defect class, one remedy shape — reviewers of #1513
  already know this diff. Default `false` keeps the pure-Dart render
  byte-identical (FR-006).
- **Alternatives considered**: a renderer-argument (every call site must
  thread it; drift-prone); post-processing the rendered string (fragile).

## D3 — Sandbox Flutter mode

- **Decision**: `MockCertificationSandbox({this.flutterTest = false})`;
  when set, the sandbox pubspec gains `flutter: sdk: flutter` +
  `flutter_test: {sdk: flutter}` (dev_deps keep `test` for parity of the
  runner engine) and the three steps run through the `flutter` executable:
  `flutter pub get --offline` → online fallback → `flutter analyze .` →
  `flutter test <rel> --reporter json`. `MockCertificationRun.runner`
  records `flutter` (currently hardcoded `'dart'` at four return sites).
- **Rationale**: `dart pub get` refuses Flutter SDK deps and the plain Dart
  VM cannot load `dart:ui`, so a flutter_test-importing test can ONLY be
  proven by the Flutter toolchain. Reusing the same timeouts/offline-first/
  JSON parsing keeps one code path with a swappable executable + manifest.
- **Alternatives considered**: keeping the sandbox Dart-only (moves the red
  from the host suite to `mock create --certify` — the same bug in a
  different hat; rejected); sandboxing with a fake flutter_test shim
  (certification would no longer be live — rejected on honesty grounds).

## D4 — Missing-Flutter-SDK degradation

- **Decision**: the capability detects SDK availability (scan PATH for a
  `flutter` executable file) BEFORE running the sandbox when the host is
  Flutter; if absent, mirror the spec-1110 `certSandboxUnresolved`
  precedent: warning naming the precondition + fix, no receipt written,
  `success: true` with the same `certSandboxUnresolved` marker (exit stays
  generation-governed). The sandbox, if reached without the SDK, returns
  the unresolved-run shape (analyzeErrors=1 style honest non-proof) with a
  log naming the gap — but the capability path prevents ever hitting that
  in the CLI flow.
- **Rationale**: precedent is already in the same function for the
  framework root; an environment-dependent proof that cannot run is not a
  red contract. The un-certified state stays loud (no receipt → downstream
  cert-gates refuse).
- **Alternatives considered**: exit red (would break CI dart lanes for
  Flutter projects — the regression FR-005 exists to prevent); silently
  skipping (dishonest).

## D5 — Regression coverage placement

- **Decision**: unit behaviors in `test/plugins/mock/` (fast tier,
  Flutter-SDK-free); the live `flutter`-toolchain certification e2e in
  `test/integration/` (tagged `slow, integration`, like
  `mock_certification_e2e_test.dart`), executed locally (Flutter SDK
  installed at `/usr/local/bin/flutter`) but excluded from the fast suite
  and from CI's dart lane.
- **Rationale**: the tdd-profile pins `dart test` fast tier as CI-facing;
  the repo's own CI has no Flutter SDK on the dart lane (same constraint
  the sandbox docstring records for spec 1001).
