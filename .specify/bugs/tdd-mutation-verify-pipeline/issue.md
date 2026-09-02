# Bug Issue: [TDD-120] Mutation verify pipeline: fix preflight semantics + make it runnable at corpus scale

- **Slug**: tdd-mutation-verify-pipeline
- **Fetched**: 2026-09-02
- **Issue**: 837
- **URL**: https://github.com/arrrrny/zuraffa/issues/837
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: `zfa tdd verify` exits 64 with gate=preflight_red on a green suite — observed on every completed feature. The gate reads backwards for a post-green audit, and mutation never actually ran (`mutation_was_run: false`) on our runs.

Required (system fix — keep the audit strict, fix the machinery):
1. Define gates precisely: verify runs AFTER green; preflight asserts suite GREEN + evidence complete (red+green present per behavior). Red suite at verify time = hard fail (correct, keep).
2. Mutation runs must execute (`mutation_was_run: true`) with bounded wall-clock: mutation_test scoped to the feature's subjects only (namespaced per #827), killed/survived/timed_out tallied, threshold gate from .zfa.json (default strict).
3. Survived mutants = exit 1 with per-mutant report + `--> fix:` pointer to the weak test.
4. Restoration proof extended: verify artifacts include spec-hash + subject-hash binding.

## Comments

None.
