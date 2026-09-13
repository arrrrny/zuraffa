# TDD Test List — Spec 1600

Red pre-fix: B1–B4, B6, B7 red via the missing API surface (load errors —
the flag/factory/seam do not exist yet); B5, B8 **assertion red** on the
current binary (the defect itself: the committed/certified contract test
imports `package:test` on a Flutter fixture); B2 guard green (golden
pinned); B9/B10 skip honestly without the Flutter SDK (slow tier, local).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | MockContractTestWriter(flutterTest: true) renders the flutter_test import and never package:test | FR-001 / SC-1 | test/plugins/mock/certification/bug_1600_mock_contract_flutter_import_test.dart |
| B2 | Default writer stays byte-identical to the pre-fix render (golden: test/fixtures/baseline_outputs/bug_1600_mock_contract_default_render.txt) — guard | FR-006 / SC-1 | test/plugins/mock/certification/bug_1600_mock_contract_flutter_import_test.dart |
| B3 | Sandbox Flutter manifest: flutterTest declares flutter sdk + flutter_test sdk dep; unset shape is today's exact bytes | FR-004 / SC-4 | test/plugins/mock/certification/bug_1600_mock_contract_flutter_import_test.dart |
| B4 | Sandbox toolchain selection: flag set → flutter executable + runner records `flutter`; unset → dart (unchanged) | FR-004 / SC-4 | test/plugins/mock/certification/bug_1600_mock_contract_flutter_import_test.dart |
| B5 | END-TO-END (in-process): `mock create Task --certify` on a Flutter-declaring fixture commits a Flutter-shaped contract test (assertion red pre-fix — the #1600 defect) | FR-002 / SC-2 | test/plugins/mock/capabilities/bug_1600_certifier_for_project_test.dart |
| B6 | MockCertifier.forProject detection matrix: flutter pubspec → Flutter-shaped certifier (writer testImport + sandbox flag); pure-Dart / unreadable / absent pubspec → Dart shape; both capabilities construct through it (no bare render sites) | FR-002 / FR-003 / SC-2 / SC-6 | test/plugins/mock/capabilities/bug_1600_certifier_for_project_test.dart |
| B7 | Degradation: Flutter host + no Flutter executable on PATH (injected) → create-certify warns naming precondition + fix, writes NO receipt, returns generation-governed success with the certSandboxUnresolved marker; with the SDK present a red contract is still honestly red | FR-005 / SC-5 | test/plugins/mock/capabilities/bug_1600_certifier_for_project_test.dart |
| B8 | END-TO-END (in-process): `mock certify Task` fresh-render path (no committed test) on a Flutter fixture emits the same Flutter-shaped surface (assertion red pre-fix) | FR-003 / SC-6 | test/plugins/mock/capabilities/bug_1600_certifier_for_project_test.dart |
| B9 | Integration (slow, skips w/o SDK): live certification on a Flutter fixture runs green through the flutter toolchain, receipt records every pinned method satisfied, and the committed test passes under `flutter test` in the fixture | FR-004 / SC-3 | test/integration/bug_1600_mock_certification_flutter_e2e_test.dart |
| B10 | Integration (slow, skips w/o SDK): a red contract on a Flutter host stays honestly red (exit failure, receipt records the failure) — degradation never masks a real red | FR-005 / SC-5 | test/integration/bug_1600_mock_certification_flutter_e2e_test.dart |

## Red protocol

```
dart test test/plugins/mock/certification/bug_1600_mock_contract_flutter_import_test.dart
dart test test/plugins/mock/capabilities/bug_1600_certifier_for_project_test.dart
# slow tier, local only (needs the Flutter SDK):
dart test --preset=integration test/integration/bug_1600_mock_certification_flutter_e2e_test.dart
```
