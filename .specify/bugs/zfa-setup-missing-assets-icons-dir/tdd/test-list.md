---
feature: zfa-setup-missing-assets-icons-dir
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 3
planned_at: 49496d5
updated_at: 49496d5
suite_baseline: green
---

# Test List: zfa setup must never leave a dangling assets/zuraffa_app_icons/ pubspec entry (bug #735)

Outer-only plan (no `plan.md` in the bug directory). Behaviors are derived from
`issue.md` and `assessment.md` (Proposed Remediation + Tests to add or update).

## Outer loop: acceptance behaviors

The real entry point is `BrandingWriter.writeFlutterBranding` — the exact method
`zfa setup` invokes (`lib/src/commands/setup_command.dart:309-313`). A full
`zfa setup --flutter` end-to-end run needs the Flutter SDK (`flutter create`),
which is unavailable in this environment; the acceptance tests drive the same
production method with a `zuraffaRoot` whose brand assets are absent, which is
the exact condition from the issue (minimal CI clone / `findZuraffaRoot`
failure).

| id  | behavior                                                                                                                   | traces | kind    | state    | test                                                                                                                                             |
| --- | -------------------------------------------------------------------------------------------------------------------------- | ------ | ------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| A1  | `writeFlutterBranding` creates `assets/zuraffa_app_icons/` in the target project even when the brand asset source is absent | AC-1   | example | DONE     | `test/core/branding/branding_writer_test.dart::bug 735 creates assets/zuraffa_app_icons/ when brand asset source is absent`                       |
| A2  | The pubspec entry written by branding is always backed by an existing directory (never dangling)                            | AC-2   | example | DONE     | `test/core/branding/branding_writer_test.dart::bug 735 pubspec assets entry is backed by an existing directory`                                   |
| A3  | The spec 053 contract is unchanged: the pubspec still gains the `assets/zuraffa_app_icons/` entry (fix is create-dir, not omit-entry) | AC-3 | example | DONE | asserted inside A2 (`content.contains('assets/zuraffa_app_icons/')`)                                                                              |

## Inner loop: unit behaviors

Backed by the same tests (the private helpers `_copyBrandAssetsToAssets` and
`_updatePubspecAssets` are exercised through the public entry point):

- `_copyBrandAssetsToAssets` must create the destination directory even when
  `_brandAssetsSource` is absent (no silent skip) — backs A1.
- `_updatePubspecAssets` must ensure the referenced directory exists on disk
  before injecting the entry (defensive gate) — backs A2/A3.

These are derived from `assessment.md` (Root Cause Hypothesis, Proposed
Remediation), not from `plan.md`.

## Invariants and edge cases still to place

- Idempotency must be preserved: the existing `content.contains('zuraffa_app_icons')`
  guard (U9/U11, spec 053) keeps re-runs from duplicating the entry; the new
  `createSync` calls are no-ops when the directory already exists.

## Out of scope

- Any file other than `lib/src/core/branding/branding_writer.dart` (hard
  constraint from the bug record).
- `writeDartBranding` pubspec handling (Dart packages have no `flutter:`
  assets block; the bug is Flutter-path only).
- Full `zfa setup --flutter` CLI end-to-end (requires Flutter SDK; not
  available in this environment — recorded in verification.md as a gap).

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (repo, disk-safe): `tools/run_tests_chunked.sh`
- Static analysis (full repo): `dart analyze`
