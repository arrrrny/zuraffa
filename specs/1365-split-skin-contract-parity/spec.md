**Template Version**: `zuraffa-1.0`

# Spec: 1365-split-skin-contract-parity

GitHub issue: arrrrny/zuraffa#1365 (verify-misfire / spec-drift, EPIC #1012 Phase A step 5)

## Summary

`zfa tdd split --force` re-emits 04-SKIN.md in the PRE-1004 shape: the
split path passed no skin contract to `renderSkinPlan`, so the platform
contract matrix (#1004), the state machine, the route table, and the
machine-parseable skin-contract JSON silently disappear on a forced
re-split (91 lines lost on the 004-login-ui fixture). The machine JSON is
consumed downstream (`parseSkinContractJson`, spec 079 binding; runtime
auditor spec 1102) — a re-split can silently break skin-contract binding.

## Locked decisions

1. The split path parses the spec's `## Skin Contract` with the SAME
   shared parser plan uses (`parseAdaptiveSkinContract`) and passes the
   contract to `renderSkinPlan` — one parser, one renderer, parity by
   construction (the issue's "delegate to the plan emitter" remedy).
2. A MALFORMED `## Skin Contract` section refuses the split BEFORE any
   lane plan is written: exit 2, the refusal names the section and the
   fix (mirroring plan's skin-contract refusal semantics).
3. A spec with no `## Skin Contract` section renders exactly the
   pre-1004 shape (the parser returns null; no behavior change).
4. Provenance maps stay out of scope (the issue's lost sections are the
   contract rows + JSON; the empty-provenance split default is retained).
5. No changes to `renderSkinPlan`/`renderEnginePlan`/`renderContractPlan`
   or the plan command.

## Functional requirements

- **FR-1 (parity)**: split renders the platform matrix, state machine,
  route table, and machine JSON (`adaptiveSlots` markers) whenever the
  spec declares a `## Skin Contract` — identical sections to plan's
  04-SKIN.md.
- **FR-2 (honest refusal)**: a malformed section exits 2 with the
  refusal naming the drift; no lane plans or receipt are written.
- **FR-3 (no-contract guard)**: no section → pre-1004 shape, exit 0.
- **FR-4 (forced re-split)**: `--force` keeps the full contract
  (the issue's exact regression path).

## Acceptance scenarios

1. split (fresh) with lanes + Skin Contract → exit 0, 04-SKIN.md carries
   `home_indicator_safe_area`, `title_bar_alignment`, states, routes,
   `adaptiveSlots`.
2. Malformed Skin Contract → exit 2, refusal names it, no 04-SKIN.md.
3. No Skin Contract → exit 0, pre-1004 shape (guard).
4. split then `split --force` → the contract sections survive the forced
   re-split (the issue regression).

## Success criteria

- **SC-001**: A forced re-split's 04-SKIN.md is at parity with
  plan-emitted skin contract sections — re-splitting can no longer
  silently break skin-contract binding.
- **SC-002**: The split/skin suites stay green.

## Assumptions

- Empty provenance maps in the split path stay (the plan command's
  provenance derives from routing migration state split does not own).
