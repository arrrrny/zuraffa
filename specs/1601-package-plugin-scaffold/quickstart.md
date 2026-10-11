# Quickstart: Federated Plugin Scaffold

**Feature**: specs/1601-package-plugin-scaffold

Validate the feature end-to-end without reading the implementation.

## Prerequisites

- Dart SDK ≥ 3.11 on PATH (`dart --version`)
- Network access for `dart pub get` inside generated packages
- The zuraffa repo checkout (this repo)

## 1. Dry-run (no writes, < 5 s)

```bash
cd <somewhere empty>
dart run /path/to/zuraffa/bin/zfa.dart package plugin my_plugin --dry-run
```

Expected: stdout lists every file that would be created under
`my_plugin/` prefixed `[dry-run] `, five `✓` package lines
(`my_plugin`, `my_plugin_platform`, `my_plugin_android`,
`my_plugin_ios`, `my_plugin_macos`), and `ls` shows **no** `my_plugin`
directory was created.

## 2. Scaffold + per-package checks (SC-001, ≤ 5 min)

```bash
dart run /path/to/zuraffa/bin/zfa.dart package plugin my_plugin
cd my_plugin
for pkg in packages/*/; do
  (cd "$pkg" && dart pub get && dart analyze --no-fatal-warnings && dart test)
done
```

Expected: every package resolves, analyzes with zero errors, and its test
suite passes. Nothing was edited by hand.

## 3. Publish-readiness (SC-002, network)

```bash
cd packages/my_plugin && dart pub publish --dry-run; cd - >/dev/null
```

Expected: validation completes; **no `LICENSE`/`CHANGELOG` errors**.
(The hosted-name check may note the package already exists on pub.dev or
flag the name as reserved — those are publish-time, not scaffold-time,
concerns. Override/dependency hints are expected and fine.)

## 4. Subset selection (US3)

```bash
dart run /path/to/zuraffa/bin/zfa.dart package plugin tiny_plugin \
  --platforms android,ios --dry-run | grep '✓'
```

Expected: exactly `tiny_plugin`, `tiny_plugin_platform`,
`tiny_plugin_android`, `tiny_plugin_ios` — no macos adapter.

## 5. Failure rails (US5)

```bash
dart run …/zfa.dart package plugin Bad-Name        # → snake_case rule error, exit 1
dart run …/zfa.dart package plugin my_plugin       # → directory exists, exit 1
dart run …/zfa.dart package plugin x --platforms '' # → empty selection error
dart run …/zfa.dart package plugin x --platforms dos # → unknown platform error
```

## 6. In-repo automated proof

```bash
dart test test/package_sdk/plugin_scaffold_test.dart
dart test test/package_sdk/ --tags slow   # e2e tier, needs network
```
