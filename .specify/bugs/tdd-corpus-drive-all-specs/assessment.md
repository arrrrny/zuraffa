# Bug Assessment: tdd corpus — drive all 120 specs in dependency order with resume + per-feature verify gate + gap ledger

- **Slug**: tdd-corpus-drive-all-specs
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/836
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Spec 051 defined `zfa tdd corpus` — the command the 120-spec rebuild needs. It has never been exercised against a real corpus. The 120-spec corpus driver cannot topologically order features, run per-feature verify gates, or write a gap ledger. Without this, "100% TDD built" has no mechanical proof. https://github.com/arrrrny/zuraffa/issues/836

## Symptom

The `zfa tdd corpus` command does not exist or cannot topologically order 120 features. No per-feature verify gate exists. No gap ledger documents which FRs/ACs lack behaviors. The 100% TDD claim has no completeness proof.

## Reproduction

1. Attempt to run `zfa tdd corpus` — command not found or cannot order features
2. No gap ledger exists documenting missing behaviors
3. Corpus cannot prove "100% TDD built"

## Suspected Code Paths

- No `zfa tdd corpus` command
- No topological ordering logic for 120 features
- No per-feature verify gate infrastructure
- No gap ledger generation

## Root Cause Hypothesis

High confidence: the TDD pipeline lacks a corpus-level driver. The `zfa tdd corpus` command was never implemented, and the 120-spec rebuild plan has no mechanical way to order features, run verify gates, or document gaps.

## Proposed Remediation

**Preferred**: (1) `zfa tdd corpus --plan rewrite-plan.md` (or TUPEC inventory.json): topologically orders all 120 features by declared dependencies, runs `plan → run → verify` per feature, stops honestly on failure with resume token. (2) Provenance audit: every feature's green run references the spec hash — rebuild evidence binds to intent (drift = exit 3). (3) Gap ledger: corpus writes which FRs/ACs across the 120 specs lack behaviors (plan gaps) — the ledger IS the completeness proof for "100% TDD built". (4) Cross-feature composition ordering: acceptance behaviors composing unit subjects may only depend on features earlier in the topological order (needs #827 namespacing). (5) Full-corpus smoke in CI on a scaled-down fixture set (zuraffa repo) — regression-proof the driver itself.

**Alternatives** (optional):
- Manual corpus driving — doesn't scale; not a system fix.

**Files likely to change**:
- New `zfa tdd corpus` command
- Topological ordering logic
- Per-feature verify gate
- Gap ledger generation
- Cross-feature composition ordering

**Tests to add or update**:
- Corpus topologically orders 120 features correctly
- Per-feature verify gate passes on green suites
- Gap ledger documents all missing behaviors
- Corpus CI smoke test passes on scaled fixture set

## Risks & Considerations

- All 120 specs affected — this is the conductor
- Topological ordering must respect declared dependency edges
- Per-feature verify gate must not slow the normal path
- Gap ledger must be accurate and machine-parseable
- Cross-feature composition depends on #827 (namespacing)
- Full-corpus CI must not be flaky

## Open Questions

- [NEEDS CLARIFICATION: What is the exact format of the TUPEC inventory.json?]
- [NEEDS CLARIFICATION: How does the resume token work across feature boundaries?]