---
feature: 069-corpus-economics
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: spec/069-corpus-economics working tree (branch spec/069-corpus-economics, pre-commit)
behaviors: 7
proven: 7
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 3/3 caught # deliberate-mutant sample; scope: pass_registry_tracker.dart, corpus_sharder.dart, budget_telemetry.dart
mutants_survived: 0
suite: fast tier chunked 69/69 chunks, 0 failures; focused corpus_economics folder 47/47, ~12s
---

# TDD Verification: Corpus Economics — all-120 verify in minutes (spec 069, closes #916)

**Verdict: PASS_WITH_GAPS.** Every behavior in the spec's task list has
a recorded red before its green (hash-chained cycle-log, real
transcripts), the full fast-tier suite is green chunked 69/69 with zero
failures, all three sampled deliberate mutants were caught (each
restored and the suite re-verified green), and no HIGH smell was found.
The evidence is weak in three specific places listed below — the
weightiest being that the 120-spec wall-clock acceptance numbers are a
derived projection from issue #916's measured Intel-Mac baselines plus
the spawn-count arithmetic this change removes, not a fresh end-to-end
measurement of a real 120-spec corpus (this session ran on a cloud
Linux agent and the repo's current spec corpus is 73 directories).

**Engine path disclosure (Step 0):** `/speckit.tdd.verify` ran its
engine detection — `zfa --version` succeeds (v6.1.0) but `.zfa.json`
does not exist in the repo root, so the audit took the documented
`ZFA_MISSING` fallback path (the original LLM-guided rubric audit),
exactly as the 067 and 068 verifications did. No `zfa tdd verify`
mutation gate ran; the mutation evidence below is deliberate-mutant
sampling per the profile's documented fallback.

## Test-first evidence

The cycle log at `specs/069-corpus-economics/tdd/cycle-log.md` carries
9 schema-1 hash-chained entries (red→green per behavior, T005 green
straight — its machinery landed green through T003/T004's cycles). Red
entries record the REAL failing transcript (compile errors naming the
missing modules — `No such file or directory` / `Undefined name`) with
the exact command; green entries record the same command's passing
output. Every chain link verifies against the recomputed payload.

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| T001 incremental verification (tracker + scoped re-proof) | PROVEN | cycle-log red `dcb75232` (module missing, exit 1) → green `37f3b21a`; 9/9 tests incl. the scoped/fallback/`--full-reproof` contract |
| T002 batched gen/verify-red | PROVEN | cycle-log red `cc27ee17` (`--all` unknown, exit 1) → green `f803f364`; 8/8 tests incl. the one-invocation-for-N-behaviors spawn count |
| T003 sharding + budget telemetry | PROVEN | cycle-log red `636b8159` (services missing, exit 1) → green `c57b092a`; 18/18 tests (10 sharder + 8 telemetry) |
| T004 corpus-wide baseline cache | PROVEN | cycle-log red `8ef5bc90` (service missing, exit 1) → green `95082384`; 7/7 tests incl. fingerprint invalidation + corrupt fallback |
| T005 acceptance machinery | PROVEN | cycle-log green `f6808ff2`; 5/5 integration tests: full lane telemetry, deterministic exact-coverage shards, lane-scoped completion, telemetry budget gate |
| A1 full-verify frequency engineering | PROVEN (machinery) / PROJECTED (wall clock) | refactor re-proof scoped + full gate at completion/nightly; per-feature suite spawn removed (T004); see the acceptance math below |
| A2 per-PR lane ≤ 10 min via sharding | PROVEN (machinery) / PROJECTED (wall clock) | `--shard i/n` + CI-matrix concurrency + telemetry gate; 120/10 = 12 features per lane |

Weakened-existing-test check: `git diff master -- test/` touches five
pre-existing files — four carry `dart format .` re-wraps required by
the format gate (dart_style drift on master: `subject_signature_deriver.dart`,
`test_list_reader.dart`, `bug_937_reader_sections_test.dart`,
`wire_command_test.dart`), and `tdd_fixture.dart` gains an OPTIONAL
`fileTemplate` parameter (additive; every existing caller compiles and
the whole pre-existing corpus suite passes unchanged). Zero assertions
removed, loosened, or renamed.

## Mutation evidence (deliberate-mutant sample, 3/3 caught)

| Mutant | Change | Caught by |
| ------ | ------ | --------- |
| M1 | `PassRegistryTracker.coveringTestsFor`: `if (test == null) continue` — silently skip the unattributable file instead of poisoning the set (the silent-narrowing bug T001 exists to kill) | incremental_verify_test "one unattributable file poisons the whole set" (exit 1) |
| M2 | `CorpusSharder.shard`: `shards[(i + 1) % shardCount]` — off-by-one round-robin | corpus_sharder_test (2 failures: exact assignment + coverage) |
| M3 | `BudgetTelemetry.parseMutantCounts`: fabricate zeros for an incomplete machine line | budget_telemetry_test "a missing machine line yields null" |

Each mutant was applied, the focused suite failed naming it, the file
was restored byte-for-byte, and the full corpus_economics folder
re-verified green (47/47) after the restore.

## Suite evidence

- Fast tier, chunked (`tools/run_tests_chunked.sh` + the four
  tail chunks the session's 10-minute command window split off):
  **69/69 chunks, 0 failures.**
- Focused change set: `dart test test/plugins/tdd/corpus_economics/`
  **47/47 passed** in ~12s.
- `dart analyze lib test`: no issues in the change set. Two pre-existing
  repo warnings remain (`unused_import` in `test/commands/entity_help_test.dart`,
  flagged by 068's verification too; the analyzer's 23 errors are all in
  the never-committed-generated `examples/todo_tdd/` + `website/`
  packages — present on master, untouched by this change).
- `dart format .`: **zero remaining diffs** (format gate clean).
- Pre-existing unrelated failures flagged, verified failing on MASTER
  with this branch's changes stashed (not caused by this change):
  `gen_command_test.dart` "registry composite third segment is the PURE
  description" (bug #871 regression) and `run_command_test.dart`
  "bug #691: verify-red unexpected-green skips to make" — both
  slow-tier, both out of scope here.

## Acceptance math (the two #916 targets)

Measured inputs (issue #916, Intel Mac, live): full suite 2m21s;
`zfa build` 1m08s; one refactor = 2 suite runs + build = 9m30s; default
10m step timeout knife-edge. What this change removes, per feature in
the corpus lane:

| Cost component | Before 069 | After 069 |
| -------------- | ---------- | --------- |
| Refactor re-proof | 2nd full suite run (2m21s) + overhead | scoped covering tests (seconds); full gate preserved at completion/nightly |
| Verify-red spawns | one `dart test` spawn per behavior | ONE whole-file invocation per feature (T002 batch) |
| Suite baseline capture | once per feature (per `tdd run`) | once per dependency state, corpus-wide (T004) |
| Per-PR lane | sequential, all features | 120/10 = 12 features per shard lane, lanes concurrent (T003) |

- **A1 (120-spec full verify ≤ 30 min):** the dominant per-feature cost
  collapses from "2 full-suite runs + build per refactor" (9m30s) to
  "build + one full-suite preflight + scoped re-proof" (~3m30–4m by the
  measured components), and the per-feature baseline capture is removed
  entirely. The full gate still runs per feature completion (the verify
  step) and nightly — frequency engineered, not removed. **Verdict:
  machinery PROVED by tests; the 30-minute wall-clock is a PROJECTION
  from #916's measured components** (this session's hardware is a cloud
  agent, and the repo's corpus is 73 spec dirs, not 120 ready features).
- **A2 (per-PR lane ≤ 10 min via sharding):** 12 features per shard
  lane, driven concurrently; the telemetry verdict
  (`corpus.budget.v1`, `wall_clock_ms`, `suite_seconds`, mutant counts)
  is the CI-enforceable gate against the real number — the integration
  test proves a lane completes and writes a REAL wall-clock the CI lane
  gates on. **Verdict: machinery + gate PROVED; the 10-minute number on
  Intel Mac class is the same projection.**

## Findings (the gaps behind PASS_WITH_GAPS)

1. **Wall-clock acceptance is projected, not re-measured** on a real
   120-spec corpus on Intel-Mac-class hardware (cloud agent + 73-spec
   repo). The telemetry gate exists precisely so the next full-corpus
   run replaces this projection with a measurement — until then, weight
   A1/A2 as LIKELY rather than measured.
2. **Same-session authorship** (Hard Rule disclosure): this audit was
   produced by the same session that wrote the tests. Files were
   re-read in full and every mutant citation was re-verified against
   the actual transcript, but the audit is not independent.
3. **Mutation evidence is a 3-mutant sample** (the repo profile wires no
   mutation tool in CI; deliberate-mutant sampling per the rubric), and
   the sampled scope is the three new pure services — the command-level
   wiring (gen/verify-red/refactor/corpus-run) is covered by behavioral
   tests, not mutants.

## Remediation tasks (appended to tasks.md)

- T007: run the full corpus lane on a real ≥120-spec corpus on
  Intel-Mac-class hardware, gate on `budget-telemetry.json`
  `wall_clock_ms` (≤ 30 min full / ≤ 10 min shard), and replace the
  projection above with the measured numbers.
