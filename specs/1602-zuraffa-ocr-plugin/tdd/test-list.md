# TDD Test List — Spec 1602 (`zuraffa_ocr` delivery)

Red pre-fix: B1/B2 red via the missing test file (the behaviors do not
exist until `plugin_ocr_instance_test.dart` is written and run — the
instance contract is what the file pins); B3 red via the missing e2e
file; B4 is the delivery procedure whose red is the absent
`~/Developer/zuraffa_ocr` repo (404 on GitHub). The generator itself is
frozen — any generator-level failure during these behaviors is a
roadblock to report, not a fix prompt.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Instance layout + stamps: real CLI `package create-plugin zuraffa_ocr --repo arrrrrny/zuraffa_ocr --description "…" --no-gate` into temp → exactly five packages; every pubspec: verbatim OCR description, `https://github.com/arrrrny/zuraffa_ocr` (+/issues), `ocr` topic, `version: 0.1.0`, hosted `zuraffa: ^6.2.2`, no `publish_to`; LICENSE + non-empty CHANGELOG per package | FR-001 / FR-002 / FR-005 / SC-1 | test/package_sdk/plugin_ocr_instance_test.dart |
| B2 | Wiring + name shapes + harness integrity: app → zuraffa only; core → app; adapters → app + core (`^0.1.0`); nobody → adapter; `OcrPort`/`OcrService` exported from the app barrel; `AndroidOcr`/`IosOcr`/`MacosOcr` prefixes in adapter sources; every harness imports its barrel and defines a test double | FR-003 / FR-002 | test/package_sdk/plugin_ocr_instance_test.dart |
| B3 | END-TO-END (slow tier): real CLI scaffold into temp → per package `dart pub get` + `dart analyze --no-fatal-warnings` + `dart test` + `dart pub publish --dry-run`, all exit 0, ≤ 15 min | FR-004 / FR-005 / SC-2 | test/package_sdk/plugin_ocr_e2e_test.dart |
| B4 | Delivery: the contract invocation produces `~/Developer/zuraffa_ocr`; full board run there; git init (master) + initial commit; `gh repo create arrrrrny/zuraffa_ocr --public --source . --push`; repo resolves; committed manifests carry no local paths | FR-006 / SC-3 | delivery procedure (evidence in tdd/cycle-log.md) |

## Red protocol

```
dart test test/package_sdk/plugin_ocr_instance_test.dart
dart test test/package_sdk/plugin_ocr_e2e_test.dart --preset=integration
```
