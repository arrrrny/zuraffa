# Test List: zfa setup references assets/zuraffa_app_icons/ but doesn't create it (bug 735)

---
feature: zfa-setup-missing-assets-icons-dir # bug dir (spec-kit feature resolver errors for bug work; resolved per the bug extension's per-bug layout)
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 3 # issue #735 acceptance: setup leaves no dangling pubspec reference; existing affected projects are repaired; non-flutter pubspecs are untouched
planned_at: 505969d4
updated_at: 505969d4
suite_baseline: green
---

Scope note: the branch's change is confined to
`lib/src/core/branding/branding_writer.dart` `_updatePubspecAssets` (the
assessment's "Preferred" remediation: ensure the referenced directory exists
before the pubspec entry is written or kept) plus regression tests in
`test/core/branding/branding_writer_test.dart`. `_copyBrandAssetsToAssets`'
graceful-degradation skip is intentionally untouched — the assessment's
preferred fix lives in the pubspec writer, where the invariant is enforced.

## Outer loop: acceptance behaviors

| id  | behavior                                                                                                                             | traces                                                  | kind             | state        | test                                                                                                                                                    |
| --- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------- | ---------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1  | After `zfa setup` branding on a project whose pubspec declares `flutter:`, `assets/zuraffa_app_icons/` exists on disk AND pubspec.yaml references it — `flutter test` can never hit "unable to find directory entry in pubspec.yaml" from this writer | Issue #735 "Bug Description" + assessment "Symptom"     | characterization | BASELINE (Flutter-toolchain end-to-end not runnable in this environment; covered one level down by U1–U4 through `writeFlutterBranding`) | — (encoded by U1/U3/U4 assertions) |

## Inner loop: unit behaviors

### `lib/src/core/branding/branding_writer.dart` (`_updatePubspecAssets` via `writeFlutterBranding`)

| id  | behavior                                                                                                     | traces                                                                                       | kind    | state | test                                                                                                                                                                                        |
| --- | -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------- | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| U1  | Brand asset source absent → the pubspec entry is written AND the referenced directory is created (no dangling reference) | Issue #735 root cause (silent-skip path)                                                      | example | DONE  | `test/core/branding/branding_writer_test.dart::BrandingWriter issue 735 — pubspec asset entry never dangles creates assets/zuraffa_app_icons/ when the brand asset source is absent`            |
| U2  | Pubspec already references the entry but the directory is missing (affected v6.1.0 project) → re-running setup repairs the directory without duplicating or removing the entry | Issue #735 "Workaround" made unnecessary; assessment "Risks & Considerations" idempotency note | example | DONE  | `test/core/branding/branding_writer_test.dart::BrandingWriter issue 735 — pubspec asset entry never dangles repairs a missing directory when the pubspec already references it`                 |
| U3  | Pubspec without a flutter block → nothing injected and no directory created (no eager side effects)           | assessment "Alternatives" trade-off guard                                                      | example | DONE  | `test/core/branding/branding_writer_test.dart::BrandingWriter issue 735 — pubspec asset entry never dangles injects nothing and creates nothing for a pubspec without a flutter block`         |
| U4  | `flutter:` block-style injection path (no `uses-material-design: true` anchor) → directory created alongside the entry | Issue #735; covers the second injection branch                                                | example | DONE  | `test/core/branding/branding_writer_test.dart::BrandingWriter issue 735 — pubspec asset entry never dangles creates the directory for the flutter: block-style injection path too`              |
