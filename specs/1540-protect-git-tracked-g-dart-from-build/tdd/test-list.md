---
feature: 1540-protect-git-tracked-g-dart-from-build
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 9
planned_at: manual
updated_at: manual
suite_baseline: green
---

# Test List: Protect git-tracked `.g.dart` placeholders (restore-or-refuse)

Baseline: fast tier (`dart test test/core/generation/
test/commands/build_command_unit_test.dart`) green at feature start.
Git-dependent tests create real `git init` sandboxes in system temp and
`skip` when the `git` binary is unavailable, so the suite stays portable.

## Outer loop: acceptance behaviors

One per measurable success criterion in `spec.md`.

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | Tracked placeholder deleted by the build exists again byte-identical after recovery; output names it + docs ref | SC-1 / US1.AC1 | example | GREEN  | test/core/generation/tracked_generated_output_guard_test.dart |
| A2  | Forced restore failure → refusal naming `git checkout -- <path>` (build command exits non-zero) | SC-2 / US1.AC2 | example | GREEN  | test/commands/build_command_tracked_outputs_test.dart |
| A3  | Non-git sandbox → guard silent, no behavior change | SC-3 / US1.AC3 | example | GREEN  | test/core/generation/tracked_generated_output_guard_test.dart |
| A4  | Regenerated tracked `.g.dart` (exists pre ∧ post) never reported or rewritten | SC-4 / US1.AC4 | example | GREEN  | test/core/generation/tracked_generated_output_guard_test.dart |
| A5  | Gate: tracked missing part → message contains `git checkout -- <path>`; untracked → unchanged message | SC-5 / US2.AC1-2 | example | GREEN  | test/commands/build_command_tracked_outputs_test.dart |
| A6  | Refactor build pass: fake-zfa deletion of tracked placeholder undone; action output records restoration; exit 0 | SC-6 / US3.AC1,AC3 | example | GREEN  | test/plugins/tdd/bug_1540_refactor_tracked_restore_test.dart |
| A7  | Refactor build pass: restore impossible → stop on `build`, refusal + remedy, exit ≠ 0 | SC-7 / US3.AC2 | example | GREEN  | test/plugins/tdd/bug_1540_refactor_tracked_restore_test.dart |
| A8  | Docs page contains both builder exclusion YAML keys | SC-8 / US4.AC1 | example | GREEN  | test/commands/build_command_tracked_outputs_test.dart (doc-content assertions) |
| A9  | Full suite + analyze + format gates green | SC-9 | example | GREEN  | dart analyze / dart test / dart format |

## Inner loop: unit behaviors

| id  | behavior | kind | state | test |
| --- | -------- | ---- | ----- | ---- |
| U1  | `git ls-files -z` parse: NUL-separated paths, project-relative, suffix-filtered | unit | GREEN  | tracked_generated_output_guard_test.dart |
| U2  | capture(): membership = tracked ∧ exists; bytes captured | unit | GREEN  | tracked_generated_output_guard_test.dart |
| U3  | capture(): disabled (empty) outside a git work tree | unit | GREEN  | tracked_generated_output_guard_test.dart |
| U4  | detectDeleted(): only snapshot members absent post-build | unit | GREEN  | tracked_generated_output_guard_test.dart |
| U5  | restore(): writes exact pre-build bytes (unstaged edits preserved) | unit | GREEN  | tracked_generated_output_guard_test.dart |
| U6  | restore(): failure bucket populated when the write cannot succeed (parent dir gone) | unit | GREEN  | tracked_generated_output_guard_test.dart |
| U7  | restoreRemedyLines(): contains `git checkout -- <path>` + doc ref | unit | GREEN  | tracked_generated_output_guard_test.dart |
| U8  | BuildCommand recovery helper: restores + prints FR-3 message (owning library, both excludes, doc ref) | unit | GREEN  | build_command_tracked_outputs_test.dart |
| U9  | Refusal helper returns failure + prints remedy (build command) | unit | GREEN  | build_command_tracked_outputs_test.dart |

## Red discipline

T001 ships the guard as a compiling no-op stub; A1–A9/U1–U9 land BEFORE the
real implementation (T003/T004/T006/T008) and the recorded red run must show
behavior-level failures (assertions/expectations), not compile errors. Red evidence: `tdd/red-run.md`; green evidence: `tdd/verification.md`.
