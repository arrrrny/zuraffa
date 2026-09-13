# Feature Specification: Mock Certification Contract Test Honors the Host Test Framework [SPEC 1600]

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `1600-mock-contract-flutter-import`

**Created**: 2026-09-13

**Status**: Draft

**Input**: User description: "Issue #1600 — mock certification contract test hardcodes package:test — permanent red test on Flutter hosts, refactor preflight hard-stops the run after a green unit lane (#1513 sibling)"

## Summary

`MockContractTestWriter` hardcodes `import 'package:test/test.dart';`, so the
mock certification contract test it commits to a Flutter host project cannot
compile there — plain `package:test` is not resolvable under the
flutter_test runner. Dogfooded on the xzx todo host: after all 21 unit
behaviors certified green, the `zfa tdd run` died at the first refactor step
(`runner-error`) because `flutter test` on the host was `+42 -1` — the one
red test being the generated `test/mock/task/task_mock_contract_test.dart`
(load error: `Couldn't resolve the package 'test'`). One generated file
permanently poisons every green-suite gate on the host: `refactor`'s
preflight, `make`'s green certification paths, and the run's baseline
accounting.

This is the mock-lane sibling of #1513 (the contract lane's
`ContractTestWriter` had exactly the same hardcoded import and was fixed
with a `flutterTest` flag that unit/acceptance lanes already honored via
#1351). The mock lane never received the same treatment.

The fix must cover the WHOLE certification loop, not just the emitted import:
the certification sandbox proves the contract test with the plain Dart
toolchain (`dart pub get` + `dart analyze` + `dart test`, sandbox pubspec
declaring only `test`). If the committed test flips to the Flutter framework
import while the sandbox stays Dart-only, `mock create --certify` on a
Flutter host trades "permanently red committed test" for "permanently red
certification" — the same bug wearing a different hat. The sandbox must
prove a Flutter-shaped contract test with the Flutter toolchain, and degrade
honestly when the Flutter SDK is not installed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Flutter host gets a compiling, passing contract test (Priority: P1)

A developer generates mocks in a Flutter project with
`zfa mock create <Entity> --certify`. The committed contract test imports
the host's Flutter test framework and never plain `package:test`, so
`flutter test` on the host compiles and passes it. The host suite returns to
green and no green-suite gate (`refactor` preflight, `make` certification,
run baseline) is poisoned by a generated file.

**Why this priority**: This is the reported defect — a generated file that
permanently reds the host suite and hard-stops the tdd run.

**Independent Test**: Generate + certify a mock in a fixture project whose
pubspec declares a Flutter dependency; inspect the committed test's import
surface and run the host toolchain on it.

**Acceptance Scenarios**:

1. **Given** a project whose pubspec declares a Flutter dependency and a
   generated mock for an entity, **When** `zfa mock create <Entity>
   --certify` runs, **Then** the committed contract test at
   `test/mock/<snake>/<snake>_mock_contract_test.dart` imports
   `package:flutter_test/flutter_test.dart` and contains no
   `package:test/test.dart` import.
   **Type**: unit
2. **Given** the same Flutter host project with the committed contract
   test, **When** the host's Flutter test runner executes the project
   suite, **Then** the contract test compiles and passes (no
   `Couldn't resolve the package 'test'` load error) — the permanently-red
   test is gone.
   **Type**: acceptance
3. **Given** a pure-Dart project (no Flutter dependency in the pubspec),
   **When** `zfa mock create <Entity> --certify` runs, **Then** the
   committed contract test keeps importing `package:test/test.dart`
   (byte-identical to the pre-fix render).
   **Type**: unit

---

### User Story 2 - The certification sandbox certifies Flutter-shaped contract tests live (Priority: P2)

The certification is live, not a snapshot: a receipt is only written from a
green run NOW. When the contract test is Flutter-shaped (host is a Flutter
project), the sandbox proves it with the Flutter toolchain — the sandbox
package declares the Flutter SDK dependencies and the analyze/test steps run
through the Flutter toolchain — so `mock create --certify` on a Flutter host
still certifies honestly instead of failing on an unresolvable import.

**Why this priority**: Without it, US-1's fix moves the red from the host
suite to the certification command — the same defect wearing a different
hat.

**Independent Test**: Run certification against a Flutter-declaring fixture
with the Flutter SDK available; the sandbox run is green and the receipt
records per-method satisfaction. (The live-SDK proof is integration-tier;
CI's dart lane proves the pubspec/toolchain selection and the honest
degradation without the SDK.)

**Acceptance Scenarios**:

1. **Given** a Flutter host project and the Flutter SDK installed, **When**
   `zfa mock create <Entity> --certify` runs, **Then** the sandbox proves
   the Flutter-shaped contract test with the Flutter toolchain and the
   certification outcome is derived from that run (green run → receipt with
   every pinned method satisfied).
   **Type**: acceptance
