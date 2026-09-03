# Bug Assessment: acceptance behaviors (A*) are unexpressible even with entity-bearing plan — no generator surface for acceptance composition (issue #923)

- **Slug**: acceptance-unexpressible-with-entity-plan
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/923
- **Verdict**: valid
- **Severity**: high

## Report (summarized)

An acceptance behavior (`A<n>`) whose prose is pure end-to-end Given/When/Then
(no entity/CRUD keywords, no function-intent verb) is refused by the pure
description-keyed `GenerationPlanner`, and the make command's composition
fallback (#642, spec 052) engages only when the feature holds unit subjects
with **green cycle-log evidence**. A unit subject that is ENTITY-WIRED — the
`zfa tdd wire` step implemented it against its spec Key Entity (the
`wiredEntityAnchor` implementation-anchor marker, bug #610) — but not yet
certified green is NOT a valid anchor, so the fallback disengages with
`no-green-units` and the acceptance make reports `outcome=unexpressible`,
defers to phase 2a, reports `unexpressible` there, and the behavior sits
`red` in the run state forever.

## Symptom

Spec 004 (cloud-agent-task-dispatch, 8 U + 5 A): every U subject wired to the
Task entity, A1-A5 all `unexpressible` at make (phase 1 and phase 2a), all 5
stuck red in `tdd/run-state.json` while the run's other behaviors complete.

## Reproduction (this session, real CLI)

Fixture project mirroring the spec-004 shape (Key Entity Task; FR prose
mentioning `task`; acceptance prose pure flow statements). The decisive
RED evidence — units entity-wired, NO green cycle-log evidence, A1
certified red:

```
$ zfa tdd make A1 --feature 004-cloud-agent-task-dispatch
   suite baseline: dart test
   baseline exit: 1, failed: 5
   composition fallback disengaged: no green unit subjects to compose
   against: behavior "A1" needs at least one unit-kind behavior with green
   cycle-log evidence and an existing subject artifact (the units must go
   green before an acceptance subject can compose against them — the 049
   phase-1 deferral).
make: behavior=A1 outcome=unexpressible feature=004-cloud-agent-task-dispatch
```

And the phase-1 deferral on the full run (all 5 A behaviors, exactly the
issue's transcript):

```
[run] A1 make -> unexpressible
[run] A1 make -> deferred (phase 2)
... A2..A5 identical
```

## Suspected Code Paths

- `lib/src/plugins/tdd/services/composition_targets.dart` (`discover`) —
  **confirmed**. The anchor loop gated on `green.contains(row.id)` alone:
  green evidence AND an existing subject artifact, nothing else. An
  entity-wired stub subject without green evidence was skipped, and zero
  anchors failed the whole discovery with `no-green-units`.
- `lib/src/plugins/tdd/commands/make_command.dart` (`_compositionFallback`)
  — behaves as designed: a failed discovery prints the disengagement and
  keeps the honest `unexpressible` stop. The discovery contract was the gap.
- `lib/src/plugins/tdd/services/generation_planner.dart` — by-design pure
  and description-keyed; acceptance flow prose without CRUD/function
  keywords is unexpressible there (spec 052 keeps that purity; the
  composition fallback is the acceptance surface, so the fix does NOT
  touch the planner).

## Root Cause Hypothesis

The composition anchor contract equated "composable" with "green". The
issue's remediation option (1)/(2) is the correct minimal surface: a unit
subject the wire step implemented against its entity (`wiredEntityAnchor`
in executable code) is an honest implementation anchor for an acceptance
scenario even while its behavior is still a stub (`return 0`) — the
acceptance composition may rest on the wiring, deferring the real green
transition to when the unit subjects are filled with business logic.

Confidence: **high** — deterministic real-CLI reproduction (RED evidence
above), and the post-fix e2e run of the same shape flips the acceptance
make to `outcome=green` via `compose` → `build` (see
`tdd/verification.md`).

## Remediation (implemented)

Extend `CompositionTargets.discover()` per remediation option (1)+(2):
besides green-evidence anchors, a unit row whose registry subject artifact
exists and carries the `wiredEntityAnchor` implementation anchor in
executable code (line comments stripped first, same discipline as wire's
`_hasExecutableUnimplementedError`) is a composable anchor marked
`entityWired: true`. Zero anchors (neither green nor entity-wired) still
fails honestly with `no-green-units`. The compose command and the
composition planner name the green/entity-wired mix in their audit trails
so the evidence chain stays honest. The planner, the certified-red
precondition, and the fail-closed `missing-anchor-subject` contract for
green rows are unchanged.

## Hard constraints honored

- STOP-ON-ROADBLOCK: the honest `unexpressible` stop remains for
  acceptance prose with zero composable anchors (no green, no wired units)
  and for every non-acceptance target — nothing is composed away silently.
- Acceptance behaviors must not be stuck at `unexpressible` when unit
  subjects are entity-wired: pinned by `A13b` (make level, fake pipeline),
  `A6b` (compose level), `U6/U8` (discovery level), and the real-CLI e2e
  repro in `tdd/verification.md`.
- One PR for this bug only.
