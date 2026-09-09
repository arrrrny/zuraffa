# Plan — Spec 1366 plan writes the split receipt

**Branch**: `1366-plan-writes-split-receipt` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`plan_command.dart`: the `if (splitReceiptExists)` gate around the
receipt refresh is removed — the refresh runs whenever lane plans are
emitted. The payload branch distinguishes provenance: an existing receipt
merges (prior fields survive), a fresh one carries
`source: 'zfa tdd plan'` + classification. Upstream staleness semantics
(#1309) untouched.

## Test strategy

`test/plugins/tdd/commands/bug_1366_plan_writes_split_receipt_test.dart`
(B1 fresh receipt, B2 one-shot guard satisfaction, B3 merge preserves
custom fields). Scoped pin: split 1000, #1309, plan-skin-contract, and
the #1365 parity suites + analyze.
