# Bug Issue: [TDD-120] Cycle-log evidence integrity: run-state, artifacts, and cycle-log must never disagree

- **Slug**: tdd-cycle-log-evidence-integrity
- **Fetched**: 2026-09-02
- **Issue**: 828
- **URL**: https://github.com/arrrrny/zuraffa/issues/828
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: Gates are non-negotiable. `zfa tdd refactor` correctly refuses when cycle-log lacks red/green evidence for a behavior. The BUG is that the system can arrive at that state at all: run-state says green/done while cycle-log has no matching evidence entries (observed after interrupted runs and mid-loop stops on specs 004/005/006).

Three stores (run-state.json, artifacts.json, cycle-log.md) are updated at different times by different steps. An interrupted run leaves them inconsistent; refactor then hard-stops the whole corpus.

Required (system fix):
1. Single transactional writer: every step (gen/verify-red/make/refactor) appends evidence AND updates state in one commit — write-ahead to a journal, then apply, then fsync both stores.
2. On resume, `zfa tdd run` RECONCILES: any behavior whose state claims green/done without complete red→green→refactor evidence in cycle-log is reset to the earliest incomplete step and re-driven. The agent never hand-edits run-state again.
3. Evidence schema versioned; tamper-evident (hash chain per behavior: red-hash → green-hash → refactor-hash).
4. `zfa tdd doctor` (or `zfa doctor --tdd`) reports drift between the three stores with `--> fix:` line.

## Comments

**arrrrny** (2026-09-02): "Part of epic #848 (Wave 1 — unblock the loop). Closing this without the epic context loses the dependency ordering."
