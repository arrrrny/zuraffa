# Chore Implementation: zfa setup: --dart/--flutter, Flutter SPM defaults, clean test env per target

- **Slug**: setup-flutter-spm-tdd
- **Implemented**: 2026-08-29
- **Assessment**: ./assessment.md
- **Status**: partial

## Summary

Reworked `zfa setup` into a thin pass-through wrapper around `flutter create` /
`dart create`. The issue's proposed `--swift-package-manager` flag does not exist
in current Flutter (3.24+ scaffolds iOS with Swift Package Manager by default —
CocoaPods was removed), so it was dropped; the constitution's SPM-only rule holds
out of the box. The hardcoded `ios,android` default was also removed so user input
is never overridden. `--platforms`/`--org` forward as-is, and a `--` separator
forwards any other `flutter create`/`dart create` flag verbatim.

The "clean test environment per target" part (point 3) is **deferred to #575**.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/commands/setup_command.dart` | modified | Removed hardcoded `ios,android` default + obsolete `--swift-package-manager`. `--platforms`/`--org` forward as-is. Added `--` passthrough forwarding arbitrary `flutter create`/`dart create` flags verbatim. Updated help text. |
| `test/commands/setup_command_test.dart` | modified | Replaced SPM assertions with pass-through tests: default emits no `--platforms`; `--platforms=linux,ios` forwards verbatim; `--` forwards arbitrary flutter/dart flags. |

## Diff Highlights (optional)

`_createApp` now appends a verbatim pass-through list to the scaffold command and
no longer injects defaults:

```dart
final args = <String>['create', '--empty', appName];
if (platforms != null && platforms.isNotEmpty) {
  for (final plat in platforms.split(',')) {
    final trimmed = plat.trim();
    if (trimmed.isNotEmpty) args.addAll(['--platforms', trimmed]);
  }
}
if (org != null && org.isNotEmpty) args.addAll(['--org', org]);
args.addAll(passthrough); // verbatim flutter/dart create flags from `--`
```

`run()` derives `passthrough` from everything after the app name:
`final passthrough = rest.length > 1 ? rest.sublist(1) : const <String>[];`

## Verification

- `dart analyze lib/src/commands/setup_command.dart` → No issues found.
- `dart test test/commands/setup_command_test.dart` → 41/41 passed.
- Real `zfa` runs (dry-run) confirmed:
  - `zfa setup x --flutter --platforms=linux,ios` → `flutter create --empty x --platforms linux --platforms ios`
  - `zfa setup x --flutter -- --template plugin --org com.example` → forwarded verbatim
  - `zfa setup l --dart -- --template package` → `dart create -t package l --template package`
- Full real scaffold `zfa setup probe --flutter` created `ios` + `android` with **no Podfile/Pods** (SPM default). Env: Flutter 3.47.1.

## Deviations from Assessment

- **Obsolete flag.** The issue prescribed `--swift-package-manager` to `flutter create`. That flag was removed from Flutter (verified on 3.47.1: `flutter create --help` has no such option, and passing it errors with "Could not find an option named --swift-package-manager"). On current Flutter, iOS already uses SPM by default (no CocoaPods), so no flag is needed and the constitution's SPM-only rule holds automatically. The flag was dropped rather than pinning a non-existent option that would break `zfa setup`.
- **No hardcoded platform default.** The issue wanted a default of `ios,android`. Per feedback, the default was removed entirely so user-supplied `--platforms` is honored verbatim and `flutter create` applies its own default when none is given.
- **Pass-through design.** Instead of enumerating specific flags, `zfa setup` forwards any flag after `--` straight to the underlying scaffolder, satisfying "any param flutter/dart accepts is ported directly". `--platforms`/`--org` remain first-class for convenience.
- **Test env deferred** to #575 (see above). Status is therefore `partial`: the scaffolding/pass-through contract is fully implemented; the test-runner acceptance is delegated.

## Follow-ups

- Pair with #575 to deliver the runnable `test/` baseline for both targets.
- After #575, re-verify the full acceptance criteria from issue #576.
