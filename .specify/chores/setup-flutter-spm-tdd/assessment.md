# Chore Assessment: zfa setup: --dart/--flutter, Flutter SPM defaults, clean test env per target

- **Slug**: setup-flutter-spm-tdd
- **Created**: 2026-08-29
- **Source**: https://github.com/arrrrny/zuraffa/issues/576
- **Verdict**: needs scoping
- **Size**: [NEEDS CLARIFICATION]

## Report (verbatim or summarized)

The `zfa setup <name>` command (in `lib/src/commands/setup_command.dart`) already supports
`--flutter` (default), `--dart`, and `--platforms`. The issue asks for three changes:

1. Make `--dart`/`--flutter` first-class explicit targets while keeping the mutual-exclusion guard.
2. Default Flutter platforms to `ios,android` (currently `ios,macos`) and pass
   `--swift-package-manager` to `flutter create` whenever iOS is in the platform list, to honor
   the constitution's SPM-only (no CocoaPods) rule at scaffold time.
3. Hand each target a runnable test environment: Flutter gets `test/` + a smoke test +
   `flutter_test` dev dep + `dart_test.yaml` (covered in detail by #575); Dart gets `test/` +
   `test` dev dep + a passing smoke test.

Pairs with #575 (which emits `test/` + `tdd-profile.md`); this issue owns the scaffolding flags
and the test runner per target. Full acceptance criteria are in the issue body.

## Summary

[NEEDS CLARIFICATION]

## Constitution Check

[NEEDS CLARIFICATION — read .specify/constitution.md and confirm the change honors its principles.]

## Affected Paths

[NEEDS CLARIFICATION — run /skill:speckit-chore-assess to locate the code/assets, or fill in manually.]

## Proposed Approach

[NEEDS CLARIFICATION — run /skill:speckit-chore-assess to propose an approach, or apply it directly with /skill:speckit-chore-implement.]

## Risks & Considerations

- Loaded from an existing GitHub issue; scoping is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: …]
