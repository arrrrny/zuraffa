# Bug Assessment: scalar vacuous-green refusal prints the void/entity explanation

- **Slug**: 1677-scalar-vacuous-green-message
- **Created**: 2026-09-18
- **Source**: https://github.com/arrrrny/zuraffa/issues/1677
- **Verdict**: valid, reproduced in this session (RED evidence below)
- **Severity**: medium

## Report (summarized)

The `zfa tdd run` vacuous-green make stop for a SCALAR contract-row unit
behavior (`add(int a, int b) -> int`) prints the #1308 void/entity
hand-delta-seam template: "the traced contract's return is void/an entity
— the `zfa:tdd: vacuous-guard` marker IS the designed hand-delta seam
(issue #1308): the assertion set is the UnimplementedError guard only,
which make refuses vacuous-green (issue #1259)." Both claims are false for
the scalar branch: the declared return is `int` (neither void nor an
entity), and the assertion set is the declared-return-TYPE check
(`expect(result, isA<int>())`) the #1517 func dummy satisfies — which is
exactly what the make refusal excerpt printed above the paragraph on the
same screen says (the issue #1651 placeholder wording). The two paragraphs
contradict each other on the same screen.

## Symptom

The run driver's make vacuous-green marker-present arm keys only on the
`zfa:tdd: vacuous-guard` marker. Since #1651, the scalar type-only shape's
generated test ALSO carries that marker (`typeOnlyVacuousGuardComment` is
emitted with the typed assertion), so the arm fires for scalar contracts
too — and prints the void/entity template unconditionally.

## Reproduction

Reproduced in this session (unfixed master a9329746) by
`test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart` U1:
a traced scalar contract row (`FR-001, Calculator`), a generated test
carrying the #1651 scalar shape (marker comment + `expect(result,
isA<int>())`), make refusing `outcome=vacuous-green`. The driver printed
the void/entity template verbatim; the pin on the scalar explanation
failed with `does not contain 'the traced contract's return is scalar
(int)'`.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_driver_core.dart` — the make
  vacuous-green marker-present arm (the refusal message's middle
  paragraph; the observed text).
- `lib/src/plugins/tdd/services/vacuous_guard.dart` — the marker
  constants, the `_typeOnlyScalarExpect` detector, and the #1651
  `typeOnlyVacuousGuardComment` (the scalar branch's marker comment).
- `lib/src/plugins/tdd/services/behavior_test_writer.dart` —
  `_declaredAssertion`, whose scalar branch already discriminates the
  emission (marker + typed type-only assertion vs marker + guard).

## Root Cause

The marker-present arm's explanation is a single unconditional template
written when the arm's population was ONLY the void/entity shape (#1259
emission). #1651 widened the marker-carrying population to scalar-declared
contracts (the typed type-only assertion carries the same marker), but the
message was not widened with it — it still describes the void/entity
shape: the return type claim ("void/an entity") and the assertion-set
claim ("the UnimplementedError guard only") are both the #1259 emission's
properties, not the #1651 emission's.

## Proposed Remediation

Branch the refusal message on the same discriminator the writer's
emission already produced: read the generated test content (fail-open) at
the arm and detect the scalar type-only expect (`isA<T>()` with T in the
dummy-satisfiable scalar set) — the writer's scalar branch's emitted
shape.

* scalar type-only expect present → print the #1651 scalar explanation:
  "the traced contract's return is scalar (`<T>`) — the
  `zfa:tdd: vacuous-guard` marker's assertion set checks the declared
  return TYPE only; a func-scaffolded dummy (`return 0;`) satisfies it
  (issue #1651)."
* otherwise → the #1308 void/entity template, byte-for-byte unchanged.

Hard constraints (all honored by this remediation): the `--> fix:` and
`hand step:` lines are unchanged; the #1651 gate semantics are unchanged
(detection, refusal outcome, and the `stopped_at=<id>:hand` machine
contract stay as-is); the #1308 hand-delta-seam handling is unchanged for
void/entity contracts. Messaging only.

## Risks & Considerations

- Regression family: #1259 → #1308 → #1483 → #1626 → #1651 — the refusal
  surface was touched by every member; the void/entity branch's wording
  is pinned by `issue_1308_vacuous_guard_remedy_driver_test.dart` (U6)
  and must stay byte-identical.
- The discriminator is content-based (the emitted test), not a re-parse
  of the spec's contract row: a re-parse would duplicate the shape
  derivation and could drift from what the author actually sees on
  screen. Fail-open (unreadable file → void/entity wording) mirrors the
  arm's existing marker probe.

## Open Questions

None — the remediation is fully determined by the assessment; no
follow-up behavior changes are in scope for this bug.
