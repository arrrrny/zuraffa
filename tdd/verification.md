# tdd.verify — Bug #1660 a skipped refactor pass is indistinguishable from an executed one on stdout — print the skip note

- **Verified**: 2026-09-17, this session, on
  `fix/1660-refactor-skip-note-stdout` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: `lib/src/plugins/tdd/commands/refactor_command.dart` (the pass
  print loop + the two cycle-log `capturedOutput` branches), the new
  `test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart`, and the
  spec artifacts under `.specify/specs/1660-refactor-skip-note-stdout/`.
- **Command audit**: `/speckit.tdd.verify` Step 0 — `zfa --version` is not
  on PATH in this sandbox and the repo root has no `.zfa.json` →
  ZFA_MISSING → the command's documented FALLBACK PATH (LLM-guided audit:
  red-phase evidence, acceptance-criteria coverage, mutation-style checks
  on the changed file, verdict). The verdict below is built from the real
  runs in this session only — nothing copied or back-dated.

## Verdict: PASS

## 1. TDD discipline (red → green → verify, REAL runs in this session)

The loop was driven with the spec directory as the TDD feature. The
behaviors were pinned in `tdd/test-list.md` BEFORE the fix, mapped 1:1 to
the spec's success criteria, and the red set was observed failing against
unmodified master (`a9329746`) for exactly the reason the issue describes —
never for a setup error.

RED, pre-fix (verbatim excerpt in `tdd/test-list.md`):

```
dart test test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart --preset=all
→ U-1660-1 [E]  Expected: contains 'pass: build — SKIPPED (build-relevance gate)'
                Actual: '...   pass: build\n ...'   ← identical to an executed pass
→ U-1660-3 [E]  Expected: contains 'note: refactor build pass skipped:'
→ 00:21 +0 -3: Some tests failed.
   (U-1660-2 — the executed-shape guard — passed pre-fix, as a guard must)
```

GREEN, post-fix (same suite, same command):

```
dart test test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart --preset=all
→ 00:22 +3: All tests passed!
```

The fix was applied only after the repro suite was proven red; no test was
edited to make it pass retroactively. Gate semantics untouched (hard
constraint): `git diff --stat` = one production file
(`refactor_command.dart`, +34/−1 lines of printing) + the new test file +
the artifacts.

## 2. Verbatim post-fix transcript (the issue's acceptance shape)

Captured via a throwaway print-harness run of the REAL command
(harness deleted after capture; not part of the deliverable):

```
zfa tdd refactor: applying passes
   pass: build — SKIPPED (build-relevance gate)
     command: /tmp/tdd_fixture_BQQBMS/fake_bin/zfa build
     exit: 0
     changed: (none)
     note: refactor build pass skipped: every file newer than the build_runner
     asset graph is un-annotated plain Dart, or a config file whose bytes are
     identical to the digests the last completed build consumed (issue #1637)
     — nothing newer than that asset graph can feed a builder. A path DELETED
     since that build is invisible to this gate ... so these plain-Dart writes
     were not analyzer-graded.
   pass: format
     command: dart format lib/
     exit: 0
     duration: 0.0s
     changed: (none)
   pass: fix
     ...
refactor: feature=090-tdd-fixture outcome=clean applied=0
```

(verbatim, line-wrapped here only for the document) — and the refactor
cycle-log entry's `- output:` block now carries the mirrored
`note: refactor build pass skipped: ...` line between the re-proof block
and `applied: 0 actions.`

## 3. Static gates (REAL runs)

```
dart analyze lib/src/plugins/tdd/commands/refactor_command.dart
dart analyze test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart
→ No issues found!                          (both changed files, zero findings)

dart analyze                                (whole repo)
→ 208 issues found                          — IDENTICAL on clean master
  (`git stash` A/B this session; all pre-existing, in the workspace
  sub-packages, none in the changed files)

dart format --output=none --set-exit-if-changed .
→ Formatted 2944 files (0 changed)          (exit 0 — zero drift repo-wide;
  the one initial drift was in the new test file itself and was formatted)
```

## 4. Regression audit (all REAL runs, this session)

Changed-file semantic neighbors:

