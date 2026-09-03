---
feature: 069-corpus-economics
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: 069-corpus-economics
updated_at: 069-corpus-economics
suite_baseline: green
---

# Test List: Corpus Economics (spec 069)

Baseline: `dart analyze lib test` clean for the change set (2 pre-existing
repo warnings, both flagged in verification.md). Fast tier via
`tools/run_tests_chunked.sh` — 69/69 chunks green. Focused folder
`test/plugins/tdd/corpus_economics/` — 47/47 in ~12s.

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| A1 | the 120-spec corpus full verify runs in minutes, not tens of minutes, on the same hardware class (frequency engineered: full gate kept at feature completion + nightly) | AC-1; #916 | acceptance | DONE | test/plugins/tdd/corpus_economics/corpus_economics_integration_test.dart::A1: the full lane drives every feature and writes the budget telemetry JSON verdict (end-to-end) |
| A2 | the per-PR corpus lane completes ≤ 10 min via sharding (deterministic round-robin, exact coverage, concurrent CI-matrix invocations) | AC-2; #916 | acceptance | DONE | test/plugins/tdd/corpus_economics/corpus_economics_integration_test.dart::A2: --shard i/n drives ONLY that shard's features + corpus_sharder_test.dart::A2: a 120-feature corpus splits into 12-per-shard across 10 shards |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/pass_registry_tracker.dart` (incremental verification, T001)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| T001 | the refactor re-proof is scoped to the covering tests of the pass-registry-changed files; one unattributable file falls back to the full suite; `--full-reproof` forces the feature-completion/nightly full gate | T001; FR-1 | unit | DONE | test/plugins/tdd/corpus_economics/incremental_verify_test.dart::T001: a changed registered subject scopes the re-proof to its covering test |

### `lib/src/plugins/tdd/commands/gen_command.dart` + `verify_red_command.dart` (batched lineage, T002)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| T002 | `zfa tdd gen --all` generates every pending row in ONE invocation; `zfa tdd verify-red --all` certifies every pending red through ONE whole-file runner invocation (N behaviors, 1 spawn); honest refusals stop the batch | T002; FR-2; #792; #785 | unit | DONE | test/plugins/tdd/corpus_economics/batch_gen_test.dart::T002: certifies every pending red through ONE whole-file invocation |

### `lib/src/plugins/tdd/services/corpus_sharder.dart` + `budget_telemetry.dart` (sharding + telemetry, T003)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| T003 | the corpus lane splits features across deterministic shards; the JSON verdicts carry budget telemetry (wall-clock per step, suite seconds, mutant count) | T003; FR-3 | unit | DONE | test/plugins/tdd/corpus_economics/corpus_sharder_test.dart::T003 + test/plugins/tdd/corpus_economics/budget_telemetry_test.dart::T003 |

### `lib/src/plugins/tdd/services/corpus_baseline_cache.dart` (corpus-wide cache, T004)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| T004 | the #741 suite baseline is reused corpus-wide under a dependency fingerprint; a dependency change invalidates it (correct, never stale); corrupt cache falls back to the live suite | T004; FR-4; #741 | unit | DONE | test/plugins/tdd/corpus_economics/baseline_cache_test.dart::T004: the SECOND feature's run reuses the corpus baseline |

### acceptance verification (T005)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| T005 | the machinery works end-to-end on a subset corpus: full lane + shard lanes + telemetry gate; the wall-clock budget is enforced from REAL measurements | T005; AC-1; AC-2 | unit | DONE | test/plugins/tdd/corpus_economics/corpus_economics_integration_test.dart::T005: the budget verdict is enforced from the telemetry |
