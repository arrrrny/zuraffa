# Cycle Log: tdd-gen-project-flag-ignored (GitHub issue #1272)

Bug TDD cycle (red → green → refactor → verify), single session,
2026-09-07 (UTC+8), branch `fix/1272-tdd-gen-project-flag-ignored`.

## Step 1 — Read assessment + issue

GitHub issue #1272 fetched (open, high). Root cause + remediation from
assessment.md; both mirrored into `.specify/bugs/tdd-gen-project-flag-ignored/`
(issue.md, assessment.md).

## Step 2 — Reproduce (RED)

- Fixture: monorepo with `pubspec.yaml`, decoys `example/specs/004-login-ui`
  (7-column) + `corpus/regression/x/specs/u2-flow` (7-column), project
  `apps/login_demo/specs/001-login-ui` (4-column, A1), root-level
  `specs/001-login-ui` (4-column, A1).
- Probe on master: `zfa tdd gen A1 --project apps/login_demo --feature
  ../../../example/specs/004-login-ui --dry-run` → gen read the FOREIGN
  list: `Bad state: zfa tdd gen: malformed test list — test-list.md line 7:
  expected 4 columns (id/behavior/traces/state), found 7` (issue's exact
  error signature). Batch `--all` variant: `verdict=stopped` masking the
  foreign parse error, exit 1.
- New suite `bug_1272_gen_project_scoped_test_list_test.dart` on master:
  `+4 -2: Some tests failed` — 2 failures pin the bug for the right
  reason (foreign list read + parsed before any validation); 4
  regression guards green on master as they must be.

## Step 3 — Fix (GREEN)

- Minimal change, scoped to gen's test-list resolution path:
  `GenCommand.testListScopeRejection(projectRoot, featureRef)` —
  containment first (resolution must stay inside `<project>/specs`),
  segment shape second (ONE spec directory name, the verify/make/
  refactor/compose/verify-red contract) — consulted in `GenCommand.run`
  BEFORE any test-list read, as a usage-level rejection.
- Suite post-fix: `+12: All tests passed!` (5 unit + 7 CLI).
- Gen-related suites: bug_890 + smoke + batch_gen + json_flag 43/43;
  step_runner 18/18; sc_019 + bug_969_receipts + bug_830 + bug_840
  31 pass / 5 fail — the 5 reproduced on pristine master (pre-existing,
  unrelated bug_840 verdict-JSON drift).

## Step 4 — Refactor

- Formatter + analyzer only (`dart format`, `dart analyze` — both clean
  on the changed scope). No hand edits beyond the fix; no behavior
  change. Pre-existing unformatted `specs/1142-.../evidence/` files left
  untouched (out of scope).

## Step 5 — Verify

- Mutation check on the changed resolution logic: MUTANT-A (containment
  disabled) KILLED by 6 tests; MUTANT-B (shape disabled) KILLED by 3
  tests. 2/2 killed, 0 survived.
- Full evidence + verdict: ./verification.md — **PASS**.
