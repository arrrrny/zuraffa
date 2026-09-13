# Quickstart: `zuraffa_ocr` delivery

**Feature**: specs/1602-zuraffa-ocr-plugin

## 1. Scaffold a throwaway family

```bash
cd "$(mktemp -d)"
dart run /path/to/zuraffa/bin/zfa.dart package create-plugin zuraffa_ocr \
  --repo arrrrrny/zuraffa_ocr \
  --description "Typed OCR support for the Zuraffa ecosystem: a pure-Dart port, recognition lifecycle, and typed failures behind an injected platform channel with federated adapters." \
  --no-gate
ls zuraffa_ocr/packages
```

Expected: exactly `zuraffa_ocr`, `zuraffa_ocr_android`, `zuraffa_ocr_ios`,
`zuraffa_ocr_macos`, `zuraffa_ocr_platform`. Every pubspec carries the OCR
description, `repository: https://github.com/arrrrny/zuraffa_ocr`, an
`ocr` topic, `version: 0.1.0`, `zuraffa: ^6.2.2`.

## 2. Family board (network; ≤ 15 min)

```bash
cd zuraffa_ocr
for pkg in packages/*/; do (cd "$pkg" \
  && dart pub get \
  && dart analyze --no-fatal-warnings \
  && dart test \
  && dart pub publish --dry-run) || echo "FAILED: $pkg"; done
```

Expected: no `FAILED` lines.

## 3. In-repo automated proof

```bash
dart test test/package_sdk/plugin_ocr_instance_test.dart      # fast, offline
dart test test/package_sdk/plugin_ocr_e2e_test.dart --preset=integration
```

## 4. Delivery

Run the invocation in `~/Developer` (creates `~/Developer/zuraffa_ocr`),
re-run the board there, then:

```bash
cd ~/Developer/zuraffa_ocr
git init -b master && git add -A && git commit -m "feat: initial federated scaffold"
gh repo create arrrrrny/zuraffa_ocr --public --source . --push
gh repo view arrrrrny/zuraffa_ocr   # resolves
```
