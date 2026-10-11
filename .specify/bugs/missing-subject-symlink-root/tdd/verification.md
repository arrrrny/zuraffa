---
feature: missing-subject-symlink-root
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: fix/missing-subject-symlink-root
behaviors: 2
proven: 2
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 2
criteria_covered: 2
mutation_score: sampled # no mutation tool wired (tdd-profile.md Phase 4 fallback); 2 deliberate mutants, both killed
mutants_survived: 0
suite: view_command_test.dart 12/12 (incl. U-V3, U-V11, U-V12); sibling view surface 29/29; dart analyze on both changed files exit 0 (No issues found); dart format 0 changed. macOS / Dart 3.13.x, 2026-09-13.
---

# TDD Verification: missing subject misreported as outside-root on symlinked roots (#1603)

**Verdict: PASS.** `zfa tdd view` now canonicalizes a *missing* subject
through its nearest EXISTING ancestor before the outside-root comparison, so
a symlinked project root (macOS `/var/folders` → `/private/var/folders`)
produces the missing-subject refusal instead of the outside-root refusal —
the same shape `wire_command.dart` carries since `c1e287da` (pull/1516
review). A new cross-platform regression pin (U-V11) makes the case
deterministic on every OS, and a guard pin (U-V12) holds the genuine
outside-root refusal unchanged.

## What the run proved (fresh, this branch)

1. **RED was honest** (`tdd/cycle-log.md`): U-V11 failed pre-fix with the
   issue's exact signature — the refusal printed `points outside the project
   root` (assertion `contains 'missing subject file'` failed), exit 1 — while
   the U-V12 guard passed pre-fix. The pre-existing U-V3 was also red on
   macOS pre-fix for the same reason (the fixture temp root itself traverses
   `/var` → `/private/var`).
2. **GREEN is real**: `dart test
   test/plugins/tdd/commands/view_command_test.dart` → `00:51 +12: All tests
   passed!` — U-V3 turned green (the original red), U-V11 green, U-V12
   stayed green.
3. **Mutation sampling** (no mutation tool wired per `tdd-profile.md`; two
   deliberate mutants, both applied one at a time and reverted):
   - **M1 — identity canonicalization** (the pre-fix shape:
     `canonicalSubject = subjectPath;`) → **killed by U-V11** (`does not
     contain 'missing subject file'`), U-V12 unaffected.
   - **M3 — outside-root guard disabled** (`if (false && …)`) → **killed by
     U-V12** (`does not contain 'points outside the project root'`),
     U-V11 unaffected.
   - Both mutants reverted; the restored tree re-ran green (`+12`) and the
     diff matches the intended fix (`view_command.dart | 31 ++++++++-`,
     30 insertions / 1 deletion).
   - Mutations that preserve the observable branch contract (e.g. a helper
     returning only the resolved ancestor directory) survive by construction:
     the pinned contract is *which refusal fires and what it says*, not the
     internal canonical string — asserting the latter would pin an
     implementation detail (test smell).
4. **No collateral damage**: the sibling view-command surface —
   `bug_1141_view_audit`, `bug_965_view_i18n_generation`,
   `bug_1141_login_ui_regeneration`, `spec_1142_adaptive_layout` — reports
   `00:38 +29: All tests passed!`
5. **Static hygiene**: `dart analyze` on both changed Dart files → `No
   issues found!`; `dart format` on both → `0 changed`.
6. **Constraint compliance**: `git status` touches exactly
   `lib/src/plugins/tdd/commands/view_command.dart` (one catch-block call +
   one private static helper) and
   `test/plugins/tdd/commands/view_command_test.dart` (two pins + a
   `runView` project override), plus the `.specify/bugs/<slug>/` artifacts.
   No runtime behavior changed outside the refusal-branch selection.

## Criteria coverage

| Criterion | Evidence |
| --- | --- |
| FR-001 — a missing subject on a symlinked root is the missing-file refusal | U-V11 (red→green: exact issue symptom pre-fix), U-V3 (red→green on macOS) |
| FR-002 — a genuinely-outside subject is still refused as outside-root | U-V12 (green pre-fix and post-fix; killed mutant M3) |

## Test-quality notes

- U-V11 builds the symlinked root explicitly (`Link('<root>_link')` →
  fixture root) instead of relying on macOS's temp-root symlink, so the pin
  is deterministic on Linux CI too; the link is removed via `addTearDown`
  (`FileSystemEntity.isLink` guard covers a dangling link).
- Both new pins assert on the observable refusal message and exit code (the
  command's public contract), never on internal paths.
- No sleeps, no randomness, no conditional assertions in test bodies
  (`high_smells: 0`).
