# Bug Assessment: external-service simulation adapters — Firebase Auth, Vendure, Market Fiyati, Google Shopping, AdMob, OpenTelemetry

- **Slug**: tdd-external-service-simulation
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/832
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Specs 008-012 (auth), 014/084 (Vendure), 042 (Market Fiyati), 017 (Google Shopping), 068 (AdMob), 065 (OtelReporting) depend on live externals. The TDD loop must run them GREEN deterministically without network. Today the loop has no simulation adapters — all external calls are real, flaky, and non-deterministic. https://github.com/arrrrny/zuraffa/issues/832

## Symptom

External-service-dependent specs (auth, Vendure, Market Fiyati, Google Shopping, AdMob, OtelReporting) cannot run GREEN in the TDD loop. Network calls are made — tests fail non-deterministically. No simulation adapters exist. The loop cannot prove isolation from real sockets.

## Reproduction

1. Run `zfa tdd run <feature>` for a spec depending on an external service (e.g. spec 008 auth)
2. Network call is made — test outcome non-deterministic (online/offline, API key valid/invalid)
3. No simulation adapter exists — the loop cannot certify GREEN
4. Fixtures are not committed under `specs/<feature>/tdd/fixtures/`

## Suspected Code Paths

- No `zfa simulate` command exists
- No adapter families (FirebaseAuth, Vendure, Rest, AdMob, Otel)
- No fixture infrastructure under `specs/<feature>/tdd/fixtures/`
- No network-isolation guard in TDD tests

## Root Cause Hypothesis

High confidence: the TDD pipeline was designed without VISION §9 simulation worlds. External services are called directly — no fake APIs, no latency injection, no fault injection, no golden contract. The loop cannot certify GREEN for any external-service-dependent spec.

## Proposed Remediation

**Preferred**: (1) `zfa simulate` adapter per service family per VISION §9: FirebaseAuthAdapter (scriptable auth states), VendureAdapter (GraphQL golden fixtures), RestAdapter (Market Fiyati/Google Shopping/JSON fixtures + latency/fault), AdMobAdapter (load/show/fail callbacks), OtelAdapter (capture-and-assert exporter spans). (2) Data sources take the adapter via DI in test bootstrap — same production interface, different certified binding. (3) Fixtures committed under `specs/<feature>/tdd/fixtures/` and hashed into cycle-log evidence. (4) Network-isolation guard: hosted TDD tests fail if they open a real socket, certifying the simulation.

**Alternatives** (optional):
- Real external calls with API keys — flaky, non-deterministic, VISION violation; not acceptable.

**Files likely to change**:
- New `zfa simulate` command
- Adapter families (FirebaseAuthAdapter, VendureAdapter, RestAdapter, AdMobAdapter, OtelAdapter)
- Fixture infrastructure (`specs/<feature>/tdd/fixtures/`)
- Network-isolation guard in TDD test bootstrap
- DI injection for adapters in data sources

**Tests to add or update**:
- Adapter families produce GREEN tests for all affected specs
- Fixtures committed and hashed into cycle-log
- Network-isolation guard: tests fail on real socket
- Cross-adapter compatibility (same interface, different binding)

## Risks & Considerations

- 16 specs affected — significant scope
- Adapter families must share the same production interface
- Fixture commitment must be automated, not manual
- Network-isolation guard must be sound (no false positives)
- Depends on #827 (namespacing) for correct paths

## Open Questions

- [NEEDS CLARIFICATION: What is the exact JSON schema for each adapter's fixtures?]
- [NEEDS CLARIFICATION: How does the network-isolation guard detect real sockets?]