# TDD Test List: 1483-vacuous-green-remedy-wrong-file

Bug #1483 — the vacuous-green remedy must name the seam that exists for the
feature shape it is talking to. Red-green-refactor over the REAL
`RunDriverCore` (the fix is messaging-only; the loop and detection are
frozen by the issue's hard constraints).

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | A legacy single-file feature's vacuous-green stop names the TEST LIST's traces cell with the full path (`specs/<feature>/tdd/test-list.md`) and NEVER the nonexistent `04-ENGINE.md`; `stopped_at=<id>:make` preserved | FR-1483-1 | DONE |
| U2 | A lane-split feature's vacuous-green stop still names the LANE PLAN's traces cell (`specs/<feature>/tdd/04-ENGINE.md`), with the full path; `stopped_at=<id>:make` preserved | FR-1483-2 | DONE |
| U3 | The remedy vocabulary branches by shape and keeps the #1308/#1320 wording family verbatim (re-plan advice, `FR-00N, Row.method` cell, hand-delta seam tail); the pre-#1483 shared constant stays byte-identical | FR-1483-3 | DONE |

## Notes

- U1/U2 are the slow-tier driver suites
  (`test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart`,
  real `CliRunner` + real `RunDriverCore` over the scripted fake zfa, the
  issue #1308 driver-suite convention).
- U3 is the fast-tier vocabulary suite
  (`test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart`).
- RED evidence: U1 and U2 failed on the unfixed tree for the right reason
  (the printed remedy named `04-ENGINE.md` bare); U3 failed at compile
  (the branch function did not exist). See `verification.md`.
