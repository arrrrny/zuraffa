# Implementation Plan: 1660-refactor-skip-note-stdout

- **Branch**: fix/1660-refactor-skip-note-stdout
- **Spec**: .specify/specs/1660-refactor-skip-note-stdout/spec.md
- **Date**: 2026-09-17

## Technical Context

Language/Version: Dart SDK ^3.11.0 (resolved 3.13.4 in this workspace),
pure-Dart package. Key files:

- `lib/src/plugins/tdd/commands/refactor_command.dart` — the ONLY production
  file touched. Two seams, both in the command (never the services):
  1. The pass-result print loop (`for (final action in passResult.actions)`)
     that renders `pass/command/exit/duration/changed` + the `[1540]`-tagged
     lines (spec 1540 precedent) — the stdout surface.
  2. The two cycle-log append branches (`applied == 0` clean no-op and the
     `refactored` branch) whose `capturedOutput` string carries the
     preflight/re-proof block (FR-007/FR-008) — the cycle-log surface.
- `lib/src/plugins/tdd/models/refactor_action.dart` — `RefactorAction.skipped`
  (#1624) and `output` (the gate's note on a skipped action) already exist;
  consumed, not modified.
- `lib/src/plugins/tdd/services/build_relevance.dart` — the gate and its
  `refactorBuildSkippedNote` constant; UNTOUCHED (hard constraint).
- `lib/src/plugins/tdd/services/refactor_passes.dart` — records the
  synthetic skipped action (`skipped: true`, `exitCode: 0`,
  `filesChanged: const []`, `output: note`, `duration: null`); UNTOUCHED.
- `test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart` — NEW
  driver-level suite (the repo's `bug_NNNN_*_test.dart` convention,
  slow+integration tagged like every sibling).

## Technical Decisions

### D1 — Fix in the command's print loop, not the registry or the model

The pass registry already records everything an operator needs; the gap is
presentation. Changing `RefactorAction` or `RefactorPasses` would touch the
#1624 contract surface (forbidden). The print loop is the single place every
pass reaches stdout — the narrowest blast radius (one ternary on the header,
one additive note line).

### D2 — Marker wording: `— SKIPPED (build-relevance gate)` on the pass line

The issue's own suggested shape. On the pass line (not a following line) so
a transcript scan or an agent's grep for `pass: build` still matches the
prefix, and the skip is visible without reading the block. Generic label
matches the cycle-log renderer's existing generic skip note
(`cycle_entry.dart`: "the pass had no build-relevant input") — both
`refactorBuildSkippedNote` (#1624) and `staticFirstBuildSkippedNote` (#1634)
are decisions of the same build-relevance gate, and the command never needs
to distinguish them to print honestly (the full note text carries the
specifics).

### D3 — Note printed verbatim as one line, positioned like the [1540] evidence

`refactorBuildSkippedNote` is a single-line constant (no embedded newlines)
by construction, so `     note: <output.trim()>` is one line. Printed AFTER
`changed:` — the same slot the `[1540]`-tagged evidence lines use — keeping
the executed-pass line sequence intact above it. A skipped action's
`duration` is null (nothing ran, #1653's contract) so no duration line
appears, exactly as before.

### D4 — Cycle-log mirror: one note line inside `capturedOutput`, both branches

The clean-no-op branch (FR-008) renders NO actions block at all, and the
refactored branch's actions block carries only the generic per-action note
(`cycle_entry.dart`) — neither surfaces the gate's actual evidence. One
`note: <gate note>` line is appended to `capturedOutput` in BOTH branches
when the registry recorded a skip (first skipped action's output verbatim;
empty string → no line → byte-identical entry). This is the optional mirror
the issue suggests; it makes the honest-skip evidence auditable in the
cycle log for both outcomes.

### D5 — Executed-pass output unchanged: guarded by construction + test

Both new stdout branches fire ONLY on `action.skipped`; both new
cycle-log branches fire ONLY when a skipped action exists. U-1660-2 pins
the executed shape end-to-end (real fake-zfa spawn proven via the
invocation log) and fails if the executed shape ever grows the marker or
the note line.

## Verification plan

- RED first: the new suite must fail pre-fix on exactly the missing marker
  + note (U-1660-1, U-1660-3) — observed.
- GREEN post-fix: same suite 3/3 — observed.
- Regression: the changed file's semantic neighbors
  (refactor_command_test, services/refactor_passes + build_relevance,
  models, bug_1412/1653/922/1311/1520/1652/1588-phase2) green; known
  pre-existing slow-lane failures (1472 A1/A2, refactor_command A12,
  1540 A6/A7 — all rooted in #1634's static skip on fresh fixtures)
  proven identical on clean master via `git stash` A/B.
- `dart format` gate + `dart analyze` on changed files (zero findings;
  whole-repo count identical to master baseline).
