**Template Version**: `zuraffa-1.0`

# Spec: 1367-realize-mock-cert-fallback

GitHub issue: arrrrny/zuraffa#1367 (verify-misfire / missing-integration,
EPIC #1014 exit criterion 2 / #1009)

## Summary

`zfa tdd realize-mock Login --against=firestore` answered `unknown entity`
immediately after a successful `zfa mock create Login --certify`: the
differential gate resolves entities EXCLUSIVELY through
`specs/<feature>/tdd/artifacts.json`, while the mock plugin's
certification output lives in its own registry
(`test/mock/<snake>/mock-cert.<Entity>.json` naming the generated
contract test via `contract_test`). The epic's two halves — certification
(#1001) and the differential gate (#1009) — could not compose.

## Locked decisions

1. Remedy (a) from the issue: when no artifacts registry names the
   entity, realize-mock resolves through the certification receipt. The
   receipt's `contract_test` is the Tier-1 test; each CERTIFIED method
   (`satisfied: true`) synthesizes a realize-diff.v1 case under
   `.zfa/realize-mock/<snake>/fixtures/`.
2. The fallback home (`mock-cert-<snake>` + the synthesized fixtures
   dir) rides `_EntityResolution` as explicit overrides — the flow's
   Tier-1 gate, case reader, differential, and receipt machinery run
   unchanged.
3. Honest refusals keep their meaning: no receipt anywhere → the
   unknown-entity usage error stands; a receipt naming a missing
   contract test → the `no contract test` BLOCKED outcome (never
   unknown-entity); unsatisfied methods never synthesize cases.
4. Write-side registration (`--certify` also registering into a feature's
   artifacts.json — the issue's remedy (b)) is NOT taken: it would force
   every mock through a spec-kit flow, which the issue explicitly rules
   out.
5. Cross-plugin coupling stays decoupled: the fallback reads the receipt
   JSON by contract (schema fields), not by importing the mock plugin's
   receipt class.

## Functional requirements

- **FR-1 (resolution)**: with a certification receipt present, the
  entity resolves; the receipt's contract_test is discovered as the
  Tier-1 test and the differential certifies (`verdict certified`).
- **FR-2 (case synthesis)**: one realize-diff.v1 case per satisfied
  method, written to `.zfa/realize-mock/<snake>/fixtures/<method>.json`;
  unsatisfied methods synthesize nothing.
- **FR-3 (honest refusals)**: no receipt → unknown-entity (exit 1,
  usage-error); receipt naming a missing contract test → the blocked
  `no contract test` outcome (never unknown-entity).

## Acceptance scenarios

1. Receipt with two certified methods + the contract test on disk →
   `tier-1 contract test: 1 file(s)`, `verdict certified`, synthesized
   cases on disk (exit 0).
2. No receipt, no registry → `unknown entity "Login"` (exit 1).
3. One unsatisfied method → only the satisfied method's case exists.
4. Receipt naming a missing contract test → `no contract test for entity
   Login` blocked (exit 1).

## Success criteria

- **SC-001**: The epic exit criterion 2 sequence works end-to-end:
  certify, then realize-mock resolves and certifies without fabricating
  a spec-kit registry.
- **SC-002**: The realize-mock suites stay green.

## Assumptions

- Synthesized cases carry no recorded mockOutput — the tier-1 driver
  protocol provides the oracle side at differential time.