2. **Given** a pure-Dart host project, **When** certification runs, **Then**
   the sandbox behaves exactly as today (plain Dart toolchain, sandbox
   pubspec declaring the plain test package) — no Flutter machinery
   appears.
   **Type**: unit

---

### User Story 3 - Honest degradation when the Flutter SDK is unavailable (Priority: P3)

When the host is a Flutter project but the machine running certification has
no Flutter SDK, the certification is an environment-dependent proof that
cannot run — the same class as the unresolvable-framework precedent
(spec 1110). The command stays loud but honest: a clear warning names the
missing precondition and its fix, NO receipt is written (the un-certified
state stays visible — downstream cert-gates refuse the entity until it is
certified in a capable environment), and the command's exit stays governed
by the generation gate rather than reporting a false red contract.

**Why this priority**: CI dart lanes and pure-Dart machines must not
start failing `mock create --certify` for Flutter projects after the fix.

**Independent Test**: With the Flutter executable unavailable on PATH,
certify a Flutter-declaring fixture: the outcome is the environment-gap
warning path (no receipt, generation-governed exit), not a red contract.

**Acceptance Scenarios**:

1. **Given** a Flutter host project and NO Flutter SDK on PATH, **When**
   `zfa mock create <Entity> --certify` runs, **Then** the command warns
   that the sandbox cannot certify a Flutter-shaped contract test without
   the Flutter SDK, writes no `mock-cert.<Entity>.json` receipt, and the
   exit code stays governed by the generation + structural gate (the
   `certSandboxUnresolved` precedent).
   **Type**: unit
2. **Given** a red contract on a Flutter host WITH the SDK available,
   **When** certification runs, **Then** the run is still honestly red
   (exit failure, receipt records the failure) — the degradation path never
   masks a real red.
   **Type**: acceptance

---

### User Story 4 - Pure-Dart world unchanged (Priority: P3)

Every existing pure-Dart surface is untouched by the fix: the default
writer output is byte-identical, the sandbox's Dart toolchain path is
unchanged, existing receipts and their contract digests stay valid, and the
fast suite passes without a Flutter SDK.

**Why this priority**: The guard story — byte-stability is what makes the
change safe to review and merge.

**Independent Test**: Golden-render the default writer output against the
pre-fix bytes; run the existing certification suites unmodified.

**Acceptance Scenarios**:

1. **Given** the default writer (no flag), **When** a contract test is
   rendered for the canonical no-Flutter fixture shape, **Then** the bytes
   are identical to the pre-fix render (golden pin).
   **Type**: unit
2. **Given** the existing certification/regression suites (writer, receipt,
   gate, e2e), **When** the fast suite runs, **Then** they pass unchanged
   (no Flutter SDK required).
   **Type**: unit

---

### Edge Cases

- A Flutter project whose pubspec cannot be read/parsed at certification
  time → treated as NOT a Flutter host (pure-Dart default), never a crash.
- The `zfa mock certify` path with NO committed contract test (fresh render
  path) on a Flutter host → the same Flutter-shaped output as the create
  path (the flag is threaded at both render sites, never just one).
- A committed Flutter-shaped contract test being re-certified
  (`zfa mock certify`, committed bytes path) → the committed bytes are used
  verbatim (the certification is live); the sandbox proves them with the
  Flutter toolchain because the committed import says Flutter.
- A Flutter host where the sandbox framework root is ALSO unresolvable →
  the framework-root warning wins (it is checked first); no double warning.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The mock certification contract test writer MUST honor the
  host runner: it carries a `flutterTest` field defaulting to `false` and a
  `testImport` getter; with `flutterTest: true` the rendered contract test
  imports the Flutter test framework and never plain `package:test`; with
  the default the render is byte-for-byte what today's binary emits.
  traces: MockContractTestWriter.render
- **FR-002**: The `zfa mock create <Entity> --certify` path MUST detect the
  host from the project's pubspec (a Flutter dependency declares the host)
  and thread the resolved flag into the certifier's contract writer. An
  unreadable/absent pubspec is NOT a Flutter host.
  traces: CreateMockCapability.certify
- **FR-003**: The `zfa mock certify <Entity>` path MUST thread the same
  resolved flag into its certifier, covering the fresh-render path (no
  committed contract test) — the two render sites cannot drift.
  traces: CertifyMockCapability.run
