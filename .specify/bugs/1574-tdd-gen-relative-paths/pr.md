# Bug Fix PR: tdd gen — use relative paths for test_path/subject_path; migrate registries

- **Slug**: 1574-tdd-gen-relative-paths
- **Opened**: 2026-09-13T19:00:00-07:00 (previous session)
- **PR**: 1613
- **URL**: https://github.com/arrrrny/zuraffa/pull/1613
- **Branch**: fix/1574-tdd-gen-relative-paths
- **Issue**: 1574 (`Closes #1574` in the PR body)

The single PR for this bug (one PR per bug). Opened from the fix branch,
reviewed (bot reviews + the maintainer's review-findings-resolution comment
applied in `9a754f4c`).

## 2026-09-14 refresh (this session)

`master` advanced to `2aac31d8` after the review, leaving the PR `behind`.
This session merged the moved master into the branch
(`a9a2589a`, fast-forward push — no history rewrite) and re-verified:

- `dart test --preset=all test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart`
  → 6/6 green on the merged tree.
- Migration census on the merged tree: 16 tracked registries in the
  `migrate-paths` scan, 0 absolute recorded paths (no new drift from the
  master move).
- `dart analyze` (3 touched files): no issues; `dart format --set-exit-if-changed`:
  0 changed.
- Pre-existing master failures confirmed by A/B on detached `origin/master`
  (identical with and without the branch): `gen_namespacing_827_test` (5)
  and `bug_1397_path_form_mismatch_test` (2) fail on the moved master —
  the #1528 auto-init misfires in pubspec-less fixtures
  (`pubspec_dev_dependencies_patcher: Bad state: pubspec.yaml not found`
  → `setup-error`). Unrelated to this fix.
- Verification note posted on the PR:
  https://github.com/arrrrny/zuraffa/pull/1613#issuecomment-5655602313

## Duplicate-work note

An independent re-implementation of this same bug was produced in a
parallel session (writer-normalization approach on master `71ff365f`,
2 commits). It was DISCARDED in favor of this reviewed branch after
discovery: the reviewed branch additionally fixes the
`ArtifactRegistry.projectRoot` anchoring for the `.specify/bugs/<slug>`
lane (required for the bug-dir registries the issue's concrete instance
lives in) and its migration covered the 1444 registry the master move
added. Nothing from the duplicate was pushed.
