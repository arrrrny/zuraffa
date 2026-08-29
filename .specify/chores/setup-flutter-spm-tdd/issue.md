# Chore Issue: zfa setup: --dart/--flutter, Flutter SPM defaults, clean test env per target

- **Slug**: setup-flutter-spm-tdd
- **Fetched**: 2026-08-29
- **Issue**: 576
- **URL**: https://github.com/arrrrny/zuraffa/issues/576
- **State**: open
- **Author**: arrrrny
- **Labels**: enhancement

## Body

# `zfa setup`: explicit `--dart`/`--flutter`, Flutter defaults to `--platforms=ios,android` with Swift Package Manager, and clean test envs for both

## Context

`zfa setup <name>` already supports `--flutter` (default), `--dart`, and `--platforms`
(`lib/src/commands/setup_command.dart`). But two things are inconsistent with the project's
own rules and with a clean TDD start:

1. The constitution (Principle V) says **iOS is SPM-only, no CocoaPods**. `zfa setup` does not
   currently pass `--swift-package-manager` (or otherwise pin SPM) to `flutter create`, so a
   fresh Flutter app can be scaffolded with the CocoaPods default — violating the constitution
   silently.
2. The default platform set is `ios,macos`. For the mobile-first ZikZak apps the default should
   be `ios,android`, with SPM as the iOS dependency mechanism.

This pairs with #575 (TDD-ready `zfa setup`): that issue is about emitting `test/` + a
`tdd-profile.md`; this one is about the **app scaffolding flags and the test runner each
target gets**.

## Proposal

### 1. First-class, explicit targets
- `zfa setup <name> --flutter` → Flutter app.
- `zfa setup <name> --dart` → pure Dart package (`dart create -t package`).
- Keep the mutual-exclusion guard ("pass either --flutter or --dart, not both").

### 2. Flutter platform defaults + SPM
- Default Flutter platforms to **`ios,android`** (override via `--platforms=...`).
- When iOS is in the platform list, `flutter create` is invoked with
  **`--swift-package-manager`** so the iOS side uses SPM, never CocoaPods. Enforce the
  constitution's SPM-only rule at scaffold time rather than relying on manual cleanup.

### 3. A clean test environment per target
- **Flutter** (`--flutter`): ensure a `test/` directory exists and `flutter test` runs a
  real baseline out of the box (smoke test + `flutter_test` dev dep + `dart_test.yaml`).
  See #575 for the full TDD baseline contents.
- **Dart** (`--dart`): ensure `dart test` works immediately — `test/` dir + `test` dev dep
  + a passing smoke test — instead of an app that has no runnable tests.

Acceptance:
- `zfa setup myapp --flutter` → iOS uses SPM (`ios/Runner` has no `Podfile`/Pods, SPM
  integration present), platforms include `android`, and `flutter test` runs ≥1 test.
- `zfa setup mylib --dart` → `dart test` runs ≥1 test.

## Why
SPM-only is already a hard constitution rule; the CLI should make the violation impossible
rather than trusting manual fixes. And both targets should hand the developer a *runnable*
test environment, which is the prerequisite for TDD (and for #575's `tdd-profile.md` to be
verifiable).

## Comments

None.
