# Cycle Log: zfa-setup-missing-assets-icons-dir (bug 735)

Append-only. One entry per cycle. All evidence below is from real runs in the
session that produced the branch
`fix/735-zfa-setup-missing-assets-icons-dir`.

## Baseline

- Date: 2026-09-02 — HEAD: `505969d4` — suite baseline: green for the file
  under change
- The pre-existing 11 tests in `test/core/branding/branding_writer_test.dart`
  were green at `505969d4` before any change (U1–U11 in the run order shown
  in `red-evidence.log` before the new group executes).
- The issue's literal signature (`flutter test` → `Error: unable to find
  directory entry in pubspec.yaml`) is a Flutter-toolchain error and requires
  a Flutter SDK. The tdd-profile declares the root package pure-Dart; the RED
  below encodes the same defect one level down, at the code that produces it:
  after `writeFlutterBranding`, pubspec.yaml references
  `assets/zuraffa_app_icons/` while the directory does not exist — the exact
  on-disk state Flutter's asset resolver later rejects (issue.md
  "Confirmation", assessment.md "Symptom").
- Bug scenario simulated in-process with a `BrandingWriter(zuraffaRoot:)`
  pointing at a root WITHOUT `assets/zuraffa_app_icons/` (the
  minimal-CI-clone / `findZuraffaRoot`-failure / globally-activated-zfa
  path from assessment.md "Root Cause Hypothesis").

## Cycle 1 — R1: directory created when brand asset source is absent

- RED (fix not yet written; new regression group added to
  `test/core/branding/branding_writer_test.dart` at `505969d4`; output
  verbatim below):
  - Command: `dart test test/core/branding/branding_writer_test.dart`
  - Output (3 of the 4 new tests fail; R3 is the no-injection freeze and
    passes on both sides):
    ```
    00:00 +8 -1: BrandingWriter issue 735 — pubspec asset entry never dangles creates assets/zuraffa_app_icons/ when the brand asset source is absent [E]
      Expected: true
        Actual: <false>
      the referenced directory must exist — a dangling pubspec entry breaks every flutter test run (issue #735)

    00:00 +8 -2: BrandingWriter issue 735 — pubspec asset entry never dangles repairs a missing directory when the pubspec already references it [E]
      Expected: true
        Actual: <false>
      re-running setup on an affected project must repair the dangling entry instead of leaving it broken (issue #735)

    00:00 +9 -3: BrandingWriter issue 735 — pubspec asset entry never dangles creates the directory for the flutter: block-style injection path too [E]
      Expected: true
        Actual: <false>
      entry and directory must stay in sync (issue #735)

    00:00 +12 -3: Some tests failed.
    ```
  - Failure mode matches the bug: the pubspec-entry assertion passes (the
    entry IS written) and the directory-exists assertion fails (the directory
    is NOT created) — the dangling reference from issue #735.
- GREEN (fix in `lib/src/core/branding/branding_writer.dart`
  `_updatePubspecAssets`: create the referenced directory before the entry is
  written or kept):
  - Command: `dart test test/core/branding/branding_writer_test.dart`
  - Output: `00:00 +15: All tests passed!`
- Refactor: none required (`dart format` clean, `dart analyze` clean).

## Test strength sampling (deliberate mutants, post-green)

No mutation tool is wired for this repo (tdd-profile), so deliberate mutants
were sampled on the changed surface (`_updatePubspecAssets` in
`lib/src/core/branding/branding_writer.dart`). Each mutant was restored
exactly (verified with `git diff`) and the suite re-run green before the next
step.

| Mutant | Expected guard | Result |
| ------ | -------------- | ------ |
| Mutant 1 — directory-creation guard dropped (`if (false && !iconsDir.existsSync()) ... createSync`) — reinstates the bug | R1/R2/R4 directory-exists assertions | CAUGHT — exit 1, `+12 -3`: exactly the 3 regression tests fail (R1 "the referenced directory must exist", R2 "must repair the dangling entry", R4 "entry and directory must stay in sync") |
| Mutant 2 — pubspec injection disabled (`willInject = false && ...`) — the entry is never written | R1/R4 pubspec-entry assertions (and pre-existing U4) | CAUGHT — exit 1, `+13 -2`: R1 and R4 fail on the missing `assets/zuraffa_app_icons/` reference; R2 correctly unaffected (its pubspec already carries the entry) |

Sampled: 2 mutants, both caught. Restore verified: suite green (`00:00 +15:
All tests passed!`) after each mutant.
