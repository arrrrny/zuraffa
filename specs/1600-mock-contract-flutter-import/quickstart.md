# Quickstart — Spec 1600 validation guide

Prove the fix end-to-end. The fast tier needs only the Dart SDK; the last
step needs the Flutter SDK (installed on this machine).

## 1. Fast regression suite (CI parity, no Flutter SDK)

```bash
dart test test/plugins/mock/
dart analyze lib/src/plugins/mock/
```

Expected: all suites green, including the new spec-1600 behavior files; no
new analyzer issues.

## 2. Writer import surface (pure Dart)

```bash
dart test test/plugins/mock/certification/bug_1600_mock_contract_flutter_import_test.dart
```

Expected: green — flutter-shaped render imports `package:flutter_test/…`
and never `package:test/…`; default render byte-identical to the pre-fix
golden.

## 3. Live certification on a Flutter host (needs Flutter SDK)

```bash
# throwaway Flutter-declaring project shaped like the xzx dogfood host
dart run bin/zfa.dart mock create Task --certify --force
flutter test test/mock/task/task_mock_contract_test.dart
```

Expected: the CLI certifies green through the `flutter` toolchain (the
receipt records every pinned method satisfied), the committed contract test
imports `package:flutter_test/flutter_test.dart`, and the host runner passes
it — the permanently-red test from issue #1600 is gone.

## 4. Honest degradation without the Flutter SDK (CI dart lane shape)

Run step 3's CLI line with `flutter` removed from PATH.

Expected: the command warns that a Flutter-shaped contract test cannot be
certified without the Flutter SDK, writes NO `mock-cert.Task.json`, and the
exit stays governed by the generation gate — not a false red.

## 5. Full e2e (slow tier, opt-in)

```bash
dart test --preset=integration test/integration/bug_1600_mock_certification_flutter_e2e_test.dart
```

Expected: green on a machine with the Flutter SDK; the test skips honestly
when the SDK is absent.
