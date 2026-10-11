**Template Version**: `zuraffa-1.0`

# Spec: 1366-plan-writes-split-receipt

GitHub issue: arrrrny/zuraffa#1366 (verify-misfire / spec-drift, EPIC #1012 Phase A / #1000 exit criterion 4)

## Summary

The committed tree ships the 004-login-ui fixture as SPLIT (lane
meta-index + lane plans) WITHOUT `split-receipt.json` — plan refreshed a
receipt only when one already existed, so a plan-produced lane split
never carried the migration record and `zfa tdd split`'s one-shot guard
refused forever ("the migration record was lost — issue #1309").

## Locked decisions

1. The receipt write in plan's lane-plans path is UNCONDITIONAL: whenever
   plan emits 04-ENGINE/04-SKIN/04-CONTRACT + the meta-index, it writes
   `split-receipt.json` — a plan-emitted tree always carries the record
   the one-shot guard keys on.
2. Provenance is preserved and distinguished: a pre-existing receipt is
   refreshed by MERGE (all prior fields survive; spec hash/mtime,
   `refreshed_at/by/rows` updated — the #1309 contract unchanged). A
   plan-first receipt carries `source: 'zfa tdd plan'` (vs the one-shot
   split's `tdd/test-list.md`).
3. No guard semantics change: the staleness check (#1309) runs upstream
   exactly as before; this fix only closes the record-LOSS hole.
4. The shipped example fixture's missing record is healed by re-running
   plan on it (the mechanism above), committing the regenerated receipt.

## Functional requirements

- **FR-1**: plan without a pre-existing receipt writes
  `split-receipt.json` with `source: 'zfa tdd plan'`, the classification,
  and the spec hash.
- **FR-2**: the plan-written receipt satisfies the one-shot guard — a
  follow-up plain `zfa tdd split` resolves honestly (no lost-record
  refusal).
- **FR-3**: a pre-existing receipt is refreshed by merge (custom fields
  survive; `refreshed_by: zfa tdd plan`).

## Acceptance scenarios

1. plan (no receipt) → exit 0, receipt on disk with `source: zfa tdd
   plan`, spec hash, classification (B1).
2. After plan, plain `zfa tdd split` → no "migration record was lost"
   refusal (B2).
3. Pre-existing receipt with a custom field → after plan, the field
   survives + refresh fields updated (B3).

## Success criteria

- **SC-001**: The record-loss drift class is closed: plan-emitted lane
  plans always carry the migration record.
- **SC-002**: The plan/split suites stay green.

## Assumptions

- The receipt's `source` field distinguishes provenance without a schema
  version bump (consumers key on presence, not source).
