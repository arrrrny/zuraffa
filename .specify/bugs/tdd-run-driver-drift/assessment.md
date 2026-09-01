# Bug Assessment: fix(tdd): run driver misclassifies #657 success as generation-error — U1 stays pending when test goes green

- **Slug**: tdd-run-driver-drift
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/693
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

After fix #657 (generator surface for plain functions), `zfa tdd make <id>` for behaviors with a stubbed func body returns `drift` (test already passes). But `zfa tdd run` reports the same scenario as `generation-error` and marks the behavior as `pending` instead of `green`/`done`.

## Symptom

When `zfa tdd make U1` is called as part of `zfa tdd run`, it returns `outcome=drift` (test already green), but the run driver maps `drift` to `generation-error`, hard-stops the run, and leaves U1 in `pending` state instead of transitioning it to `done` and proceeding to U2.

## Reproduction

1. Forklift spec 004, U1 (`render returns a non-empty string for a fully populated task`)
2. Run `zfa tdd run 004-cloud-agent-task-dispatch` from a clean state
3. U1:make → stub rewritten to `String subject_u1() { return 'subject_u1'; }`
4. `zfa tdd make U1` → `outcome=drift`
5. `dart test test/tdd/u1_test.dart` → passes
6. Run driver reports `step failed — behavior=U1 step=make outcome=generation-error`, U1 stays `pending`

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

`run_command.dart` has an outcome mapping table (from bug #625 refactor). The new `drift` outcome introduced by #657 is not mapped, so it falls through to `generation-error`, which triggers a hard stop instead of treating the step as `green`.

## Proposed Remediation

Add an entry for `drift` in the outcome mapping table in `run_command.dart` that classifies it as `green` (success), allowing the run to proceed to U2 after a `drift` outcome.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: Confirm the exact file and line in run_command.dart where the outcome mapping table lives.]
- [NEEDS CLARIFICATION: Verify that `drift` truly means "test is green" across all callers, or if it can mean something else in some contexts.]
- [NEEDS CLARIFICATION: Does `drift` need any special logging note ("U1 was already green from a prior make") per the issue's verification section?]
