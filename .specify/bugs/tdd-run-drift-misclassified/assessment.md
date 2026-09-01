# Bug Assessment: run driver misclassifies #657 success as generation-error — U1 stays pending when test goes green

- **Slug**: tdd-run-drift-misclassified
- **Created**: 2026-09-01T17:14:40Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/693
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

After fix #657 (generator surface for plain functions), `zfa tdd make <id>` returns `drift` when the test is already passing after a stub rewrite. But `zfa tdd run` reports the same scenario as `generation-error` and leaves the behavior in `pending`.

The reporter identifies the root cause: `run_command.dart` has an outcome mapping table (from bug #625 refactor) that needs an entry for the new `drift` outcome (introduced by #657) classified as `green` (success). Currently `drift` is unmapped and falls through to `generation-error`.

See: https://github.com/arrrrny/zuraffa/issues/693

## Symptom

`zfa tdd run <spec>` hard-stops at the `make` step for a behavior whose test is already green. The run driver reports `step failed — behavior=U1 step=make outcome=generation-error` instead of recognizing the success path. U1 stays in `pending` state and the run never proceeds to U2.

## Reproduction

1. Forklift spec 004, U1 (`render returns a non-empty string for a fully populated task`)
2. Run `zfa tdd run 004-cloud-agent-task-dispatch` from a clean state
3. A1-A5 deferred as `unexpressible` (expected)
4. U1:gen → ok, U1:verify-red → certified (expected)
5. U1:make → the #657 fix fires: stub rewritten to `String subject_u1() { return 'subject_u1'; }`
6. Test `dart test test/tdd/u1_test.dart` → passes
7. `zfa tdd make U1` direct call → `outcome=drift` (success)
8. Run driver reports `outcome=generation-error` and hard-stops.

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

Likely file: `lib/src/cli/commands/tdd/run_command.dart` — the outcome mapping table from the bug #625 refactor.

Related: PR #660 (which introduced `drift` as a new make outcome).

## Root Cause Hypothesis

The `run_command.dart` outcome mapping (added in the #625 refactor) has no entry for the new `drift` outcome introduced by PR #660. Unmapped outcomes fall through to a default that classifies as `generation-error`, so a successful drift (test already passes) is misclassified as a generation failure. The fix is to add a mapping entry: `drift → green` (success, with a log note).

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

Expected change: in `run_command.dart`, add `drift` to the outcome mapping table with classification `green`. The transition logic should move the behavior from `pending` → `green` → `done` and proceed to the next behavior, logging a one-line note ("U1 was already green from a prior make") instead of aborting the run.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Adding `drift` to the outcome map may also need a corresponding test (likely in `test/cli/commands/tdd/run_command_test.dart` or similar).
- Cross-check that no other outcome is currently silently falling through to `generation-error` (could find more unmapped values).

## Open Questions

- [NEEDS CLARIFICATION: confirm the exact location of the outcome mapping table in `run_command.dart` and check for other unmapped outcomes from the #625 refactor.]
- [NEEDS CLARIFICATION: should `drift` be classified as `green` always, or only when the test is verified green after make? The reporter says "drift AND test is green" — confirm whether the make output already carries the test-verified signal, or whether the run driver needs to run a verification step.]
- [NEEDS CLARIFICATION: is the canonical next state `green` → `done`, or a different name? Confirm with state machine semantics.]
