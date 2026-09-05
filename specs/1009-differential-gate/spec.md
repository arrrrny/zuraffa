# Feature Specification: Differential gate — realize-mock against Firestore (spec 1009)

**Feature Branch**: `1009-differential-gate` (delivered on `epic/1014-mock-certification`)

**Created**: 2026-09-05

**Status**: Implemented

**Template Version**: `zuraffa-1.0`

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/1009 — [ZIKZAK-REBUILD] Differential gate: realize-mock against Firestore (M-TRACK). Epic #1014 MOCK-CERTIFICATION, child of the certified-mocks track."

## Context

`zfa tdd realize` (spec 913) swaps a mock for a real adapter behind the same
generated interface, gated by the contract suite and a fixtures differential.
Issue #1009 extends the mock-certification track (epic #1014) with a
**per-entity differential gate**: the same Tier-1 contract test (spec 1001)
runs against BOTH the Tier-1 mock and a Tier-2 Firestore-shaped adapter, and
the per-method outcomes are compared. Divergence = failure; same green
result = certified. This spec delivers exactly that gate — it reuses the
spec-1001 sandbox (dart analyze + dart test) and never changes Tier-1
generation semantics.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - `zfa tdd realize-mock <Entity> --against=firestore` certifies the differential (Priority: P1)

A developer runs the differential gate over a certified mock. The command
loads the COMMITTED Tier-1 contract test (`test/mock/<snake>/
<snake>_mock_contract_test.dart` — it never re-renders it), runs it unchanged
against the Tier-1 mock, swaps the subject to a generated
`<Entity>Tier2MockProvider` (Firestore-shaped adapter implementing the SAME
`<Entity>DataSource` interface, backed by a fake in-memory
`FirebaseFirestore` — collection/doc/get/set/delete/snapshots, watchers
notified on writes), runs the swapped test in the same kind of throwaway
sandbox, and compares per-method outcomes.

**Independent Test**: `zfa tdd realize-mock Login --against=firestore` exits 0
with a clean receipt — every method `{tier1_result: "pass", tier2_result:
"pass", diff: "none"}`, `result: "certified"`.

**Acceptance Scenarios**:

1. **Given** a certified Login mock, **When** realize-mock runs, **Then** both
   tiers run in sandboxes (dart pub get + analyze + test with the JSON
   reporter), the Tier-2 adapter rides along as an extra sandbox file, and the
   exit code is 0 only when every method is green on both sides.
2. **Given** the run, **Then** `test/mock/<snake>/realize.<Entity>.firestore.receipt.json`
   is written with per-method `{method, tier1_result, tier2_result, diff}`,
   the contract digests (tier-1 committed + tier-2 swapped), and sandbox
   evidence.
3. **Given** the receipt, **Then** a `proof.v1` generation receipt in
   `.zfa/receipts/` covers its bytes, so `zfa proof check` re-derives the
   digest (machine-readable AND verified — a tampered receipt is a finding).

### User Story 2 - A divergent method fails the gate and is named (Priority: P1)

A Tier-2 adapter method returns a wrong-typed value (runtime). The contract
test fails on the Tier-2 side only; the gate exits 1 and NAMES the method.
The `--diverge <method>` chaos hook makes this provable on demand: it renders
the named method's body to return a wrong-typed value (a failing cast), so
the divergence is injected deliberately and the gate must catch it.

**Independent Test**: `zfa tdd realize-mock Login --against=firestore
--diverge=get` exits 1 with `divergence=get` in the summary and the receipt
(`get: tier1 pass / tier2 fail / diff mismatch`).

**Acceptance Scenarios**:

1. **Given** a clean tier-1 side and a failing tier-2 method, **Then** the
   exit code is 1, the divergent methods are named in stdout and in the
   receipt's `divergence` list.
2. **Given** the `--diverge` hook naming a method that does not exist (or is
   Stream-returning), **Then** the command refuses (exit 2) instead of
   guessing.

### User Story 3 - Attribution honesty: a red baseline is never the adapter's fault (Priority: P1)

When the Tier-1 contract itself is red (mock broke its own contract), the
gate refuses with `result=tier1-red` (exit 2) and the fix hint — the same
attribution discipline `ContractGate` (spec 913) applies: a broken baseline
cannot certify anything, and blaming the Tier-2 adapter would be dishonest.

**Independent Test**: with the tier-1 side failing and no divergence, the
command exits 2, prints `BLOCKED: the Tier-1 contract itself is red`, and
never reports a mismatch.

### User Story 4 - The receipt is machine-readable (Priority: P2)

The receipt JSON (schema 1, spec 1009) is stable, round-trips through
`fromJson`, and is covered by a `proof.v1` generation receipt the existing
`zfa proof check` verifies with zero findings.

**Independent Test**: `zfa proof check` after a realize-mock run prints
`0 finding(s) — OK` and the artifact is digest-verified.

## Hard constraints

- Tier-1 generation semantics unchanged (the committed contract test is
  loaded, never re-rendered; the swap changes exactly two things: one import
  and one construction site — every pin stays byte-identical).
- The Tier-2 adapter is sandbox-only: never committed to the target project.
- Pure-Dart toolchain (no cloud_firestore dependency): the "Firestore shape"
  is the adapter's routing through the fake FirebaseFirestore, mirroring the
  spec-1001 sandbox's `dart test` choice (CI parity, `.specify/memory/tdd-profile.md`).
- One PR closes #1009; the epic PR (#1014) carries both children.
