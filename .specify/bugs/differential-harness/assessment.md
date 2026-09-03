# Bug Assessment: Differential harness — fixture parity between mock and real adapters

- **Slug**: differential-harness
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/915
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> Part of #908. Required: (1) Fixture contract: one committed fixture set per adapter contract, consumed by BOTH the mock (source of responses) and the realize differential (expected outputs from real). (2) Schema-parity checker: mock fixture shape must equal real response shape (Zorphy types); drift = named verdict. (3) Fault-injection parity: the failure scenarios the mock rehearses (timeouts, 5xx, corrupted payloads) must be triggerable against real adapters in the integration lane. (4) Rollup: per-adapter parity score surfaced in corpus reports.
>
> Builds on the landed simulate adapters (fix 832, commit 2334d1b6).

## Symptom

There is no mechanism to verify that the mock adapter's fixture responses match the real adapter's actual response shapes. When a behavior transitions from MOCKED to REAL (the realization ladder), the real adapter may return data with different field names, types, or nesting — and the contract test will either fail silently (different shape) or pass dishonestly (mock was too shallow to catch the mismatch). No committed fixture set exists per adapter contract, and no schema-parity checker runs during realization.

## Reproduction

1. Use `zfa mock create` to generate a mock datasource for an entity with a known contract.
2. Write a behavior test that passes against the mock (MOCKED tier green).
3. Replace the mock with a real adapter (e.g., a REST API client).
4. Run the same contract test — it may pass or fail depending on whether the real API response shape coincidentally matches the mock fixture.
5. There is no automated check that the fixture shapes match — parity is manual and error-prone.

## Suspected Code Paths

- `lib/src/simulation/fixture_registry.dart:1-80` — `FixtureRegistry` manages SHA-256 hashing and manifest verification for committed fixtures under `specs/<feature>/tdd/fixtures/`; this is the existing fixture infrastructure
- `lib/src/simulation/simulation_world.dart:1-80` — `SimulationWorld` loads certified fixture sets and boots adapter families; currently supports auth, vendure, rest, admob, otel families
- `lib/src/simulation/simulation_adapters.dart` — the adapter implementations that consume fixtures
- `lib/src/plugins/tdd/services/differential_ref_runner.dart:1-80` — `DifferentialRefRunner` drives corpus entries against generator refs; this is where differential testing infrastructure lives but it tests generator behavior, not adapter parity
- `lib/src/simulation/certified_worlds.dart` — the certified world definitions that bind fixtures to adapter families
- `test/simulation/simulation_adapters_test.dart` — existing tests for the simulate adapters
- `test/simulation/simulation_world_test.dart` — existing tests for SimulationWorld

## Root Cause Hypothesis

**Medium confidence.** The simulation infrastructure (bug #832) was built for generator differential testing (comparing generator versions), not for adapter parity checking (comparing mock vs real response shapes). The fixture registry verifies fixture integrity (hash matching) but not schema compatibility. The gap is architectural: no component currently accepts a mock fixture set AND a real adapter's actual response and compares their shapes. This is a missing feature, not a regression — the differential harness was designed for a different differential axis (generator version, not adapter type).

## Proposed Remediation

**Preferred**:
1. **Fixture contract**: Define a per-adapter-contract fixture schema (JSON Schema or Zorphy type assertion) that both the mock adapter's responses and the real adapter's responses must conform to. Store committed fixtures under `specs/<feature>/tdd/fixtures/<adapter-contract>/` with `mock.json` and `real.json` (or auto-generated from the real adapter's first successful call).
2. **Schema-parity checker**: Add a `zfa tdd diff-check` (or extend `zfa tdd verify`) command that loads the mock fixture and real fixture for an adapter contract, compares their shapes using Zorphy type metadata, and reports any drift as a named verdict. Drift = exit 2 with the field-level difference.
3. **Fault-injection parity**: Extend the fixture system to include fault scenarios (timeouts, 5xx, corrupted payloads) that can be triggered against both mock and real adapters. The real adapter lane would need a network interception layer or a configurable fault-injection hook.
4. **Corpus rollup**: Surface per-adapter parity scores in corpus reports (the `corpus status` / `corpus audit` commands).

**Alternatives**:
- **Type-only parity**: Compare only the Zorphy types (field names + types), not actual values — simpler but misses value-level mismatches.
- **Contract-test approach**: Use generated interface contracts to verify that both adapters implement the same interface — already partially done by the datasource interface generator.

**Files likely to change**:
- `lib/src/simulation/fixture_registry.dart` — extend to support adapter-parity fixtures
- `lib/src/simulation/simulation_world.dart` — add parity-check method
- New: `lib/src/plugins/tdd/services/adapter_parity_checker.dart` — the parity checker
- `lib/src/plugins/tdd/commands/verify_command.dart` or new `diff-check` command
- `lib/src/plugins/tdd/commands/corpus_status_command.dart` — add parity scores
- `lib/src/plugins/tdd/commands/corpus_audit_command.dart` — add parity audit

**Tests to add or update**:
- Parity checker test: mock fixture matches real fixture shape → green
- Parity checker test: field mismatch detected → exit 2 with field-level report
- Fault-injection parity test: timeout scenario triggerable against both mock and real

## Risks & Considerations

- **Real adapter access**: Testing real adapters requires network access or a test double for the real backend — the integration lane must handle flaky networks and rate limits.
- **Fixture maintenance**: Committing real adapter response fixtures creates a maintenance burden as APIs evolve — fixtures may go stale.
- **Performance**: Running parity checks on every realization adds time to the MOCKED→REAL transition; may need to be opt-in or gated behind `--full` flag.
- **Zorphy type availability**: The parity checker depends on Zorphy type metadata being available for all adapter response types — not all adapters may expose this.

## Open Questions

- [NEEDS CLARIFICATION: Does the existing simulation infrastructure (bug #832, commit 2334d1b6) already include any shape comparison, or is it purely hash-based integrity verification?]
- [NEEDS CLARIFICATION: What are the "10 adapter families" planned for the realization ladder — and which ones already have committed fixtures?]
- [NEEDS CLARIFICATION: Should parity checking be a separate command (`zfa tdd diff-check`) or integrated into the existing `zfa tdd verify`?]
