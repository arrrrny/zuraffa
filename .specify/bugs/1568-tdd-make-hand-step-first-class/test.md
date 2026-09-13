# Verification — SPEC 1568 `tdd make` hand-step first-class run state

- **Verified**: 2026-09-14, this session, on `feat/1568-tdd-make-hand-step-first-class`
- **Full gate**: `tdd/verification.md` (repo root) — verdict **PASS**

## Summary

- RED (pre-fix): the #1568 wall reproduced verbatim — the entity-return
  contract subject's post-generation red graded `generation-error`
  (red-evidence.md).
- GREEN (post-fix): 19/19 new-suite tests pass (fast tier + make
  integration with real `dart test` children).
- Mutants: 3/3 killed (classifier, park-arm record, resume skip), each
  reverted from a byte backup and re-verified green.
- Chunked fast-tier sweep (`tools/run_tests_chunked.sh`, the repo's
  sanctioned cloud-agent runner): **OK: all chunks passed** — 104 chunks,
  including `tdd/commands` (+601) and `tdd/models` (+90).
- `dart analyze` on every changed file: No issues found. `dart format .`:
  0 changed.
- Pre-existing, unrelated: 4 `make_command_test.dart` (regression/e2e tier)
  pins fail on this container — verified red on pristine master (stash run
  + master worktree), untouched by this fix.

## Acceptance criteria

1. `outcome=hand-step` (not `generation-error`), run continues — PROVED
   (A-1568-s1, d2).
2. Run summary `hand_steps=N` + hand-step ids listed — PROVED (d1, d2/d4).
3. Mechanical behaviors behind hand-steps reachable and drivable — PROVED
   (d2: U2 drives to done behind parked U1).
4. Resume does not re-drive hand-steps (honest red stands) — PROVED (d3 +
   B-1568-r1 persistence).
