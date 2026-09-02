# Bug Assessment: zfa tdd init writes tdd-profile Commands bullets with stray trailing quotes (both Dart and Flutter profiles)

- **Slug**: tdd-profile-quotes
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/756
- **Verdict**: valid — confirmed by hand-repairs in two consumer repos
- **Severity**: medium — malformed CLI output, breaks copy-paste from tdd-profile Keys

## Report (verbatim or summarized)

`zfa tdd init` generates `.specify/memory/tdd-profile.md` whose **Commands** section is malformed: every bullet ends with a stray single quote outside the closing backtick. Both Dart and Flutter profiles affected — the defect lives in one shared render template. https://github.com/arrrrny/zuraffa/issues/756

## Symptom

Generated `tdd-profile.md` Commands bullets have a stray `'` after the closing backtick (e.g. ``--name "{name}"'$``). Commands copied from the Keys section are malformed; the machine-readable Keys block is unaffected.

## Reproduction

1. Run `zfa tdd init` on any project (Dart or Flutter).
2. Inspect `.specify/memory/tdd-profile.md` Commands section.
3. Each bullet ends with a stray `'` outside the closing backtick.

Confirmed in two consumer repos: `zuraffa_permissions`#4 (Flutter) and `zuraffa_auth` (Dart) — both hand-repaired.

## Suspected Code Paths

- `lib/src/cli/writers/tdd/tdd_profile.dart:168-171` — stray `'` after closing backtick in the four Commands bullets.
- `lib/src/plugins/tdd/models/tdd_profile.dart:22,30` — secondary: `--plain-name` vs `--name` drift between Flutter and Dart single-command templates.

## Root Cause Hypothesis

Template literal interpolation bug: each Commands bullet closes the backtick then emits a stray `'`. Likely a leftover from an earlier edit that removed the closing `'` inside the template literal but forgot the trailing `'` outside.

## Proposed Remediation

1. **Primary**: In `tdd_profile_writer.dart` lines 168–171, drop the stray `'` after each closing backtick.
2. **Secondary** (optional): Align `dart single` to `--plain-name` in `tdd_profile.dart:30` to match the Flutter variant.

Both are one-liner template fixes; regenerated profiles match the already-repaired hand fixes in consumer repos.

## Risks & Considerations

- Template fix only — no logic change.
- Aligning `--name` → `--plain-name` in the Dart profile is a behavioral change to the test matcher; should be verified against the TDD loop's targeting before merging.

## Open Questions

- [NEEDS CLARIFICATION: should the Dart profile's single command also switch to `--plain-name`, or just fix the stray quotes?]
