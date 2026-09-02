# Bug Issue: Persistence test harness — Hive CE temp-box lifecycle + corrupted-box recovery

- **Slug**: tdd-persistence-test-harness
- **Fetched**: 2026-09-03
- **Issue**: 833
- **URL**: https://github.com/arrrrny/zuraffa/issues/833
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Specs 005 (caching), 089 (offline mode), 091, 092 and all cached entities need
real Hive CE behavior under test: TTL expiry, box corruption, registrar
failures. Today the TDD loop has no persistence harness — no temp-box
lifecycle, no corruption drills, no registrar gate. TTL assertions use real
sleeps — the suite slows at 120-spec scale.

Required (system fix):

1. Test bootstrap rule: every Hive-touching test gets a fresh temp directory
   box set, torn down per test — generated into the test by `zfa tdd gen`
   when the plan marks the behavior persistence-kind.
2. Clock injection: TTL assertions use a zfa test clock (`advanceTime`) — no
   real sleeps in the suite.
3. Corruption drills: the adapter opens a pre-corrupted box fixture and
   asserts the recovery path (clear + re-fetch per spec edge cases).
4. Registrar gate: init-time registration failure surfaces as a
   deterministic red, not a runtime read crash (spec 005 US3-AC3).

## Comments

None.
