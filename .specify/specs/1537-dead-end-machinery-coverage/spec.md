# 1537-dead-end-machinery-coverage

- **Spec ID**: 1537-dead-end-machinery-coverage
- **Created**: 2026-09-13
- **Source**: GitHub issue #1537 (SPEC 1537 — dead-end fallback machinery uncovered after feature 1484 — prove unreachable and delete or pin with live fixture)
- **Type**: coverage/verification (P2 — the machinery's liveness is undocumented; one option of the spec is provably wrong)
- **Branch**: feat/1537-dead-end-machinery-coverage
- **Related**: #1484 (FR manual exemption), #1527 (test-only PR updating #1481 expectations), #1481 (dead-end detection), #1480 (unit-fallback gate), #1319 (unbound traces)

## Problem

Feature #1484 routed FRs with no surviving `traces:` binding to manual
declarations instead of unit-lane fallback routes. PR #1527 updated the last
`#1481` expectations accordingly, leaving `plan_command.dart`'s dead-end
machinery with **no test proving it live and no test proving it dead**:

- `plan_command.dart` `_provenanceLines` — `if (!repairable) deadEnds.add(b.id);`
- the `[fallback: no declared trace — make will dead-end]` route prefix
- `_printDeadEndTally` — the one-line fatal tally
- the `dead_end_behaviors` verdict key (both render paths)

Issue #1537's initial analysis claimed the `!repairable` branch was
unreachable after #1484 ("FR-derived unit behaviour always carries `traces:`;
bound trace resolves declared; dangling refuses; unbound drops the FR") and
proposed **Option A — delete the machinery**. This feature's investigation
**disproved unreachability with live CLI probes**: an FR whose inline
`traces:` line binds ONLY criterion-shaped tokens (`FR-001`, `AC-2`, `SC-1`
— the resolver's `_criterionToken` skip) survives the `traceTokens` filter
(no `(`-shaped tokens to drop), binds non-empty (so #1484 keeps the unit row
instead of routing manual), and the resolver passes the tokens without
dangling — leaving `kind == null` → `RoutingUndeclared` → `decision == unit`
→ `!repairable` → dead-end machinery. The #1480 unit-fallback gate hides
this route on the default path, but two live routes reach it:

1. a `[persistent]`-tagged FR (persistence-marked fallbacks are exempt from
   the #1480 gate) — **default flags, exit 0, tally prints**;
2. any criterion-only-traced FR under `--allow-unit-fallback` — exit 0,
   tally prints.

## Goal

**Option B — keep and pin.** The machinery is LIVE through the
criterion-token seam and its diagnostics are correct (the author wrote a
`traces:` line that looks bound but names a criterion id, not a contract
row; the plan announces the dead-end at make in seconds). Pin it with a
live fixture, assert the tally and the verdict key, prove the pinning tests
guard against future deletion, and correct the machinery's provenance
documentation in `plan_command.dart` (which currently parrots the disproved
unreachability claim).

## Success criteria (measurable)

- **SC-1**: A spec whose FR carries a `[persistent]` tag and an inline
  `traces:` line binding only a criterion-shaped token (`traces: FR-001`)
  plans with exit 0 under DEFAULT flags; stdout renders the fatal-class
  route line (`route: U1 -> unit lane [fallback: no declared trace — make
  will dead-end — ...]`) AND the one-line tally (`zfa tdd plan: 1 behavior
  will dead-end at make — no declared contract trace (U1). ...`).
- **SC-2**: The same routing reaches the machinery via the second live
  route — the same spec without the `[persistent]` tag run with
  `--allow-unit-fallback` — exit 0, tally renders with the behavior id.
- **SC-3**: The verdict envelope (plan run with `--json`) carries
  `details.dead_end_behaviors == 1` for the SC-1 fixture.
- **SC-4**: The pinning tests FAIL when the machinery is deleted from
  `plan_command.dart` (mutant red evidence: remove the `!repairable` add,
  the fatal prefix, the tally call, and the verdict key — the Option-A-style
  deletion) — recorded as red evidence, then the machinery is restored and
  the tests pass (green). This proves the tests guard the machinery, not
  just the happy path.
- **SC-5**: The existing #1481 guards keep passing unchanged: manual-routed
  unbound FRs render no fatal prefix and no tally; a repairable scenario
  fallback under `--no-emit-markers` renders the REPAIRABLE class, not the
  fatal one.
- **SC-6**: `plan_command.dart`'s dead-end documentation no longer claims
  the fatal class is unreachable: the `_provenanceLines` dead-end doc, the
  `RoutingUndeclared` fallback comment, and the `_printDeadEndTally` doc
  name the criterion-token seam and point at the pinning test. No rendered
  string, exit code, or routing decision changes.

## Hard constraints

- Must change `plan_command.dart` (out of scope for test-only PR #1527) —
  the documentation correction above; behavior stays byte-identical.
- Must pass `dart analyze` with no new warnings.
- No change to `RoutingResolver` / `SpecParser` routing semantics (the
  criterion-token skip is shared by make/gen cell tokenization — out of
  scope).
- One PR, `Closes #1537`.

## Out of scope

- Refusing criterion-only trace bindings at plan time (a behavior change
  beyond both of the spec's options; candidate follow-up issue).
- The #1480 unit-fallback gate semantics or its exemption set.
- The `--allow-unit-fallback` / `--strict-routing` flag matrix beyond the
  two pinned routes.
- Make/gen-side consumption of criterion tokens (resolver cell shape).
