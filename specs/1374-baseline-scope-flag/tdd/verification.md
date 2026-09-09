# TDD Verification — Spec 1374 — Verdict: PASS (2026-09-09)

- Test-first: red commit (`+0 -3`) precedes the fix commit.
- Suite: bug file `+3 All tests passed!` (slow tier); scoped pin
  (split 1000, #1309, realize-mock) `+30 All tests passed!`; analyze
  clean; format clean.
- Mutation sampling (executed): M1 — plumb dropped (the flag parsed but
  never reached the baseline block) → B1 red (killed). M2 — corpus write
  unguarded when scoped → the corpus cache must not gain a scoped
  snapshot; pinned by code inspection + the B1/B2 absence of the
  corpus-reuse line (documented limitation: the corpus-reuse path is
  silent in the fixture — no fingerprint — so the write-side guard is
  asserted structurally).
- Smells: none — slow tag for the real dart test children; reasons on
  every expect.
- AC coverage: AS-1→B1, AS-2→B2, AS-3→B3. All FRs traced.
