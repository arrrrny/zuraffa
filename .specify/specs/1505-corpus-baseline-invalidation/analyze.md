# Analyze: 1505-corpus-baseline-invalidation

- **Date**: 2026-09-13
- **Artifacts**: spec.md, plan.md, tasks.md, tdd/test-list.md (post-plan)

## Cross-artifact checks

1. **Caller drift**: `dependencyFingerprint()` has exactly ONE caller
   (`run_driver_core.dart:585`) plus `read()`/`write()` on the same class;
   the plan keeps the signature and return-null contract, so no caller
   edits are required — consistent with the hard constraint (fix only
   `corpus_baseline_cache.dart`). ✔
2. **SC ↔ task traceability**: SC-1→T001/T002/T006, SC-2→T003, SC-3→T007,
   SC-4→T004/T008, SC-5→(existing fixture test, unchanged), SC-6→T011.
   No orphan criteria, no orphan tests. ✔
3. **Exclusion consistency**: spec US-4's run-mutated set
   (progress.json, run.lock, receipts, cache file) matches plan's
   allow-list complement; specs/ planning artifacts and per-feature
   run-state.json are outside the fingerprint in both (they are
   run-mutated in real corpus lanes). ✔
4. **Fixture reality check**: TddFixture temp projects have no git repo →
   plan's rejection of git-HEAD hashing is sound; fake zfa steps write no
   test/lib files → T008 (reuse preserved) is expected green-by-design
   after T005; tasks.md already records that contingency. ✔
5. **Template compliance**: spec.md carries prioritized user stories with
   `**Type**` routing markers (issue #1186 contract); test-list derived
   under tdd/ per the TDD extension file placement. ✔

## Findings

No cross-artifact drift requiring fixes. One preventive note recorded:
T008's "may already pass" clause keeps the TDD cycle honest if the
economics guard is satisfied by design at implementation time.
