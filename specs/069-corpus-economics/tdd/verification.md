---
feature: 069-corpus-economics (issue #916 — corpus economics: all-120 verify in minutes)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 79bc566c # working tree HEAD of spec/069-corpus-economics, this session's real runs
behaviors: 51 # tests across the seven 069 suites
proven: 13 # red-first (test compiled/ran RED before the implementation existed, recorded in-session)
likely: 38 # same-session green-first or red-via-absence (flag unknown -> usage failure)
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 6 # 4 system fixes (spec Required) + 2 acceptance targets
criteria_covered: 6
mutation_score: 62/64 detected (96.9%) # real mutation_test run, scoped config committed beside this report
mutants_survived: 2 # both equivalent mutants (documented below)
suite: fast tier 70/70 chunks, 0 failed (tools/run_tests_chunked.sh chunk ranges, per-chunk kernel clears); 069 suites 51/51 green under --preset=all in this session; 3 pre-existing failures flagged as environmental (verified failing on pristine master)
---

# TDD Verification: 069-corpus-economics — all-120 verify in minutes (issue #916)

**Verdict: PASS_WITH_GAPS.** All four system fixes of the spec's
Required list are implemented and proven through the real CLI
(incremental verification, batched gen/verify-red, sharding +
concurrency + budget telemetry, corpus-wide baseline cache reuse), the
fast tier is green across all 70 chunks, the 51 069 tests pass, and a
REAL `mutation_test` run on the pure services kills 62 of 64 mutants.
The gaps that keep this from `PASS`: (1) the acceptance targets are
expressed on "Intel Mac class hardware" — this audit ran on a cloud
Linux agent, so the ≤ 30 min / ≤ 10 min wall-clock targets are proven
by the lane arithmetic over the issue-916 measured baselines plus
smoke runs, not by a literal 120-spec measurement on the named
hardware class; (2) 38 of 51 tests were written after (or alongside)
their implementations in the same session — red-first is PROVEN only
for T001/T002's 13 tests; (3) 2 of 64 sampled mutants survived and are
assessed as equivalent mutants (below); (4) the audit was run by the
same session that wrote the tests.

## Audit independence disclosure

The same session authored the code and ran this audit (the session is
the only driver available on this agent). Mitigations: every claim
below cites a command that was actually executed in this session and
is re-runnable from the committed branch; the mutation audit used the
real `mutation_test` tool (not hand-picked assertions); and three
pre-existing failures were re-verified against pristine `master` via
`git stash` before being attributed to the environment rather than
this change set.

## What was verified, and how (all from THIS session's real runs)

### Required 1 — Incremental verification (T001)

`zfa tdd refactor` re-proof is scoped by the pass registry
(`specs/<f>/tdd/pass-registry.json`): registered-file checksums + the
full `test/`+`lib/` tree fingerprint + the last-full-proof stamp.
Proven by `test/plugins/tdd/incremental_verify_test.dart` (7 tests,
**red-first**: the suite failed to compile against the absent
`PassRegistryTracker` before the service existed):

- T001.1 first proof is FULL and commits the registry;
- T001.2 a changed subject re-proves SCOPED to the covering test only
  (the spy argv carries `test/a_001_test.dart`, never B's);
- T001.3 an expired nightly window escalates to FULL and refreshes
  the stamp;
- T001.4 zero delta SKIPS the re-proof spawn (2 suite runs per
  refactor halved to 1 — the issue-916 knife-edge directly addressed);
- T001.5 unregistered file changes escalate to FULL (honest scope);
- T001.6 `--reproof full` forces; T001.7 the tracker unit contract.

### Required 2 — Batched gen/verify-red (T002)

`zfa tdd gen --all` + `zfa tdd verify-red --all` (**red-first**: 6
tests failed before the flags existed). Proven by
`test/plugins/tdd/batch_gen_test.dart`:

- one `gen --all` invocation materializes every planned pair;
- idempotent re-runs skip registered behaviors (progressed subjects
  never clobbered);
- the batch red verification spawns ONE suite invocation (spy log:
  1 line) where the per-behavior path spawns once per behavior
  (3 lines) — the spawn-count proof issues #792/#785 asked for;
- per-behavior honesty preserved: `BatchTranscript` segments the
  package:test transcript per file, each behavior classified
  independently; a passing behavior is `unexpected-green` and fails
  the batch with NO evidence written for it.

### Required 3 — Sharding + concurrency + budget telemetry (T003)

`--shard <i>/<k>` (deterministic round-robin, CI matrix form),
`--concurrency <n>` (bounded worker pool; STOP-ON-ROADBLOCK holds:
no new lanes start, in-flight lanes drain), and the verdict JSON
`.zfa/corpus/verdict.json` carrying measured
`wall_clock_ms` per step + total, `suite_seconds`, `mutant_count`
(parsed from verify's killed/survived/timed_out). Proven by
`corpus_sharder_test.dart` (13), `budget_telemetry_test.dart` (6),
and `commands/corpus_sharding_test.dart` (9: lane scoping, matrix
union covers every feature exactly once, interleave proof via a
sleeping fake, roadblock-under-concurrency, telemetry axes in the
verdict, mutant counting incl. a failing verify's counters).

### Required 4 — Baseline cache reuse corpus-wide (T004)

`CorpusBaselineCache` at `.zfa/corpus/run-baseline.json`: the exact
#741 payload plus a dependency fingerprint (pubspec.yaml +
pubspec.lock + .dart_tool/package_config.json) and a suite
fingerprint. The run driver consults it FIRST — a cross-feature hit
reuses the baseline with ZERO suite spawns; a dependency change since
capture invalidates it (honest miss). Proven by
`baseline_cache_test.dart` (6, incl. the invalidation matrix) and the
existing #741 suite stays green (7/7).

### Acceptance targets (T005)

- 120-spec full verify ≤ 30 min, per-PR lane ≤ 10 min via sharding:
  proven by the lane arithmetic over the issue-916 measured
  per-feature cost (`corpus_economics_integration_test.dart`):
  30 round-robin lanes × ≤ 4 features × 2.5 min ≤ 10 min/lane; the
  lane union IS the corpus (sharder proof), max−min lane size ≤ 1;
  plus the end-to-end smoke (gen --all → verify-red --all → sharded
  lanes, one spawn for 6 behaviors, second refactor re-proof skipped,
  verdict budgets present). GAP: not measured on literal Intel Mac
  class hardware — see the verdict paragraph.

## Mutation evidence (REAL tool run, not a spot check)

`dart run mutation_test` scoped to the two pure services
(config + report committed beside this file:
`tdd/mutation-test.xml`, `tdd/mutation-report.md`):

| Round | Detected | Undetected | Rating | Remediation |
| ----- | -------- | ---------- | ------ | ----------- |
| 1     | 50/64 (78.1%) | 14 | C | — |
| 2     | 56/64 (87.5%) | 8 | B | boundary + validation kills |
| 3     | 62/64 (96.9%) | 2 | B | index-0 / index>count lane contract, full message contracts |

The 2 survivors (corpus_sharder.dart line 108, `minutesPerFeature <= 0`
boundary: `== 0` and `< 0` mutants) are EQUIVALENT mutants: the
downstream `math.max(1, …)` / `math.min(featureCount, …)` clamps make
the three guard variants indistinguishable through the public API
(covered by tests at 0 and negative inputs that pin the one-lane
floor). Additionally, 4 hand-applied deliberate mutants on the
integration surfaces (unowned-escalation removal, lane off-by-one,
mutant accumulation drop, transcript `[E]` strip) were each killed by
their focused suites in this session (T001.5, corpus_sharder_test,
budget_telemetry_test, batch_gen T002.2 respectively).

## Suite evidence (this session's real runs)

- **Fast tier:** all 70 chunks of the chunked runner's chunk list,
  0 failed chunks (executed as `tools/run_chunks_range.sh` ranges
  1-12, 13-26, 27-40, 41-54, 55-70 — the same list
  `tools/run_tests_chunked.sh` emits; per-chunk kernel-cache clears
  applied; the two pure 069 unit suites run in this lane and pass
  post-strengthening).
- **069 suites:** 51/51 green under `--preset=all` (the exact
  invocation is recorded above in this file's generation session).
- **Existing TDD suites re-run:** refactor_command (14/14),
  bug_922 (9/9), corpus_run_command (23/23), corpus_run_plan (8/8),
  corpus_status + corpus_step_runner + sharding (40/40), gen_command
  (17/18), run_command (39/40), run_baseline_cache (7/7).
- **Pre-existing failures, verified on pristine master (not this
  change set):** `SC-012.A1/A9` (build-pass entrypoint resolves to
  the dart-test kernel when `--zfa-bin` is not pinned — environment),
  `gen_command_test` bug #871 registry-spacing assertion, and
  `run_command_test` bug #691. Each was re-run under `git stash -u`
  on this agent and failed identically WITHOUT the 069 changes.

## Test-first ordering evidence

PROVEN (red observed before implementation, in-session):
T001's 7 tests (compile-red against the absent service), T002's 6
tests (behavior-red: `--all` unknown flag → usage failures). LIKELY:
T003-T005's 38 tests were authored alongside/after their
implementations in the same session (green-first); their strength is
compensated by the real mutation round above and the CLI-level
smokes, but the ordering is honestly recorded as LIKELY, not PROVEN.

## Gaps and remediation tasks

1. **Hardware-class acceptance measurement** — the ≤ 30 min / ≤ 10 min
   targets are proven by lane arithmetic + smoke, not a literal
   120-spec run on Intel Mac class hardware (unavailable on this
   agent). Remediation: one follow-up measurement run on the target
   hardware class recording `verdict.json` budgets.
2. **Ordering evidence for T003-T005** — LIKELY, not PROVEN (same
   session authored code and tests). Mitigated by the real mutation
   audit and the re-runnable commands above.
3. **Equivalent mutants (2/64)** — no action (mathematically
   equivalent; documented).
4. **`mutation-test.xml` scope** — the scoped config covers the two
   pure services; the command-layer surfaces (corpus_run_command,
   verify_red batch, refactor scope wiring) are covered by the 4
   hand-applied deliberate mutants + the CLI suites, not the tool.
   Remediation candidate: extend the scoped config once a fast-lane
   home for the slow-tagged 069 suites exists.
