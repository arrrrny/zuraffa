# Plan — Spec 1600 mock certification contract test honors the host test framework

**Branch**: `1600-mock-contract-flutter-import` | **Date**: 2026-09-13 | **Spec**: [spec.md](spec.md)

## Summary

`MockContractTestWriter.render()` hardcodes `import 'package:test/test.dart';`,
so the mock certification contract test committed to a Flutter host cannot
compile there — one generated file permanently reds the host suite and
hard-stops the tdd run's refactor preflight (issue #1600, #1513 sibling).
Fix: the writer learns the `flutterTest` flag (default `false`, byte-stable),
both certify capabilities detect the host from the project pubspec and thread
the flag, and the certification sandbox learns to prove a Flutter-shaped
contract test with the Flutter toolchain — degrading honestly (warning path,
no receipt, generation-governed exit) when the Flutter SDK is absent.

## Technical Context

- **Language/SDK**: Dart 3.13 stable (pubspec pins `^3.11.0`); pure-Dart root
  package — the fast suite must never require the Flutter SDK.
- **Surfaces**:
  - `lib/src/plugins/mock/certification/mock_contract_test_writer.dart` —
    line ~205 hardcodes the plain import inside `render()`. Gains
    `flutterTest` + `testImport`.
  - `lib/src/plugins/mock/capabilities/create_mock_capability.dart` —
    `_certify` constructs `MockCertifier()` bare (line ~179). Gains host
    detection + flag threading (writer AND sandbox).
  - `lib/src/plugins/mock/capabilities/certify_mock_capability.dart` —
    `run` constructs `MockCertifier()` bare (line ~125); it renders fresh
    when no committed test exists — the second render site (FR-003).
  - `lib/src/plugins/mock/certification/mock_certification_sandbox.dart` —
    `run()` hardcodes the Dart toolchain (`dart pub get --offline` →
    `dart analyze` → `dart test --reporter json`) and a pubspec declaring
    only `test: ^1.25.0`. Gains `flutterTest` (default `false`).
- **Existing machinery reused**:
  - `ContractTestWriter.flutterTest` + `_testImport` (#1513) — the mock
    writer mirrors the exact same getter shape.
  - `DependencyWirer.isFlutterProject(pubspecContent)` — YAML-only detection
    (`dependencies: flutter:` key), no Flutter SDK needed; same signal the
    tdd gen lane uses (#1458/#1351) so every lane answers "is this a Flutter
    host" identically.
  - The spec-1110 `certSandboxUnresolved` precedent in
    `create_mock_capability._certify`: an environment-dependent proof that
    cannot run → warn with the fix, NO receipt, exit governed by the
    generation + structural gate. FR-005 mirrors it for a missing Flutter
    SDK.
- **Sandbox Flutter mode (FR-004)**: when the flag is set the sandbox
  pubspec declares `flutter: sdk: flutter` + `flutter_test: {sdk: flutter}`,
  and the same three steps run through the `flutter` executable (`flutter
  pub get --offline` → online fallback, `flutter analyze .`, `flutter test
  <rel> --reporter json`). Timeouts, offline-first strategy, JSON parsing,
  and per-method outcome derivation are shared; `MockCertificationRun.runner`
  records `dart` | `flutter` so the proof names its toolchain.

## Data flow (after the fix)

```
zfa mock create Task --certify            (or: zfa mock certify Task)
  → read <projectRoot>/pubspec.yaml
  → DependencyWirer.isFlutterProject(...)      (existing, YAML-only)
  → MockCertifier(
      contractWriter: MockContractTestWriter(flutterTest: isFlutter),   (NEW)
      sandbox: MockCertificationSandbox(flutterTest: isFlutter),        (NEW)
    )
  → contractWriter.render(...)                 testImport = flutter_test | test
  → sandbox.run(...)
      → flutterTest? pubspec += flutter sdk deps; exec = flutter   (NEW)
      → [flutterTest && no flutter on PATH] → unresolved run       (NEW, FR-005)
      → pub get (offline→online) → analyze → test --reporter json
  → receipt (unchanged schema; digest pins the certified bytes)
```

No-Flutter-SDK detection lives in the capability (PATH scan before `certify`
runs), mirroring the existing `resolveFrameworkRoot == null` early warning —
the sandbox itself also reports the gap honestly if reached without it.

## Constitution / constraints check

- No ratified constitution (`.specify/memory/constitution.md` is the unfilled
  template) — the repo's binding constraints are the spec's FR-006/FR-007
  guards: pure-Dart byte-stability and zero run-driver/preflight changes.
- Touch surface: the four files above (+ regression tests). No state
  machine, lane routing, or loop semantics.
- Fast suite stays Flutter-SDK-free: detection is YAML-only; live-Flutter
  certification proof is integration-tier (`test/integration/`, `slow` tag,
  same convention as `mock_certification_e2e_test.dart`).

## Test strategy

- Unit (fast tier, `dart test test/plugins/mock/`): writer import surface
  both ways + golden byte-stability pin; sandbox pubspec/toolchain
  selection without executing Flutter; capability PATH-scan degradation
  (warning, no receipt, generation-governed exit); certify-capability
  threading; unreadable pubspec → pure-Dart default.
- Integration (slow tier, opt-in; locally verified with the installed
  Flutter SDK): the full `mock create --certify` e2e on a
  Flutter-declaring fixture — sandbox certifies green through `flutter`,
  receipt records every pinned method satisfied, and the committed test
  passes under `flutter test` in the fixture project.

## Risks

- **Sandbox regression**: the Flutter branch must not perturb the Dart
  branch. Guard: B-behaviors pin the Dart pubspec shape + executable
  choice with the flag unset (byte-level, not snapshot-of-stdout).
- **`flutter analyze` exit semantics** differ from `dart analyze` on infos —
  the Flutter branch counts errors with the same `_countAnalyzeErrors`
  regex and passes `--no-fatal-warnings` where supported; errors-only
  blocking stays the rule on both branches.
- **PATH scan portability**: check the PATH env for a `flutter` (or
  `flutter.bat`) executable file rather than spawning `flutter --version`
  (fast, deterministic, no SDK warm-up in tests).
- **Receipt drift**: none — the receipt schema and digest are unchanged;
  a Flutter host re-certifying an old `package:test` receipt re-pins with
  the new import via `--force` (the existing drift advisory already tells
  the user to do exactly that).
