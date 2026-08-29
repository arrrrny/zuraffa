## Summary

Reworked `zfa setup` into a thin pass-through wrapper around `flutter create` /
`dart create`, per feedback. The originally proposed `--swift-package-manager`
flag does not exist in current Flutter (3.24+ scaffolds iOS with Swift Package
Manager by default — CocoaPods was removed), so it was dropped; the constitution's
SPM-only rule holds out of the box. The hardcoded `ios,android` platform default
was also removed so user input is never overridden.

Behavior now:

- `--flutter` (default) / `--dart` select the scaffolder. `--dart` makes a pure
  Dart package; `--flutter` remains the default.
- `--platforms` / `--org` stay first-class and forward as-is, so
  `zfa setup x --platforms=linux,ios` scaffolds exactly that set.
- Any other flag for the underlying tool is forwarded verbatim via a `--`
  separator (e.g. `zfa setup x --flutter -- --template plugin`), so users can
  pass through **any** `flutter create` / `dart create` option.

> **Scope note:** the "runnable test environment per target" part of #576
> (smoke tests + `flutter_test`/`test` dev deps + `dart_test.yaml`) is deferred
> to #575, which owns the TDD baseline. This PR focuses on the scaffolding
> flags/pass-through.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/commands/setup_command.dart` | modified | Removed hardcoded `ios,android` default + obsolete `--swift-package-manager`. `--platforms`/`--org` forward as-is. Added `--` passthrough that forwards arbitrary `flutter create`/`dart create` flags verbatim. Updated help text. |
| `test/commands/setup_command_test.dart` | modified | Replaced SPM assertions with pass-through + verbatim-forward tests (default emits no `--platforms`; `--platforms=linux,ios` forwards; `--` forwards arbitrary flutter/dart flags). |

## Verification

- `dart analyze lib/src/commands/setup_command.dart` → No issues found.
- `dart test test/commands/setup_command_test.dart` → 41/41 passed.
- Real `zfa` runs (dry-run) confirmed:
  - `zfa setup x --flutter --platforms=linux,ios` → `flutter create --empty x --platforms linux --platforms ios`
  - `zfa setup x --flutter -- --template plugin --org com.example` → forwarded verbatim
  - `zfa setup l --dart -- --template package` → `dart create -t package l --template package`
- Full real scaffold `zfa setup probe --flutter` created `ios` + `android` with **no Podfile/Pods** (SPM default). Flutter 3.47.1.

Assessment: .specify/chores/setup-flutter-spm-tdd/assessment.md

Closes #576.
