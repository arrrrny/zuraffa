# Bug Assessment: `zfa tdd run` blocks on acceptance behaviors — no outside-in deferral

- **Slug**: tdd-run-acceptance-deferral
- **Created**: 2026-08-31
- **Source**: pasted text (live reproduction, `/tmp/zfa-make-demo/run-c`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Post-#617 end-to-end run of `zfa tdd run` on a `zfa tdd plan`-written list
(the canonical spec → plan → run flow):

```
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> unexpressible
zfa tdd run: step failed — behavior=A1 step=make outcome=unexpressible
run: feature=001-demo result=stopped pending=1 red=1 green=0 done=0 stopped_at=A1:make
```

Driving the unit behavior of the same feature manually completes perfectly:

```
U1 gen -> created   U1 verify-red -> certified
U1 make -> plan: 3 step(s) (entity create -n User + tdd wire + build)
make: behavior=U1 outcome=green  (exit 0, green evidence)
```

## Symptom

`zfa tdd plan` always writes acceptance behaviors (A*) before unit behaviors
(U*) — correct outside-in order — but `zfa tdd run` executes them in list
order with the full `gen → verify-red → make → refactor` cycle for each.
Acceptance prose (e.g. "the entity exists and is buildable.") is unexpressible
to the generation planner by design, so the driver stops the entire feature
at `A1:make` before ever reaching the unit behaviors that would make A1
green. Every feature produced by the canonical `plan → run` flow deadlocks
at its first acceptance behavior.

## Reproduction

1. Fresh project + `specs/001-demo/spec.md` with one Given/When/Then scenario
   and one FR naming an entity.
2. `zfa tdd plan 001-demo --project .` (A1 written before U1).
3. `zfa tdd run 001-demo --project .` → stops at `A1:make outcome=unexpressible`.
4. Contrast: `zfa tdd gen U1` → `verify-red U1` → `make U1` → green.

Preserved at `/tmp/zfa-make-demo/run-c`. Will hit corpus feature
001-app-bootstrap (`~/Developer/zik_zak_zfa`, 120-feature corpus) on the
first invocation.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart:210` — `for (final row in
  rows)` drives behaviors strictly in test-list order with the same step
  sequence per behavior; no acceptance/unit distinction.
- `lib/src/plugins/tdd/commands/plan_command.dart:115-125` — acceptance rows
  are emitted before unit rows (correct outside-in ordering for a reader).
- `lib/src/plugins/tdd/services/generation_planner.dart` — correctly returns
  `unexpressible` for acceptance prose; not a planner bug.

## Root Cause Hypothesis

The driver implements one uniform per-behavior cycle, but outside-in TDD
requires two phases per feature: acceptance behaviors are generated and
certified red, then **held** while unit behaviors run their full cycle, and
only then does the acceptance behavior's `make`/`refactor` attempt to flip
the end-to-end test green. The missing concept is deferral, not ordering of
the list. High confidence — demonstrated live both ways (stop at A1; manual
U1 completion).

## Proposed Remediation

**Preferred**: two-phase driving in `run_command.dart`: phase 1 processes
every behavior through `gen` + `verify-red` and drives unit behaviors through
`make` + `refactor` to DONE; phase 2 returns to the acceptance behaviors and
runs their `make` + `refactor` (now typically green because the units exist;
`unexpressible` at phase 2 is a real stop). Run-state semantics unchanged
(acceptance behaviors sit in RED between phases — resumable mid-corpus).
Progress lines gain a phase marker, e.g. `[run] A1 make -> deferred (phase 2)`.

**Alternatives**:
- Planner maps acceptance prose to plans — rejected: acceptance behaviors
  are end-to-end scenarios, not generation units; forcing a mapping fakes it.
- `plan` writes units first — rejected: breaks the outside-in reading order
  and speckit's template contract.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart`
- `test/plugins/tdd/run_command_test.dart` + scenario `sc_013`/`sc_014`

**Tests to add or update**:
- Feature with 1 acceptance + 1 unit behavior: acceptance deferred, unit
  completes, acceptance flips green, feature DONE, exit 0.
- Acceptance unexpressible at phase 2 → honest stop with `stopped_at=A1:make`.
- Resume across the phase boundary (acceptance in RED after interruption).

## Risks & Considerations

- `run-state.json` semantics for acceptance behaviors in RED between phases
  must stay resumable and evidence-checked (FR-003 unchanged).
- Features with only acceptance behaviors degenerate to phase 2 only — fine.

## Open Questions

- None blocking.
