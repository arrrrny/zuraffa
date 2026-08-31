# Bug Assessment: `zfa tdd run` defers acceptance `make` but not `refactor` — features deadlock at U1:refactor

- **Slug**: tdd-run-refactor-vs-deferred-acceptance
- **Created**: 2026-08-31
- **Source**: pasted text (live reproduction, `/tmp/zfa-make-demo/run-e`, post-#625 master)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Fresh project, `zfa tdd plan` then `zfa tdd run` (post-#625/fix #634 master):

```
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> unexpressible
[run] A1 make -> deferred (phase 2)
[run] U1 gen -> ok
[run] U1 verify-red -> certified
[run] U1 make -> green
[run] U1 refactor -> not-green
run: feature=001-demo result=stopped pending=0 red=1 green=1 done=0 stopped_at=U1:refactor
```

## Symptom

#625's two-phase driving defers the acceptance behavior's `make` to phase 2
— correct — but the unit behavior's `refactor` step still runs in phase 1.
`refactor` (spec 048 FR-001) demands an absolutely green suite, which phase 1
can never provide while the acceptance test is honestly red (it is *supposed*
to be). So every feature with ≥1 acceptance behavior stops at the first
unit's `refactor` with `not-green`. The deferral concept is half-applied:
`make` is deferred, `refactor` is not.

## Reproduction

1. Fresh app + `specs/001-demo/spec.md` with one Given/When/Then scenario +
   one FR naming an entity (the canonical corpus shape).
2. `zfa tdd plan 001-demo --project .` → `zfa tdd run 001-demo --project .`.
3. Observe `stopped_at=U1:refactor` with `outcome=not-green` after U1 make
   certified green.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart` — the two-phase logic
  (fix #634) defers acceptance `make`; the step picker still schedules
  `refactor` for unit behaviors during phase 1.
- `lib/src/plugins/tdd/commands/refactor_command.dart` — correct behavior
  (absolute green preflight, spec 048 FR-001); not the bug site.

## Root Cause Hypothesis

The phase model defers the *acceptance behavior's* steps, but the suite-level
consequence — the full suite is red until phase 2 — was not propagated to the
*unit path's* refactor, whose contract requires fully green. High confidence
(live, deterministic reproduction on a fresh project).

## Proposed Remediation

**Preferred**: defer `refactor` like `make`: phase 1 drives units through
`gen → verify-red → make` only (progress line `[run] U1 refactor -> deferred (phase 2)`); phase 2, after acceptance behaviors flip green, runs `refactor` for every behavior (or once per feature) on the now-fully-green suite, then marks DONE. This keeps refactor's absolute-green contract untouched.

**Alternatives**:
- Run refactor at feature end only (one invocation per feature) — same fix
  from the feature side; slightly less granular evidence.
- Relax refactor's preflight — rejected: violates 048's hard rule.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart`
- `test/plugins/tdd/run_command_test.dart` + scenario tests

**Tests to add or update**:
- Acceptance-bearing feature drives to all-DONE (defer make + refactor,
  phase-2 flips acceptance green, final refactor runs, exit 0).
- Regression: unit-only feature still runs refactor per behavior as before.

## Risks & Considerations

- Phase-2 acceptance `make` semantics (how an acceptance subject flips green
  against units) must be defined while fixing — verify with the run-e
  fixture once refactor is deferred; if acceptance make remains
  unexpressible at phase 2, that's the next gap to file (#625's story is
  only complete when acceptance behaviors can actually turn green).

## Open Questions

- None blocking this fix; the phase-2 acceptance-make question is tracked
  as a follow-up within the same verification.
