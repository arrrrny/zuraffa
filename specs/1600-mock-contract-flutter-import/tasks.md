# Tasks — Spec 1600 mock certification contract test honors the host test framework (MVP-first)

**Traces**: behaviors B1–B10 (specs/1600-mock-contract-flutter-import/tdd/test-list.md) → FR-001..FR-007 / SC-1..SC-7.
**Behavior tasks are MANDATORY** — each [behavior: B*] task must be driven red→green by the loop before its implementation task may be ticked.

## Phase 1: Setup

- [x] T001. Capture the golden default render: generate the pre-fix
      `MockContractTestWriter().render(...)` bytes for the canonical
      no-Flutter fixture shape into
      `test/fixtures/baseline_outputs/bug_1600_mock_contract_default_render.txt`
      (B2's golden; fixture shape follows
      `test/plugins/mock/certification/mock_contract_test_writer_test.dart`).

## Phase 2: User Story 1 — Flutter host gets a compiling, passing contract test (P1) 🎯 MVP

- [x] T002. [US1] [behavior: B1] [MANDATORY] Writer import surface in
      `test/plugins/mock/certification/bug_1600_mock_contract_flutter_import_test.dart`:
      `flutterTest: true` render imports `package:flutter_test/flutter_test.dart`
      and never `package:test/test.dart`. Traces FR-001 / SC-1.
- [x] T003. [US1] [behavior: B2] [MANDATORY] Golden byte-stability: default
      render is byte-identical to the T001 golden — guard, green pre-fix by
      design. Traces FR-006 / SC-1.
- [x] T004. [US1] Implement the writer flag:
      `mock_contract_test_writer.dart` gains `flutterTest` (default false) +
      `testImport` getter; `render()` interpolates it. Traces FR-001.

**Checkpoint**: writer surface proven both ways; pure-Dart bytes unchanged.

## Phase 3: User Story 2 — The certification sandbox certifies Flutter-shaped contract tests live (P2)

- [x] T005. [US2] [behavior: B3] [behavior: B4] [MANDATORY] Sandbox Flutter
      mode in
      `test/plugins/mock/certification/bug_1600_mock_contract_flutter_import_test.dart`:
      the Flutter-shaped manifest declares `flutter: sdk: flutter` + the
      Flutter test framework sdk dep; the unset manifest is today's exact
      bytes; the toolchain executable selects `flutter` when the flag is set
      and `dart` when unset; `MockCertificationRun.runner` records which
      toolchain ran. Traces FR-004 / SC-4.
- [x] T006. [US2] [behavior: B5] [behavior: B6] [behavior: B8] [MANDATORY]
      Host detection + threading in
      `test/plugins/mock/capabilities/bug_1600_certifier_for_project_test.dart`:
      in-process end-to-end, `mock create Task --certify` on a
      Flutter-declaring fixture commits a Flutter-shaped contract test (B5 —
      assertion red pre-fix: the #1600 defect); `MockCertifier.forProject`
      detection matrix — flutter pubspec → Flutter-shaped certifier
      (writer testImport + sandbox flag), pure-Dart / unreadable / absent
      pubspec → Dart shape, both capabilities construct through it (B6); the
      `mock certify` fresh-render path emits the same Flutter-shaped surface
      (B8 — assertion red pre-fix). Traces FR-002 / FR-003 / SC-2 / SC-6.
- [x] T007. [US2] Implement the sandbox flag:
      `mock_certification_sandbox.dart` gains `flutterTest` (default false),
      the branched manifest + executable selection (shared timeouts,
      offline-first, JSON parsing), and honest `runner` reporting. Traces
      FR-004.
- [x] T008. [US2] Implement the wiring: `MockCertifier.forProject(projectRoot)`
      factory in `mock_certifier.dart` (pubspec read + YAML host detection);
      `create_mock_capability.dart` and `certify_mock_capability.dart`
      construct through it. Traces FR-002 / FR-003.
- [x] T009. [US2] [behavior: B9] [behavior: B10] [MANDATORY] Integration e2e
      in `test/integration/bug_1600_mock_certification_flutter_e2e_test.dart`
      (tagged `slow, integration`, skips honestly without the Flutter SDK):
      on a Flutter-declaring fixture the real CLI certifies green through
      the `flutter` toolchain with an all-satisfied receipt and the
      committed test imports flutter_test and passes under `flutter test`
      (B9); breaking the interface keeps certification honestly red (B10).
      Traces FR-004 / FR-005 / SC-3 / SC-5.

**Checkpoint**: Flutter-shaped certification is live end-to-end; Dart path unchanged.

## Phase 4: User Story 3 — Honest degradation when the Flutter SDK is unavailable (P3)

- [x] T010. [US3] [behavior: B7] [MANDATORY] Degradation in
      `test/plugins/mock/capabilities/bug_1600_certifier_for_project_test.dart`
      (SDK availability injected): Flutter host + no Flutter executable →
      the create-certify path warns naming the missing precondition + fix,
      writes NO receipt, and returns generation-governed success with the
      `certSandboxUnresolved` marker; a red contract with the SDK present
      is still honestly red. Traces FR-005 / SC-5.
- [x] T011. [US3] Implement the degradation: PATH scan for the Flutter
      executable (injectable for tests) + the spec-1110-mirroring warning
      path in `create_mock_capability.dart` and `certify_mock_capability.dart`
      (checked after the framework-root gate; no double warning). Traces
      FR-005.

## Phase 5: Polish & Cross-Cutting (US4 guards)

- [x] T012. Scoped `dart analyze` green on the four touched lib files +
      `dart format` clean; the existing certification/regression suites
      (`test/plugins/mock/`, plus the untouched neighbors of the touched
      surfaces) stay green on the fast tier without a Flutter SDK. Traces
      FR-006 / SC-7.
- [x] T013. Run quickstart.md validation steps 1–4 (step 3 locally with the
      installed Flutter SDK; step 4 with `flutter` removed from PATH).

## Dependencies & Execution Order

- T001 → T003 (golden literal) → T002 → T004 (writer impl makes B1 green).
- T005 → T007 (sandbox impl); T006 → T008 (wiring impl); T009 after T007+T008.
- T010 → T011; T011 after T008 (shares the factory seam).
- T012/T013 last (whole-feature guards).

## Implementation Strategy

MVP = US1 alone (the emitted import is fixed; hosts stop being red).
US2 makes certification live on Flutter hosts (without it the red moves
into `mock create --certify`); US3 keeps CI dart lanes green; US4 is the
merge gate. B2 is a guard — green on the current binary, pinned so the
change cannot drift it.
