# Feature Specification: Tier-1 Certified Mocks — auto-generated contract tests + deterministic seeds (spec 1001)

**Feature Branch**: `1001-certified-mocks-contract-tests`

**Created**: 2026-09-04

**Status**: Implemented

**Template Version**: `zuraffa-1.0`

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/1001 — [ZIKZAK-REBUILD] Tier-1 certified mocks: auto-generated contract tests + deterministic seeds. VISION §9: 'mocks the framework certifies, not the agent.'"

## Context

The mock plugin (#908/#935) produces Tier-1 mocks by default, but "certified" (VISION §9) means three things that did not exist before this spec: every mock satisfies its interface (`dart analyze`), a contract test proves method satisfaction, and the mock is registered in the #832 certification registry. This spec adds exactly those three rails plus deterministic (replayable) generation — without changing any existing mock generation semantics.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - `zfa mock create <Entity> --certify` certifies what it generates (Priority: P1)

A developer generates a Tier-1 mock and asks the framework to certify it. After the normal generation, zuraffa auto-generates `<snake>_mock_contract_test.dart` — for each method on the interface, a typed tear-off pin (`final Ret Function(Params) m$ = dataSource.m;`) through the INTERFACE type plus a behavioral invocation proving the fake returns typed default data — then runs that contract test in a throwaway sandbox package (`dart pub get` + `dart analyze` + `dart test`, the mock's import closure copied in, the zuraffa framework resolved as a path dependency), and writes `mock-cert.<Entity>.json` next to the test with per-method `satisfied: true|false`, the SHA-256 digest of the contract, and the sandbox evidence. A red contract fails the command honestly (exit 1) while still writing the legible red receipt.

**Independent Test**: `zfa mock create Login --certify` produces the mock, runs the contract test, and writes `mock-cert.Login.json` with all methods `satisfied: true`.

**Acceptance Scenarios**:

1. **Given** a project with a generated Login mock stack, **When** `zfa mock create Login --certify` runs, **Then** the sandbox runs `dart analyze` + `dart test` against the mock's import closure and the exit code is 0.
2. **Given** the certification, **Then** `test/mock/login/login_mock_contract_test.dart` and `test/mock/login/mock-cert.Login.json` are committed into the project (the certification stays live in the project's own suite).
3. **Given** a mock-less entity name, **When** `--certify` runs, **Then** it refuses honestly naming `zfa mock create <Entity> --certify` as the fix — never a receipt that lies.

### User Story 2 - The certification is live: interface drift goes red (Priority: P1)

A developer later removes a method from the repository interface. The committed contract test still pins that method through the interface type, so it stops compiling — the certification goes red exactly when the contract drifts, not at some later audit.

**Independent Test**: Remove `get` from `LoginDataSource`, run `zfa mock certify Login` — the committed contract test fails to compile (`undefined_getter: get`), the command exits 3, and the on-disk receipt is overwritten with the honest per-method `satisfied: false` (a stale green receipt must never survive a red run: the run-engine gate reads it).

**Acceptance Scenarios**:

1. **Given** a certified mock, **When** a method is removed from the interface, **Then** the committed contract test fails to compile and `zfa mock certify <Entity>` refuses (exit 3) with a drift diagnostic naming the removed method.
2. **Given** a red re-certification, **Then** the receipt on disk records the unsatisfied methods (the gate never reads a stale green receipt).
3. **Given** a tampered contract test (bytes differ from the receipt's recorded digest), **Then** certification names the mismatch and refuses.

### User Story 3 - `zfa mock certify <Entity>` registers the mock in the #832 registry (Priority: P1)

The #832 fixture registry gains mock provenance: the freshly-proven receipt is committed into the feature's `tdd/fixtures/` directory as a certified fixture, the manifest is rewritten with a `mocks:` list (alongside the existing `families:`), the receipt's bytes are hashed into the world digest, and a hash-chained `kind: mock-cert` cycle-log entry is appended. Registry adds are LIVE re-proofs — never copies of old receipts.

**Independent Test**: `zfa mock certify Login --fixtures-dir specs/<f>/tdd/fixtures` exits 0 with the machine summary `mock-certify: entity=Login methods=3 satisfied=3 feature=<f> registered=true`, the manifest lists `mocks: ["Login"]`, and tampering with the committed receipt trips `verifyManifest`.

### User Story 4 - Deterministic seeds: replayable generation (Priority: P2)

A developer passes `--seed=<int>`: every generated mock record derives from the seed, so the same seed + inputs reproduce byte-identical mocks. Without `--seed` the historical record seeds (1/2/3) are unchanged — existing generation semantics are untouched.

**Independent Test**: `zfa mock create Login --seed=42` in two fresh projects produces byte-identical `login_mock_data.dart` / `login_datasource.dart` / `login_mock_datasource.dart` (records `id 42`, `id 43`, `id 44`); `--seed=7` differs.

### User Story 5 - The run engine refuses uncertified CORE mocks (Priority: P1)

`zfa tdd run-engine <feature>` is the run engine's certification gate: for the feature's declared Key Entities (the CORE entities phase 0 orchestrates), any entity whose mock is present on disk but uncertified (receipt missing, corrupt, or any method unsatisfied) refuses to proceed — the exact "agent grading its own homework" state VISION §9 forbids. Entities without mocks are not gated (the loop generates them). `zfa tdd run` runs the same gate as a pre-start preflight, so the engine cannot bypass it.

**Independent Test**: with Login declared as a Key Entity and its mock present: delete the receipt → `zfa tdd run-engine <feature>` exits 1 with `blocked=Login` and the fix hint; `zfa tdd run <feature>` stops with `result=runner-error`. Restore the receipt (re-certify) → both proceed.

## Hard constraints

- Existing mock generation semantics unchanged beyond the new `--certify` / `--seed` flags (default output byte-identical to pre-1001).
- One PR for this spec; closes #1001.
- The sandbox runner is the Dart toolchain (`dart analyze` + `dart test` — package:test, the same engine `flutter test` wraps): the zuraffa root package is pure Dart and the repo's CI dart lane has no Flutter SDK (`.specify/memory/tdd-profile.md`), so `dart test` is the deterministic, CI-parity choice.
