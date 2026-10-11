# TDD Verification — bug 1625 (blocked-contract hand surface)

- **Slug**: 1625-blocked-contract-hand-surface
- **Date**: 2026-09-15
- **Runner**: `dart test` (Dart SDK 3.13.4), in-process `CliRunner` fixtures
  (fast tier — fake zfa scripts every step, no `dart test` spawn inside the
  fixtures)
- **Verdict**: **PASS** (all acceptance criteria PROVED; unrelated
  pre-existing failures on `master` documented in §4)

## 1. Test-first evidence

- RED (commit `ed160e8`, "WIP(1625): tdd-red"): the new suite
  `test/plugins/tdd/commands/bug_1625_blocked_hand_surface_subject_test.dart`
  ran against the unfixed code — **4 passed / 7 FAILED**, every failure the
  bug itself:
  - the run stop output captured inside the failure reason literally
    reproduces the issue's repro:
    `hand surface: seam test/tdd/004-calculator/contract_a1_test.dart —
    implement the declared contract Calculator.add there (e.g. `zfa tdd wire
    contract:A1 --entity Calculator`)`;
  - `seamPathFor` preferred the existing test over an existing subject;
  - `hintLine` printed the with-entity wire example with no entity on disk;
  - `make` named the test file at the implement-seam-first stop.
- GREEN (this branch): the same 11 tests all pass after the
  `hand_surface.dart` + call-site fix. The guards that passed pre-fix
  (test-fallback resolution, with-entity example, undotted bare example)
  still pass — the fix narrowed only the buggy shapes.

## 2. Real verification runs (this branch, this session)

- Targeted suite (final confirmation run):
  `dart test bug_1625… bug_1589… verify_red_command_test verify_red_subdirectory_test
  contract_blocked_e2e_1007_test bug_1544_run_continue_after_blocked_test
  wire_command_test contract_kind_1007_test contract_satisfied_with_rejection_e2e_1541_test`
  → **58/58 passed, 0 failed**.
- Full `test/plugins/tdd/commands/` directory sweep (`--concurrency=4`):
  **629 passed / up-to-5 failed** across runs; every failure either (a)
  reproduced on `master` with the fix stashed (pre-existing, §4) or (b)
  passed in isolation on this branch (flakiness under parallel real-process
  spawns, not this change).
- `dart analyze` over the six touched files → **No issues found!**
- `dart format` applied to the touched files; the committed diff is the
  formatted form.

## 3. Acceptance-criteria coverage (issue #1625)

| # | Criterion | Proved by |
|---|-----------|-----------|
| 1 | Blocked-contract stop names the subject seam, not the test file | PROVED — B1/B3 unit pins + B7 (`run` park note names `seam lib/tdd/<feature>/contract_a1_subject.dart` and NOT `seam test/tdd/…_test.dart`) + B10 (terminal `result=blocked` block) + B11 (`make` stop); the verify-red arm resolves through the same `seamPathFor` |
| 2 | `wire` hint printed only when an entity of that name exists | PROVED — B4 (entity on disk → example prints) + B5 (entity missing → no `e.g. \`zfa tdd wire …\`` in output) + B9 (end-to-end `run` with seeded entity) |
| 3 | No-entity refusal includes the hand-implement path | PROVED — B5/B8/B11: the hint names `lib/tdd/<feature>/<id>_subject.dart` and says "implement … there by hand (no generated entity … exists; the wire step needs `zfa entity create -n <E>` first)" |
| 4 | Fresh spec's first blocked behavior points to the subject file | PROVED — B7 seeds exactly the fresh-run shape (generated test + subject stub on disk, no entity) and the stop names the subject |

## 4. Pre-existing failures on master (NOT caused by this fix)

Both were re-run on a clean `master` worktree (fix stashed) and reproduce
identically there; both are environment-sensitive suites that spawn real
processes:

- `test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart` —
  `PathNotFoundException: /tmp/tdd_fixture_…/test/a1_test.dart` (fails on
  master AND on this branch, in isolation).
- `test/plugins/tdd/make_command_test.dart` — 10 failures (bug-737 build-guard
  pins; fail identically on master: `+30 -10` there vs `+30-equivalent -10`
  of this branch's batch where the other three suites in the same run all
  passed).

Additionally, four suites (`plan_fr_manual_1484`, `bug_1551`, `bug_1568`,
`bug_1388`) flaked under `--concurrency=4` full-directory load; all four
pass in isolation on this branch (and on master for the latter three).

## 5. Mutation sanity (manual mutant)

Deliberate mutant: reverting the `seamPathFor` candidate order (test-first)
while keeping the new tests → B1, B7, B10, B11 fail immediately (the suite
re-detects the bug). Reverting the `entityExists` gate (always print the
wire example) → B5, B8 fail. The suite is mutant-sensitive on both fix
axes. (No automated mutation tool in this repo; deliberate-mutant 2/2
caught.)

## 6. Test smells

None material: fixtures are throwaway temp projects (no shared state), no
order dependence, no real-network/real-spawn dependence in the new suite,
exit-code flake guard (`takeExitCode`) used per the house convention.
Assertions pin exact project-relative paths and the presence/absence of the
wire example — strong, not tautological.
