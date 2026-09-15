# Bug Assessment: blocked-contract stop names the TEST file as the hand surface and suggests `zfa tdd wire … --entity <X>` — which fails when no such entity exists

- **Slug**: 1625-blocked-contract-hand-surface
- **Created**: 2026-09-15T11:07:37Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1625
- **Verdict**: valid (root cause confirmed in code)
- **Severity**: unknown (labels: bug, tdd, track-tdd-loop) — developer-facing guidance bug, no data loss

## Report (verbatim or summarized)

With the #1589 fix merged, the blocked-contract stop names a hand surface — but it
names the wrong file, and its suggested command cannot run in a project whose
contract row has no entity. Full report:
https://github.com/arrrrny/zuraffa/issues/1625

## Symptom

A fresh `zfa tdd run calculator` parks contract behaviors with a hand-surface
hint that (1) names the generated contract TEST file
(`test/tdd/calculator/contract_a1_test.dart`) instead of the implementation
seam it imports (`lib/tdd/calculator/contract_a1_subject.dart`), and (2)
suggests `zfa tdd wire contract:A1 --entity Calculator`, which exits 1 in a
project with no `Calculator` entity (wire demands `zfa entity create` first).

## Reproduction

From the issue (zfa built from `cbb9bed2`):

1. Fresh spec with a `calculator` feature declaring contract behaviors
   `contract:A1..A4` (`Calculator.add` etc.) — no `Calculator` entity created.
2. `zfa tdd run calculator` → each contract verify-red reports `blocked`.
3. The stop prints:
   `hand surface: seam test/tdd/calculator/contract_a1_test.dart — implement
   the declared contract Calculator.add there (e.g. zfa tdd wire contract:A1
   --entity Calculator)`.
4. Running the suggested wire command fails: `no generated entity "Calculator"
   found under …/lib/src/domain/entities`.
5. Implementing the four subject seams by hand converges the run to
   `result=complete` — but no stop message points there.

## Suspected Code Paths (verified)

- `lib/src/plugins/tdd/services/hand_surface.dart` — the hand-surface
  vocabulary:
  - `seamPathFor` (L63-84): candidate list is TEST-ONLY
    (`test/tdd/<feature>/<snakeId>_test.dart`, then the legacy flat
    `test/tdd/<snakeId>_test.dart`); returns the first that exists, else the
    canonical test path. No subject candidate exists.
  - `hintLine` (L89-100) → `wireCommandFor` (L43-48): synthesizes
    `zfa tdd wire <id> --entity <E>` from the dotted contract trace without
    ever checking that the entity exists on disk.
- Call sites that print the hint:
  - `lib/src/plugins/tdd/commands/run_driver_core.dart` L1288-1296 (terminal
    `result=blocked` block) and L2306-2313 (per-behavior park note) — both
    source the seam path via `HandSurface.seamPathFor`.
  - `lib/src/plugins/tdd/commands/verify_red_command.dart` L447-457 (blocked
    arm) — sources the seam path from `record.testPath` (the generated TEST).
  - `lib/src/plugins/tdd/commands/make_command.dart` L486-508
    (implement-seam-first arm) — sources the seam path from `testPath` (the
    generated TEST).

## Root Cause Hypothesis (confirmed)

`seamPathFor` models the seam as the generated contract test only — the
subject (`lib/tdd/<feature>/<snakeId>_subject.dart`, the throwing stub the
contract test imports, confirmed as the canonical convention in
`vacuous_guard.dart` L210-213) is not among the candidates, so the stop names
a generated, registry-owned artifact instead of the hand surface. In
parallel, `hintLine` prints the with-entity wire example unconditionally,
while `zfa tdd wire` (wire_command.dart L265-280) refuses when
`locateEntityFile` finds no `lib/src/domain/entities/<snake>/<snake>.dart` —
so the printed command is guaranteed to fail exactly when its guidance is
needed most (a contract with no backing entity).

## Proposed Remediation

Hand-surface detection + hint logic ONLY (the #1007 block gate and the wire
mechanics are untouched):

1. `seamPathFor`: prefer the subject path
   (`lib/tdd/<feature>/<snakeId>_subject.dart`) existence-first, then the two
   existing test candidates; when nothing exists, the canonical display
   fallback becomes the subject path (the hand surface the make command
   names).
2. `hintLine`: require `projectRoot`; when the contract traces a dotted
   entity, print the with-entity wire example ONLY if that entity exists
   (`lib/src/domain/entities/<snake>/<snake>.dart`, mirrored synchronously
   from `locateEntityFile`'s resolution); otherwise print the hand-implement
   instruction naming the subject seam + the `zfa entity create` prerequisite.
3. `verify_red_command.dart` and `make_command.dart` blocked arms: source the
   printed seam path through `HandSurface.seamPathFor` (subject-first) instead
   of `record.testPath`, so every blocked stop names the same hand surface.
4. The refactor-gate handoff (`--parked-seam` via
   `_existingGeneratedTestPath`) is NOT touched — it must stay anchored to
   the attested failing TEST file.

## Risks & Considerations

- The #1589 tests pin `zfa tdd wire contract:A1 --entity User` in fixtures
  with NO `User` entity on disk — under the entity-gated hint that output is
  exactly the bug. Those fixtures gain the entity so the with-entity pins
  test the new contract legitimately (hint printed because the entity exists).
- Messaging-only: no verdict, receipt, state-machine, gate or wire mechanics
  change; every printed path remains display-only (the parked-seam handoff
  stays existence-gated through its own resolver).

## Open Questions

- None — repro shape, root cause and fix surface are all confirmed in-code.
