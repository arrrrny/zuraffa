# Bug Fix: contract BLOCKED dead-ends the resume path + poisons the phase-2 refactor pass

- **Slug**: 1589-contract-blocked-dead-end-resume
- **Fixed**: 2026-09-13
- **Assessment**: ./assessment.md
- **Verification**: ./test.md
- **Status**: applied (verified — see ./test.md)
- **TDD artifacts**: `tdd/test-list.md`, `tdd/verification.md` (repo root)
- **Branch**: `fix/1589-contract-blocked-dead-end-resume`
- **Closes**: #1589

## Tooling note (spec-kit)

The repo already carries an initialized `.specify/` tree with the `bug` and
`tdd` extensions installed (`.specify/extensions.yml`) — re-running
`specify init` / `specify extension add` risked clobbering exactly the
templates and scripts the workflow says to preserve (the task's own warning,
and the precedent recorded in
`.specify/bugs/1544-parks-forever-on-first-blocked-contract/fix.md`). The
specify CLI (v1.0.7.dev0) was installed via `uv tool install specify-cli
--from git+https://github.com/github/spec-kit.git` and its
`init --integration zed` / `extension add bug` flows were exercised against a
throwaway scratch directory to prove the toolchain; the extension commands'
established artifact conventions (as exercised by the #1544 bug directory and
friends) were then followed directly. No template or script was modified.

## Summary

Three defects made a BLOCKED contract (issue #1007) a dead end and a
refactor-gate poison. The BLOCKED verdict itself, the contract lane and the
state machine are untouched — only messaging, make's precondition stop, and
the refactor gate's tolerance changed.

## Changes

1. **Blocked stop names the hand surface** — `run_driver_core.dart` (the
   issue-#1007 park arm and the terminal `result=blocked` block) and
   `verify_red_command.dart` (the blocked verdict's stderr). Every blocked
   stop now prints
   `hand surface: seam <seam-test-path> — implement the declared contract <trace> there (e.g. `zfa tdd wire <id> --entity <E>`)`.
   The seam path resolves the #827 namespaced file first, the legacy flat
   fallback second, and falls back to the canonical expected path when the
   file is absent; the entity is derived from the dotted contract trace
   (`User.validateEmail` -> `User`). Shared vocabulary lives in the new
   `lib/src/plugins/tdd/services/hand_surface.dart` (`HandSurface`).
   Messaging only — the verdict, the state advance, `stopped_at`, and the
   exit code are the #1007/#1544 ones (pinned by the new tests and by the
   untouched `contract_kind_1007_test.dart` pins).

2. **`make` accepts the blocked verdict as the precondition state it is**
   — `make_command.dart`. When the target is a CONTRACT-kind behavior, the
   blocked verdict receipt (`contract-blocked.<id>.json`) exists, and the
   #1544 watch set (seam file, contract row, `lib/`) is UNCHANGED since
   `blocked_at`, the not-certified-red refusal becomes the plain,
   actionable stop: "implement seam first" + the hand-surface line + the
   verify-red re-check, with the new `implement-seam-first` outcome token
   (`models/generation_plan.dart`). Fail-open by construction: any change
   signal, a missing/unreadable receipt, or a non-contract target keeps
   the existing refusal byte-for-byte — an in-progress unblock (the #1544
   review-fix flow) or a stale receipt is never misdirected, and the
   #1542 `--born-green` attestation stays the sanctioned recovery for a
   satisfied contract. Exit 1, no green entry, no state advance.

3. **Parked behaviors exempt from the phase-2 refactor gate** —
   `run_driver_core.dart` + `step_runner.dart` + `refactor_command.dart`.
   The driver collects the parked seams it KNOWS about — persisted
   blocked contracts with a receipt on disk (cross-lane/resume parkings,
   fail-closed on a missing receipt), the still-blocked skips, and this
   run's parkings — and hands them to every refactor spawn as
   `--parked-seam <test-path>` (repeatable; refactor spawns only). The
   refactor gate tolerates suite failures whose file matches a handed
   seam in BOTH the preflight and the re-proof — pre-existing-failure
   economics for the parked verdict (the same discipline issue #922 gave
   the baseline, composable with it). Surgical: a NEW failure outside the
   handed seams still refuses/regresses, an unparseable transcript still
   fails closed, and a flag-less standalone refactor keeps the
   absolute-green contract (spec 048 FR-001). The tolerance prints the
   exact tolerated identifiers marked `parked contract` so the evidence
   stays honest.

## Hard-constraint audit

- BLOCKED verdict, contract lane, state machine: untouched (the park arm's
  advance/stop contract, the receipt writer, and the #1544 skip are
  byte-identical; new suites pin them).
- `dart analyze`: touched files clean; whole-repo 112 info / 0 errors /
  0 warnings — identical to the pre-change baseline.
- Scope: blocked-stop messaging (1), make precondition (2), refactor gate
  for parked behaviors (3). Nothing else.
