# Bug Issue: [TDD-120] tdd corpus: drive all 120 specs in dependency order with resume + per-feature verify gate + gap ledger

- **Slug**: tdd-corpus-drive-all-specs
- **Fetched**: 2026-09-02
- **Issue**: 836
- **URL**: https://github.com/arrrrny/zuraffa/issues/836
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: Spec 051 defined `zfa tdd corpus` — exactly the command the 120-spec rebuild needs. It has never been exercised against a real corpus. The rewrite plan at zik_zak_zfa/rewrite-plan.md carries the dependency edges (F002→F001, F003→F002...).

Required (system fix):
1. `zfa tdd corpus --plan rewrite-plan.md` (or TUPEC inventory.json): topologically orders all 120 features by declared dependencies, runs `plan → run → verify` per feature, stops honestly on failure with resume token.
2. Provenance audit: every feature's green run references the spec hash — rebuild evidence binds to intent (drift = exit 3).
3. Gap ledger: corpus writes which FRs/ACs across the 120 specs lack behaviors (plan gaps) — the ledger IS the completeness proof for "100% TDD built".
4. Cross-feature composition ordering: acceptance behaviors composing unit subjects may only depend on features earlier in the topological order (needs #827 namespacing).
5. Full-corpus smoke in CI on a scaled-down fixture set (zuraffa repo) — regression-proof the driver itself.

## Comments

None.