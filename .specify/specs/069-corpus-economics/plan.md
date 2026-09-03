# Plan: 894-corpus-economics

- **Spec ID**: 894-corpus-economics
- **Created**: 2026-09-03

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CORPUS VERIFY PIPELINE                   │
├─────────────────────────────────────────────────────────────┤
│  1. INCREMENTAL VERIFY                                      │
│     - Track pass-registry-changed files                     │
│     - Scope refactor re-proof to changed files              │
│     - Full-suite proof on feature completion + nightly      │
│                                                             │
│  2. BATCHED GEN/VERIFY-RED                                  │
│     - zfa tdd gen --all (batch generation)                  │
│     - Reduce per-behavior dart test spawns                  │
│                                                             │
│  3. SHARDING + CONCURRENCY                                  │
│     - Corpus lane splits across shards                       │
│     - Budget telemetry in JSON verdicts                     │
│     - Per-shard telemetry: wall-clock, suite secs, mutants  │
│                                                             │
│  4. BASELINE CACHE REUSE                                    │
│     - Extend #741 cache machinery corpus-wide               │
│     - Reuse build artifacts across features                 │
└─────────────────────────────────────────────────────────────┘
```

## Phases

### Phase 1: Incremental verification
- Implement pass-registry change tracking
- Scope refactor re-proof to changed files only
- Full-suite proof runs on feature completion + nightly
- Full gate still exists (just frequency engineered)

### Phase 2: Batched gen/verify-red
- Implement `zfa tdd gen --all` for batch generation
- Reduce per-behavior `dart test` spawns
- Pipeline batches through fewer test invocations

### Phase 3: Sharding + concurrency
- Corpus lane splits features across shards
- Budget telemetry in JSON verdicts (wall-clock per step, suite seconds, mutant count)
- Target: per-PR corpus lane ≤ 10 min via sharding

### Phase 4: Baseline cache reuse
- Extend #741 baseline cache machinery corpus-wide
- Reuse build artifacts across features
- Cache invalidation on dependency changes

### Phase 5: Acceptance verification
- Measure 120-spec corpus full verify on Intel Mac class
- Verify ≤ 30 min full verify
- Verify ≤ 10 min per-PR sharded lane

## Files likely to change

- `lib/src/plugins/tdd/commands/verify_command.dart` — incremental verify logic
- `lib/src/plugins/tdd/commands/gen_command.dart` — batch gen `--all` flag
- `lib/src/plugins/tdd/services/corpus_sharder.dart` (new) — sharding + concurrency
- `lib/src/plugins/tdd/services/budget_telemetry.dart` (new) — wall-clock, suite secs, mutants
- `lib/src/plugins/tdd/services/baseline_cache.dart` (extends #741) — corpus-wide cache
- `lib/src/plugins/tdd/services/pass_registry_tracker.dart` (new) — changed files tracking

## Tests

- `incremental_verify_test.dart` — refactor scoped to changed files
- `batch_gen_test.dart` — `gen --all` reduces test spawns
- `corpus_sharder_test.dart` — features distributed across shards
- `budget_telemetry_test.dart` — JSON verdicts contain telemetry
- `baseline_cache_test.dart` — cache reuse across features
- `corpus_economics_integration_test.dart` — 120-spec ≤ 30 min (smoke on subset)

## Risks

- Incremental verify must not miss cross-feature regressions
- Sharding must produce deterministic results
- Baseline cache invalidation must be correct (no stale artifacts)
- Telemetry overhead must not negate time savings
- Concurrency on single hardware class may need tuning

## Measured baselines (from issue #916)

| Operation | Time (Intel Mac, 4 features / 76 tests) |
|-----------|-----------------------------------------|
| zfa build | 1m08s |
| Full suite | 2m21s |
| ONE refactor (2 suite runs + build) | 9m30s |
| Default 10m step timeout | knife edge (killed at 10m00s) |

## Acceptance targets

| Metric | Target |
|--------|--------|
| 120-spec full verify | ≤ 30 min |
| Per-PR corpus lane | ≤ 10 min (via sharding) |