---
feature: 1603-missing-subject-misreported-symlink
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: fix/1603-missing-subject-misreported-symlink
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: 2/2 killed # no mutation tool in this environment (tdd-profile: "Mutation tool: none"); deliberate-mutant sampling per the rubric — each fix site reverted to its pre-fix shape and the pinning test re-run
mutants_survived: 0
suite: 4 affected suites 54/54 (view+func+compose+wire); fast-tier TDD scope chunked (-j 2, sandbox OOM-safe) 2431 passed / 10 failed — all 10 in the e2e-tagged make_command_test.dart and byte-identical to the failure set of a clean master worktree (71ff365f), i.e. pre-existing, not introduced; scenarios/ fully slow-tagged (excluded by dart_test.yaml, CI-consistent); U-V3/U-W3/U-F5 originals green; dart analyze on changed files exit 0 (No issues found); dart format full pass 0 changed. All figures re-captured on this branch (Linux, Dart 3.13.3).
---

# TDD Verification: canonicalize containing dir for missing subjects on symlinked roots (#1603)

**Verdict: PASS.** A missing subject file is now reported as a **missing
subject file** — never as "points outside the project root" — on roots that
reach the filesystem through a symlink (macOS `/var/folders` →
`/private/var/folders`), across `view` (fixed), `func` (hardened), `compose`
(pin: already immune), and `wire` (pin: carries the pull/1516-review fix).

## What the run proved (fresh, this branch)

1. **RED was honest** (`tdd/cycle-log.md`): U-1603a and U-1603c failed
   pre-fix with the issue's exact signature —
   `Expected: contains 'missing subject file'` / `Which: does not contain
   'missing subject file'` — reproduced deterministically on Linux by
   aliasing the fixture root through a symlink and passing the alias as
   `--project`. The regression pins U-1603b/U-1603d/U-1603e were green
   pre-fix (recorded in the cycle log), which is what a pin is supposed to
   do.
2. **GREEN is real**: post-fix, all five U-1603 behaviors pass, and the
   four affected suites pass end-to-end (582 commands + the four-suite
   54/54 subset). The original U-V3 / U-W3 / U-F5 pins pass unchanged.
3. **No collateral damage**: the fast-tier TDD scope passes 2431 tests
   across chunked runs (`commands/` 582, `services/` 1068, root 650,
   `corpus_economics/` + `setup_command` 67, `cli/writers/tdd/` 64). The
   only failures anywhere are 10 tests in the e2e-tagged
   `make_command_test.dart`; a clean master worktree fails the **same ten
   tests with the same messages** (diff of failure sets: empty), and the
   repo's own `tools/run-tdd-tests.sh` header documents the e2e lane's
   pre-existing master failures. Nothing in this fix's scope changed make
   semantics; `make_command.dart` is untouched.
4. **Test strength (deliberate mutants, 2/2 killed)**:
   - Mutant V1: `view_command.dart` reverted to the pre-fix raw fallback
     (`canonicalSubject = subjectPath`) → U-1603a RED. Killed; fix
     restored.
   - Mutant F1: `func_command.dart` guard reverted to the pre-fix raw
     raw-vs-raw comparison → U-1603c RED. Killed; fix restored and
     U-1603c re-verified green after restoration.
5. **Rubric grade** (cold re-read of the tests as written):
   - *Came first?* PROVEN × 5 — cycle log records the red command and its
     failure output; tests and source landed in the same commit
     (`fed9c756`), which the rubric's PROVEN class accepts; the mutant
     sampling re-demonstrates the red on demand.
   - *Assert behavior?* Yes — the tests drive the public CLI surface
     (`CliRunner.runCapturing`) and assert the user-visible message and
     exit code, including the negative assertion that the wrong refusal
     branch never appears.
   - *Catch a bug?* Yes — 2/2 deliberate mutants killed (see 4).
   - *Every requirement covered?* 5/5 acceptance criteria of `spec.md`
     reach a test exercising the real entry point: AC1→U-1603a,
     AC2→U-1603c, AC3→U-1603d, AC4→U-1603e, AC5→U-1603b.
   - *Worth keeping?* Deterministic (timestamped unique alias names),
     POSIX-only with a Windows skip matching the suite's existing U12
     symlink convention, no new shared fixtures, insensitive to the
     refactoring the fix itself performs.

## Environment notes (honest constraints)

- The sandbox provides 4 GB RAM / 2 cores: a single unbounded
  `dart test test/plugins/tdd/` run OOM-killed 237 test LOADS while the
  same files pass individually and in chunked `-j 2` runs. The 2431/10
  figures above are the sum of six chunked runs, not one invocation; the
  10 failures were additionally reproduced on a pristine master worktree
  for the pre-existing classification.
- The serialized `tools/run-tdd-tests.sh` lane could not complete in this
  sandbox (background processes are reaped between tool invocations); the
  chunked runs cover the same scope minus the e2e/slow-tagged lanes CI
  also excludes.

## Post-rebase re-verification

Rebased onto origin/master after PR #1606 (same-issue view fix) merged
mid-flight. Re-ran the full affected scope on the rebased branch: the four
suites (view/func/compose/wire) pass 57/57 — the union of this branch's
U-1603a..e and #1606's U-V11/12/13 — with `dart analyze` clean on the delta
and `dart format` 0 changed. The deliberate-mutant evidence for `func` (the
branch's remaining code fix) stands: the func file is byte-identical to the
pre-rebase state where mutant F1 was killed by U-1603c.