- **FR-004**: The certification sandbox MUST prove a Flutter-shaped contract
  test with the Flutter toolchain: when the flag is set, the sandbox
  package's manifest declares the Flutter SDK and its test framework, and
  the dependency-resolution, analyze, and test steps run through the
  Flutter toolchain with the same timeouts, offline-first strategy, JSON
  reporter, and per-method outcome parsing as the Dart path. The reported
  runner records which toolchain ran.
  traces: MockCertificationSandbox.run
- **FR-005**: When the flag is set but the Flutter toolchain is unavailable
  (not on PATH), the sandbox MUST report the environment gap as an
  unresolvable proof (NOT a red contract), and the certify capability MUST
  mirror the spec-1110 unresolved-framework precedent: warn with the fix,
  write no receipt, keep the exit governed by the generation + structural
  gate. A real red contract WITH the SDK available is still honestly red.
  traces: MockCertificationSandbox.run, CreateMockCapability.certify
- **FR-006**: Pure-Dart stability guard: with the default flag (non-Flutter
  host), the writer render is byte-identical to the pre-fix output, the
  sandbox selects the plain Dart toolchain and the same manifest shape as
  today, and no existing receipt or digest changes meaning.
- **FR-007**: The run driver, refactor preflight, red classifier, state
  machine, and loop semantics are NOT touched (messaging- and
  artifact-shape-only fix on the mock lane). Distinguishing "pre-existing
  broken generated test" from "behavior under refactor regressed" in the
  preflight is explicitly OUT of scope (the #1544/#1568 family).

## Layer Contracts

**Function**:
- `MockContractTestWriter`: `render(EntityName, Methods, ProjectRoot, OutputDir) -> Source`
- `MockCertificationSandbox`: `run(EntityName, ProjectRoot, OutputDir, ContractTestSource, Methods) -> Run`

**Presentation**:
- `CreateMockCapability`: `certify(Args, Files) -> ExecutionResult`
- `CertifyMockCapability`: `run(Args) -> ExitCode`

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-1**: A contract test rendered with `flutterTest: true` imports the
  Flutter test framework and never `package:test`; with the default it is
  byte-identical to the pre-fix render (golden pin). **[US-1]**
- **SC-2**: On a fixture whose pubspec declares Flutter, the create
  `--certify` path commits a Flutter-shaped contract test; on a pure-Dart
  fixture it commits today's bytes. **[US-1]**
- **SC-3**: On a Flutter host with the Flutter SDK available, certification
  runs green end-to-end through the Flutter toolchain and the receipt
  records every pinned method satisfied; the committed test passes under
  the host's Flutter test runner. **[US-2]** (integration-tier proof)
- **SC-4**: The sandbox manifest for a Flutter-shaped run declares the
  Flutter SDK + test framework and the toolchain commands route through
  `flutter`; for a pure-Dart run both are unchanged from today. **[US-2]**
- **SC-5**: With no Flutter SDK on PATH, certification of a
  Flutter-shaped contract test takes the warning path: no receipt written,
  generation-governed exit, and the warning names the missing
  precondition + fix. A red contract with the SDK present still exits
  red. **[US-3]**
- **SC-6**: The `zfa mock certify` fresh-render path emits the same
  Flutter-shaped surface as the create path on a Flutter fixture. **[US-1,
  FR-003]**
- **SC-7**: The existing fast certification suites (writer, receipt, gate,
  capability) pass unchanged without a Flutter SDK; `dart analyze` over the
  changed files reports no new issues. **[US-4]**

## Assumptions

- The host's shape is read from the project pubspec's dependency set (a
  Flutter dependency declares a Flutter host) — the same signal
  `DependencyWirer.isFlutterProject` and the tdd gen lane already use, so
  all lanes answer "is this a Flutter host" identically.
- The certification runs where the CLI runs; a developer certifying a
  Flutter project realistically has the Flutter SDK installed (they run
  its test runner). CI dart lanes without the SDK take the FR-005
  degradation path.
- The Flutter-shaped sandbox needs only a minimal manifest + the copied
  import closure (as today); no full Flutter app scaffold is created.
- The follow-up "refactor preflight should distinguish pre-existing broken
  generated tests from regressions" remains tracked in the #1544/#1568
  family and is not part of this spec.
- The same audit sweeping EVERY generated test writer for a hardcoded
  plain-test import is a separate follow-up; this spec fixes the mock lane
  (the contract lane was fixed in #1513; unit/acceptance lanes in #1351).

## Out of Scope

- The run driver, refactor preflight, red classifier, state machine.
- Unit/acceptance/ffi/persistence/platform/theme lanes (already correct via
  #1351/#1035).
- The contract lane (`ContractTestWriter`, fixed in #1513).
- `ContractSubjectWriter` / mock datasource subject output (never imports
  the test framework).
- The engine cert-gate and receipt format (the receipt's
  `contractTestSource` digest already pins whatever bytes were certified;
  no schema change needed).
