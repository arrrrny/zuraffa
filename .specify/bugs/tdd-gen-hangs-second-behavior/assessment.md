# Bug Assessment: zfa tdd gen hangs on second behavior (regression from #738)

- **Slug**: tdd-gen-hangs-second-behavior
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/744
- **Verdict**: valid
- **Severity**: high

## Report

After fix #738 (regression check compares only current behavior test), `zfa tdd gen A2` hangs indefinitely on a fresh project. A1 gen works, A2 gen hangs.

## Symptom

`zfa tdd gen A2` hangs indefinitely (killed with SIGKILL after 20s). Confirmed regression from fix #738.

## Reproduction

1. `zfa setup --platforms=macos`
2. `zfa tdd init`, copy spec, `zfa tdd plan`
3. `zfa tdd gen A1` → works
4. `zfa tdd gen A2` → hangs indefinitely

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/gen_command.dart` — the gen step introduced in fix #738 that runs a per-behavior regression check before/after scaffolding.
- The regression check likely spawns a `dart test` subprocess that hangs on the second behavior (possibly due to a missing timeout — see #742, or a deadlock in the suite guard when processing a behavior whose predecessors are deferred).

## Root Cause Hypothesis

Fix #738 added a per-behavior regression check in the gen flow. On the second behavior (A2), this check spawns a `dart test` subprocess that hangs indefinitely — either because there's no timeout (same systemic gap as #742) or because the suite guard deadlocks when A1 is deferred (unexpressible) and A2's check runs against a stale baseline. Confidence: **medium** — the regression is confirmed, but the exact hang trigger (deadlock vs missing timeout vs infinite loop) requires code inspection.

## Proposed Remediation

1. Apply the #742 timeout fix to the gen step's regression check (kill + timeout).
2. Inspect the #738 gen logic for a possible deadlock when processing a behavior whose predecessor is deferred/unexpressible.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/gen_command.dart`

**Tests to add or update**:
- `zfa tdd gen A2` on a fresh project completes within 30s (not hangs).
- A1 (unexpressible/deferred) + A2 (gen) does not deadlock.

## Risks & Considerations

- This is a regression — the fix must not reintroduce the #731/#737 false-positive that #738 originally solved.
- The timeout (from #742) should be applied here as a safety net regardless of the root cause.

## Open Questions

- [NEEDS CLARIFICATION: Is the hang a deadlock in the suite guard or a missing timeout (same as #742)?]
- [NEEDS CLARIFICATION: Does A2 hang because A1 is deferred, or would any second behavior hang?]