```
dart test test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart --preset=all
→ +3: All tests passed!                                (the new suite)

dart test test/plugins/tdd/services/refactor_passes_test.dart
          test/plugins/tdd/services/build_relevance_test.dart --preset=all
→ +58: All tests passed!   (the #1624/#1634/#1637 gate contracts — UNTOUCHED)

dart test test/plugins/tdd/models/ --preset=all
→ +86: All tests passed!   (RefactorAction + CycleLogEntry renderers)

dart test test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart
          test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart --preset=all
→ +9: All tests passed!    (duration lines + the console-excerpt tail over
                            the refactor transcript)

dart test test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart
→ +9: All tests passed!

dart test test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart
          test/plugins/tdd/bug_1520_refactor_scratch_tmpdir_test.dart --preset=all
→ +10: All tests passed!

dart test test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart --preset=all
→ +12: All tests passed!

dart test test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart --preset=all
→ +16: All tests passed!

dart test test/plugins/tdd/refactor_command_test.dart --preset=all
→ +13 -1  (the -1 is A12 — see the pre-existing-failures audit below)
```

Fast-tier folders (the CI lane; `-j 2` after a disk-pressure lesson):

```
dart test test/plugins/tdd/services → +1157: All tests passed!
dart test test/plugins/tdd/models   → +86: All tests passed!
dart test test/plugins/tdd/commands → +549/-3 … +551/-1 across runs — every
  flagged failure is a DIFFERENT test per run (bug_1625, replay A5,
  plan_fr_manual_1484, plan_marker_emission_1186) and each passes in
  isolation WITH the change (+11, +1, +5, +16: All tests passed!). Shared-
  tmpfs flakiness under parallel temp-project load, pre-existing
  environment noise — the same class the #1664 verification recorded.
```

## 5. Pre-existing failures audit (flagged, NOT caused by this fix)

Proven via `git stash` A/B — each fails IDENTICALLY on clean master
`a9329746` with the fix stashed:

| test | failure | root cause (pre-existing) |
| ---- | ------- | -------------------------- |
| refactor_command_test A12 | `Expected: contains 'build' / Actual: []` (fake-zfa log empty) | #1634's static first-build skip fires on the fresh fixture → the build pass never spawns; the test predates #1634 and was never updated. Slow-tagged (outside the CI fast lane). |
| bug_1472 acceptance A-1472-1 | `Expected: contains '0 error(s), 2 warning(s)'` | same #1634 root cause: the build pass is skipped, so the scripted fake-zfa refusal never happens. |
| bug_1472 acceptance A-1472-2 | same shape | same root cause. |
| bug_1540 A6/A7 | restore/refusal scenarios never engage | same root cause: the build pass that deletes the placeholder never spawns on a fresh fixture. |

All four are slow-lane integration suites broken by #1634's gate (merged
2026-09-15), not by this fix — this fix changes only what a skipped pass
PRINTS. They are flagged here for the maintainer; fixing them is a
different spec.

## 6. Acceptance criteria audit (spec 1660)

1. **SC-1 (SKIPPED marker)** — PROVED: U-1660-1 asserts the exact header
   `pass: build — SKIPPED (build-relevance gate)` on a run where the gate
   (real, unmodified) skipped the pass; the transcript shows it.
2. **SC-2 (note surfaced)** — PROVED: U-1660-1 asserts the `note:` line and
   its distinctive content markers (`refactor build pass skipped:`,
   `issue #1637`, `DELETED`), i.e. the FULL gate note reaches stdout
   verbatim, including the config-digest clearance and the deleted-source
   caveat.
3. **SC-3 (executed unchanged)** — PROVED by construction (both new stdout
   branches fire only on `action.skipped`) and by U-1660-2, which pins the
   executed shape end-to-end: plain `   pass: build` header, the command
   line, and the fake-zfa invocation log proving a real spawn; asserts the
   ABSENCE of the marker and the note line.
4. **SC-4 (cycle-log mirror)** — PROVED: U-1660-3 reads the refactor entry
   from the real cycle log and asserts the mirrored
   `note: refactor build pass skipped:` line; entries with no skip render
   byte-identically (the mirror block is the empty string then).

Hard constraints honored: the #1624 gate's decision semantics and skip
timing are untouched (`build_relevance.dart`, `refactor_passes.dart` not in
the diff — verified by `git diff --stat`: 1 production file, +34/−1); one
PR per spec.

## 7. Verdict

PASS — a skipped refactor pass is now distinguishable from an executed one
at a glance (`— SKIPPED (build-relevance gate)` + the gate's full note on
stdout, mirrored into the cycle-log entry), executed-pass output is
byte-identical to before, the gate that decides the skip is untouched, and
the evidence above is from real runs in this session.
