# Bug Assessment: [BUG] zfa tdd run: unexpected-green on already-completed behavior breaks the run loop

- **Slug**: zfa-tdd-run-unexpected-green
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/691
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

`zfa tdd run` fails with `unexpected-green` when a behavior's test is already green from prior work (e.g., manual make via `zfa tdd make`). The run loop should detect already-green tests and skip them, or at least not treat it as a failure. The entire run loop stops with exit code 1 when `verify-red` encounters a behavior (A7) whose test is already green. See https://github.com/arrrrny/zuraffa/issues/691.

## Symptom

When `zfa tdd run` processes a feature where one or more behaviors have had their tests completed manually (e.g., via `zfa tdd make`), the `verify-red` step reports `unexpected-green` and the run loop exits with code 1 instead of detecting the already-green state and skipping that behavior.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. Manually run `zfa tdd gen A7`, `zfa tdd verify-red A7`, `zfa tdd make A7` (test now green)
5. `zfa tdd run 001-app-bootstrap --zfa-bin ~/.local/bin/zfa`
   → **exit 1**: `behavior=A7 step=verify-red outcome=unexpected-green`

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- The workaround (delete the green test/subject) is manual and disruptive.

## Open Questions

- [NEEDS CLARIFICATION: What is the expected behavior — should `verify-red` detect green and return "already done" / "skip", or should the run loop skip `verify-red` for behaviors whose test already passes?]
- [NEEDS CLARIFICATION: Does `zfa tdd run` have a `--skip-green` / `--force` flag that should be used here?]
- [NEEDS CLARIFICATION: Is `zfa tdd verify-green` idempotent for already-green tests, and should `run` use it instead of `verify-red`?]
