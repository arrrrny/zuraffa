# Plan — Spec 1365 split skin-contract parity

**Branch**: `1365-split-skin-contract-parity` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

In `split_command.dart`: after the spec is read, `parseAdaptiveSkinContract(specMd)`
(shared parser, same one plan uses); `AdaptiveSkinContractParseException`
→ print the refusal + SPEC 917 fix line, verdict envelope
`skin-contract-refused`, exit 2, return BEFORE writing any artifact.
Pass the parsed contract to `renderSkinPlan(skinContract:)`. The
pre-1004 shape (null contract) is untouched.

## Test strategy

`test/plugins/tdd/commands/bug_1365_split_skin_contract_parity_test.dart`
(B1 parity sections + JSON, B2 malformed refusal, B3 no-contract guard,
B4 forced re-split keeps the contract). Scoped pin: split 1000, #1309,
plan-skin-contract, skin-receipt suites + analyze.
