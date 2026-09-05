# Spec 0996 — Receipts on standalone capability invocations (ZIKZAK-REBUILD, T-TRACK)

## Problem

Per VISION.md and the fleet report: "every artifact ships a verifiable receipt." Today,
`ReceiptStore` is only written by `PluginManager._persistGenerationReceipt` on the
`zfa make` path. Standalone invocations (`zfa di create`, `zfa cache adapter <E>`,
`zfa repository create`, etc.) write no receipts. The vision is partial.

## Requirements

FR-001: The system MUST auto-persist a `proof.v1` receipt after every successful
standalone capability execution via a `CapabilityInvocationWrapper` (or a thin hook in
`CapabilityCommand.execute()` post-execution), keyed to
`<plugin>-<capability>-<entity>-<timestamp>.json` in `.zfa/receipts/`.

FR-002: Receipts MUST be emitted for: `di create`, `cache adapter`,
`repository create`, `usecase create`, `service create`, `datasource create`,
`provider create`, `shadcn <layout>`, `state create`, `observer create`,
`sync enable`, `strategy create`.

FR-003: Receipts MUST be machine-readable with the schema
`{plugin, capability, entity, hash, methodset, files, receipt_version: 1}`.

FR-004: `zfa proof check` on a standalone receipt MUST validate: exit 0 with
`valid: true` in the machine verdict.

FR-005: `zfa tdd verify` (the audit step) MUST include receipt-checking as a
preflight gate; a missing receipt for an audited subject MUST trigger gate failure
when the project ships receipts.

## Constraints

- All deliverables in this single PR; one PR per spec.
- Receipts must be machine-readable; proof check must validate; tdd verify must
  include the receipt gate.
- Receipt persistence is best-effort on the capability path (a receipt failure must
  not fail an otherwise-successful generation), mirroring the make-path contract.
- Projects that ship no receipts (no `.zfa/receipts/` content) keep working: the
  tdd verify receipt gate is vacuous for them (backward compatibility).

## Exit criteria

- Run each standalone and verify a file appears in `.zfa/receipts/`.
- `zfa proof check` on the resulting receipt validates (exit 0 with `valid: true`).
- `zfa tdd verify` (the audit step) includes receipt-checking as a preflight gate.
