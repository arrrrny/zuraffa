# 913-tdd-realize

- **Spec ID**: 913-tdd-realize
- **Created**: 2026-09-03
- **Source**: GitHub issue #913 (ROADMAP P1)
- **Type**: feature
- **Priority**: P1

## Problem

Mocks are 100% generatable; real impls are not. The honest 90/10 (mock-first → real) becomes enforced physics through a single command — `zfa tdd realize <entity|behavior> --adapter <real>`. Today there is no command to swap a mock datasource for the real adapter while preserving the contract, capturing differential evidence, and recording hand-written deltas.

## Goal

Provide `zfa tdd realize` that rebinds DI from mock to real behind the SAME generated interface, gates the swap with contract + differential proofs, and carries nuance receipts for hand-written deltas.

## Command contract

`zfa tdd realize <entity|behavior> --adapter <real>`:

1. **Rebinds DI** from mock datasource to the real adapter behind the SAME generated interface (no contract change).
2. **CONTRACT GATE**: the MOCK-era suite runs unchanged against the real binding — must stay green. Any red = the real impl (or the mock) broke the contract; verdict says which side.
3. **DIFFERENTIAL GATE**: real vs mock run the same committed fixtures (extends #832 simulate adapters); output diff = drift report, threshold from `.zfa.json`. Reuses #805 differential machinery.
4. **NUANCE RECEIPTS** (#807 proof-carrying): any hand-written delta is recorded (file, reason, diff-hash) in the feature's provenance ledger. Hand-deltas are legal; ungated hand-deltas are not.
5. **State transitions MOCKED → REAL**; cycle-log carries era-tagged evidence.

## Why this is the keystone

Mocks are 100% generatable; real impls are not. This command is where the honest 90/10 becomes enforced physics instead of aspiration.

## Success criteria

- MOCK-era suite stays green when run against the real binding
- Differential report quantifies real-vs-mock output drift with configurable threshold
- All hand-written deltas recorded in provenance ledger with reason + diff-hash
- State transitions MOCKED → REAL; era tags carried through cycle-log
- Mock-first realization is the default path (not an aspirational one)

## References

- #913 (GitHub issue, ROADMAP P1)
- #908 (Mock-First Realization parent)
- #832 (simulate adapters)
- #805 (differential machinery)
- #807 (proof-carrying nuance)

## Out of scope

- Auto-generating real implementations (only the swap + gates are spec'd)
- Multi-real adapter orchestration (single `--adapter` only)
