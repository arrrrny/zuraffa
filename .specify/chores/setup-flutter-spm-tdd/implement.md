# Chore Implementation: zfa setup: --dart/--flutter, Flutter SPM defaults, clean test env per target

- **Slug**: setup-flutter-spm-tdd
- **Implemented**: 2026-08-29
- **Assessment**: ./assessment.md
- **Status**: partial

## Summary

Updated `zfa setup` so Flutter scaffolds default to `ios,android` and pin
`--swift-package-manager` whenever iOS is in the platform list (enforcing the
constitution's SPM-only rule at scaffold time). The "clean test environment per
target" part (point 3 of the issue) was deliberately **out of scope** for this
change — it overlaps companion issue #575, which owns the TDD baseline
(`test/` + `tdd-profile.md`). Scope was confirmed with the user before coding.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/commands/setup_command.dart` | modified | Default Flutter platforms `ios,android`; add `--swift-package-manager` when iOS present; updated usage line + `--flutter`/`--platforms` help text. |
| `test/commands/setup_command_test.dart` | modified | 3 new dry-run assertions pinning default SPM+platforms, no-SPM for non-iOS, and SPM for `--platforms=ios`. |

## Diff Highlights (optional)

`_createApp` (Flutter branch) now computes a default platform set and pins SPM:

```dart
final effectivePlatforms =
    (platforms != null && platforms.isNotEmpty) ? platforms : 'ios,android';
final usesIos = effectivePlatforms
    .split(',')
    .map((p) => p.trim())
    .contains('ios');
final args = <String>['create', '--empty', appName];
if (usesIos) {
  args.add('--swift-package-manager');
}
for (final plat in effectivePlatforms.split(',')) {
  final trimmed = plat.trim();
  if (trimmed.isNotEmpty) {
    args.addAll(['--platforms', trimmed]);
  }
}
```

The explicit `--dart`/`--flutter` mutual-exclusion guard (already present at
`run()`) was left unchanged.

## Verification

- Commands run:
  - `dart analyze lib/src/commands/setup_command.dart` → No issues found.
  - `dart test test/commands/setup_command_test.dart` → 39/39 passed (incl. 3 new).
- Manual checks: none (Flutter is not installed in this environment, so a live
  `flutter create` scaffold was not executed; the flag assembly is covered by the
  dry-run tests which assert on the exact `flutter create` argument string).

## Deviations from Assessment

- **Scope reduced to flags + SPM only.** The assessment was a scaffold
  (`[NEEDS CLARIFICATION]`). Per user decision, the runnable test environment
  (smoke tests + `flutter_test`/`test` dev deps + `dart_test.yaml`) is deferred to
  #575 to avoid duplicating its TDD baseline. This leaves the issue's acceptance
  criteria "flutter/dart test runs ≥1 test" satisfied only once #575 lands.
- Status is therefore `partial`: the platform/SPM contract is fully implemented,
  but the test-env acceptance is delegated.

## Follow-ups

- Pair with #575 to deliver the runnable `test/` baseline for both targets.
- After #575, re-verify the full acceptance criteria from issue #576 in a Flutter-equipped environment.
