# Cycle Log: zfa setup must never leave a dangling assets/zuraffa_app_icons/ pubspec entry (bug #735)

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/core/branding/branding_writer_test.dart` (pre-existing
  11 tests) — green at planning time; last recorded full fast-suite run
  (bug #682 verification, 2026-09-01): fast 2494 passed, 0 failed (chunked,
  60 chunks, exit 0)
- repo fast suite green at planning time
- commit: `49496d5`
- recorded: cycle 0, before any change

## A1–A3 (bug #735 fix)

### RED — behavior tests existed and failed before implementation

Two regression tests added to `test/core/branding/branding_writer_test.dart`
(group `bug 735: pubspec assets entry is never dangling`). They deliberately do
NOT skip when brand assets are absent — the `markTestSkipped('brand assets not
checked out')` blind spot in U4/U5 is exactly how this bug shipped. The
`zuraffaRoot` is a fresh temp dir with no `assets/zuraffa_app_icons/` inside,
simulating the minimal CI clone from the issue deterministically.

```
$ dart test test/core/branding/branding_writer_test.dart --plain-name "bug 735"
00:00 +0 -1: BrandingWriter bug 735: ... creates assets/zuraffa_app_icons/ when brand asset source is absent [E]
  Expected: true
    Actual: <false>
  assets/zuraffa_app_icons/ must exist even when the brand asset source is absent — otherwise every flutter test fails with "unable to find directory entry in pubspec.yaml" (bug 735)
00:00 +0 -2: BrandingWriter bug 735: ... pubspec assets entry is backed by an existing directory [E]
  Expected: true
    Actual: <false>
  the pubspec entry must never dangle: the referenced directory has to exist on disk (bug 735)
00:00 +0 -2: Some tests failed.
(exit 1)
```

Production-path reproduction (the exact invocation `zfa setup` makes,
`setup_command.dart:309-313`, against a root with no brand assets):

```
$ dart run repro_bug735.dart
brand asset source present in "CI clone": false (expected: false)
--- after zfa setup branding step ---
pubspec.yaml references assets/zuraffa_app_icons/: true
assets/zuraffa_app_icons/ exists on disk:            false
BUG 735 REPRODUCED: pubspec entry is DANGLING — flutter test would fail with
"Error: unable to find directory entry in pubspec.yaml"
(exit 1)

--- pubspec.yaml (verbatim) ---
name: zik_zak_tdd
flutter:
  uses-material-design: true
  assets:
    - assets/zuraffa_app_icons/
```

Root cause captured in `assessment.md`: `_copyBrandAssetsToAssets` returned
silently when `_brandAssetsSource` was absent, while `_updatePubspecAssets`
wrote the `assets/zuraffa_app_icons/` entry unconditionally — decoupled
reference and directory.

### GREEN — implementation present, behavior locked

Fix (single file, `lib/src/core/branding/branding_writer.dart`):

- `_copyBrandAssetsToAssets` creates the destination directory
  (`destDir.createSync(recursive: true)`) BEFORE the source-existence check and
  no longer silently skips when the source is absent — the directory is created
  (empty) so the pubspec entry can never dangle (Option B).
- `_updatePubspecAssets` defensively creates
  `assets/zuraffa_app_icons/` before injecting the pubspec entry, so a
  referenced-but-missing directory is impossible even if the copy step did not
  run (Option A / assessment Preferred).
- Idempotency preserved: the `content.contains('zuraffa_app_icons')` guard and
  the `destDir.existsSync()` early-return are untouched.

Verification:

```
$ dart test test/core/branding/branding_writer_test.dart
00:00 +13: All tests passed!   (11 pre-existing + 2 new bug-735)

$ dart run repro_bug735.dart
brand asset source present in "CI clone": false (expected: false)
--- after zfa setup branding step ---
pubspec.yaml references assets/zuraffa_app_icons/: true
assets/zuraffa_app_icons/ exists on disk:            true
NOT dangling: pubspec entry is backed by an existing directory
(exit 0)
```

- recorded: after implementation, branch `fix/735-zfa-setup-missing-assets-icons-dir`
- outcome: GREEN, no regressions in the branding suite.

### REFACTOR

None required (fix is 10 lines across two private methods; structure matches
the surrounding code).

- recorded: same session, branch `fix/735-zfa-setup-missing-assets-icons-dir`
