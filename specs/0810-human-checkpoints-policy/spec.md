# Feature Specification: Human checkpoints as policy — approval gates + sign-off ledger (issue #810)

**Feature Branch**: `feat/issue-810`

**Created**: 2026-10-18

**Status**: Draft

**Input**: Issue [#810](https://github.com/arrrrny/zuraffa/issues/810) — "[VISION] 🚦 Human checkpoints as policy: approval gates + a sign-off ledger". Part of 🧭 VISION 2030 (#804), Pillar B: Agent runtime.

## First slice (v0)

- Gate on `entity remove` and pubspec mutations.
- Ledger record: mission id, gate, request payload, decision, identity, timestamp.
- `zfa policy gates --format json` (machine contract per #778).

## Requirements

### Functional Requirements

- **FR-001**: System MUST provide a registry of approval gates for operation classes (entity.remove, pubspec.mutate).
- **FR-002**: A gated operation MUST block until approved, record a ledger entry, and resume after approval.
- **FR-003**: The sign-off ledger MUST be append-only and hash-chained (tamper-evident).
- **FR-004**: `zfa policy gates --format json` MUST emit the gate list as JSON.
- **FR-005**: `zfa policy ledger verify` MUST verify the hash chain.
- **FR-006**: `zfa policy ledger list` MUST list entries.

## Key Entities

- **PolicyGate**: an operation class requiring a human checkpoint.
- **SignOffEntry**: a ledger record (mission id, gate, request payload, decision, identity, timestamp, prevHash, hash).
- **SignOffLedger**: append-only, hash-chained JSONL store under `.zfa/ledger/`.
- **ApprovalGate**: helper that checks a gate, records the decision, and approves/blocks.
