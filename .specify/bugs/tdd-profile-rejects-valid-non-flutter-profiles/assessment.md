# Bug Assessment: [zfa tdd init] TddProfileWriter rejects valid non-Flutter profiles on re-run (exact-content comparison too strict)

- **Slug**: tdd-profile-rejects-valid-non-flutter-profiles
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/680
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

`TddProfileWriter` (used by `zfa tdd init`) throws `StateError` and exits non-zero when an existing `tdd-profile.md` has valid-but-different content — even when the project kind (Dart vs Flutter) matches exactly. This blocks idempotent re-runs of `zfa tdd init` on any project that already has a profile.

The comparison is an exact byte-equality check of the generated template vs. the existing file. But the generated template uses hardcoded preset values (e.g. `runner: dart`, `single: 'dart test {file} --name "{name}"'`) that differ from valid custom profiles (e.g. `runner: "package:test (^1.24.0)"`, `single: 'dart test -n "{name}"'`).

## Symptom

`zfa tdd init` re-runs fail on any project whose `tdd-profile.md` was enriched by an ecosystem detector or manual author, even though the profile is valid and uses the same (Dart) runner family. Overwriting it with the less-detailed template would lose information.

## Reproduction

1. `zfa tdd init` runs successfully once on a pure Dart package.
2. The profile is later enriched (e.g. ecosystem detector adds `stacks: dart: { runner: "package:test (^1.24.0)", ... }`).
3. Run `zfa tdd init` again.
4. Error: `Bad state: tdd-profile.md already exists at ... with different content; refusing to overwrite.`

## Suspected Code Paths

- `lib/src/cli/writers/tdd/tdd_profile_writer.dart:23-63` — `write()` does exact `existing.trim() == content.trim()` comparison and throws `StateError` on any difference.
- `lib/src/cli/writers/tdd/tdd_profile_writer.dart:73-79` — `_extractRunner()` reads the `runner:` value from the YAML frontmatter (helper already exists but was not wired into the guard).

## Root Cause Hypothesis

The overwrite guard is exact byte-equality against the generated template. But the template's `single:` value (`'dart test {file} --name "{name}"'`) differs from valid custom profiles (`'dart test -n "{name}"'`) — both are valid. The only meaningful conflict is a Flutter-vs-Dart flavor mismatch. Confidence: **high** — the helper `_extractRunner` already exists and the fix is a mechanical swap of the guard logic.

## Proposed Remediation

**Preferred**: In `TddProfileWriter.write()`, replace the exact-content guard with a runner-family check:
1. Extract the runner value from the existing frontmatter (`_extractRunner(existing)`).
2. If the existing runner is Flutter (`flutter_test`/`flutter`) AND we are writing a Dart profile → throw (genuine flavor conflict).
3. If the existing runner is non-Flutter → return `null` (accept the existing profile as-is; it is valid and overwriting would lose information).
4. If the existing runner is Flutter and we are writing a Flutter profile → fall back to the exact-content match (identical = no-op, otherwise throw).

**Files likely to change**:
- `lib/src/cli/writers/tdd/tdd_profile_writer.dart`

**Tests to add or update**:
- `zfa tdd init` on a project with a valid custom Dart profile (different `single:`/`suite:` values) → exits 0, no overwrite, no `StateError`.
- `zfa tdd init` on a project with a Flutter profile while targeting Dart → still throws (flavor conflict preserved).
- `zfa tdd init` on a project with an identical profile → no-op (exits 0).

## Risks & Considerations

- Accepting any non-Flutter runner could hide a genuinely broken profile; the runner-family check is intentionally narrow (Flutter-vs-Dart only).
- The `single:`/`suite:` template values are validated downstream by `SingleTestRunner`; an invalid runner family is caught there, not here.

## Open Questions

- None blocking.