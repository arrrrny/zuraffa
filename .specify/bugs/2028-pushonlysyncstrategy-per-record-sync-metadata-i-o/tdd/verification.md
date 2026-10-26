---
feature: bug-2028-pushonlysyncstrategy-per-record-sync-metadata-i-o
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: a9c148b8 + fix worktree (pre-commit) # base SHA + this session's tree
behaviors: 1
proven: 1
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 100 # scope: 3 deliberate mutants on the changed strategy file, hand-run (no mutation tool wired for these files — mutation-test.xml scopes feature-041 TDD-plugin files only)
mutants_survived: 0
suite: 51 passed, 0 failed (42 sync-plugin + 1 integration slow-lane + 8 repository-adjacent), plus 11/11 in the bug suite
---

# TDD Verification: Bug #2028 — PushOnlySyncStrategy per-record sync-metadata I/O

- **Verified**: 2026-10-27, this session, on
  `fix/2028-pushonlysyncstrategy-per-record-sync-metadata-i-o-makes-a-2k`
  @ base `a9c148b8` + the fix worktree (pre-commit)
- **Toolchain**: Dart 3.13.7 (stable) on linux_x64 (lock floor requires
  Dart ≥ 3.13.0; CI pins 3.13.3)
- **Engine detection** (`/speckit.tdd.verify` step 0): `zfa v7.2.0` runs, but
  no `.zfa.json` at repo root → `ZFA_MISSING` → the command's fallback
  LLM-guided audit was used. This file is the audit product, generated from
  the real runs in this session.

## Verdict: PASS

## 1. The bug suite (red → green, REAL runs in this session)

Subject: `test/plugins/sync/push_only_sync_strategy_test.dart` — new test
`bounds the box after pushing a backlog beyond the cap`: seeds a 2,025-record
pending backlog through `markPending` (the issue's exact shape), resets the
fake store's op counter, pushes via `syncPending()` with the default
`SyncConfig` (batchSize 50), and bounds the awaited metadata operations the
strategy issues (ceiling `2 * batchCount + 16`, floor `2 * batchCount`).

```
dart test -j 2 test/plugins/sync/push_only_sync_strategy_test.dart \
  --plain-name "bounds the box after pushing a backlog beyond the cap"
```

- **RED (pre-fix)**: the per-record implementation failed the ceiling:

```
00:00 +0 -1: PushOnlySyncStrategy bounds the box after pushing a backlog beyond the cap [E]
  Expected: a value less than or equal to <98>
    Actual: <10129>
     Which: is not a value less than or equal to <98>
  pushing 2025 records issued 10129 awaited metadata operations; expected <= 98 (batched writes + one snapshot, not per-record I/O)
```

  Fails for exactly the issue's stated root cause — four awaited reads and
  two awaited writes per record (2,025 × ~5 awaited calls + status scan),
  ~6,000+ box operations for one pass. The reproduction CONFIRMS the issue's
  root cause; no discrepancy to report.
- **GREEN (post-fix)**: `00:00 +11: All tests passed!` — the bound test plus
  every pre-existing behavior in the file.

Post-fix instrumented cost of one full 2,025-record push (evidence harness,
same counting fake): **84 awaited metadata operations** (1 status scan + 1
partition snapshot + 41 × 2 batched writes + 3 assertions' own reads), push
wall time 24 ms against the in-memory fake — from **10,129** awaited calls.
The pass no longer scales per record: it scales per batch.

## 2. Test-first evidence

| Behavior | Class  | Evidence                                                                                       |
| -------- | ------ | ---------------------------------------------------------------------------------------------- |
| B1: a 2k backlog push costs batch-bounded metadata I/O | PROVEN | Red command + verbatim output recorded above, observed BEFORE the source fix was applied in this session; test and source land in the same commit (per-cycle commit shape, rubric-sanctioned when the red is recorded) |

The change to the existing test file adds an op counter to the fake and the
new test only — **no existing assertion was weakened, renamed, skipped, or
removed** (checked against the rubric's pre-existing-test checklist; the fake
gains `putAll`/`getByKeys` overrides and counting increments, its assertions
are untouched).

## 3. Static analysis

```
dart analyze lib/src/plugins/sync/builders/push_only_sync_strategy.dart \
             lib/src/plugins/sync/builders/sync_metadata_store.dart \
             lib/src/plugins/sync/capabilities/simulate_sync_capability.dart \
             test/plugins/sync/bidirectional_sync_strategy_test.dart \
             test/plugins/sync/push_only_sync_strategy_test.dart
→ No issues found!
```

Full-project `dart analyze`: **271 issues with the fix, 271 with the fix
stashed (baseline)** — zero new issues. All 223 `error` and 10 `warning`
lines are confined to the vendored `packages/*` sub-packages (their own
package resolution is not part of the root lane; pre-existing). Nothing
under `lib/src/plugins/sync/` or the test paths.

## 4. Mutation results (deliberate mutants, hand-run, restore verified)

No mutation tool is wired for these files (`mutation-test.xml` scopes the
feature-041 TDD-plugin subjects), so the rubric's deliberate-mutant path was
used. Each mutant was applied to the working tree, the bound test was run,
and the tree was restored from the fix copy with a green re-run afterwards.

| Mutant                                                                  | Behavior | Survived | Judgment                                                        |
| ----------------------------------------------------------------------- | -------- | -------- | --------------------------------------------------------------- |
| M1: drop the batch's `syncing` `putAll` in `_syncBatch`                   | B1       | No       | Floor trips: 46 ops < 82 required — both batched writes are pinned |
| M2: drop the batch's `synced` `putAll` in `_syncBatch`                    | B1       | No       | Status assertion trips: record stays `syncing`, never `synced`   |
| M3: restore per-record partition reads (the pre-fix `_processKeys` shape) | B1       | No       | Ceiling trips: 10,129 ops > 98 — the recorded RED run itself      |

Also covered without a separate run: an empty/broken `getByKeys` snapshot
skips the metadata guard, so zero records reach `createRemote` — killed by
the suite's `createdRemote, hasLength(2025)` landed-records assertion.

Survivors inside the fixed behavior: **none**. Sample size: 3 applied
mutants + 1 argued-equivalence, on the single changed behavior.

## 5. Acceptance-criteria traceability (issue text = spec; no spec.md exists for a bug cycle)

| Criterion (from issue #2028)                                                                 | Tests | End to end |
| --------------------------------------------------------------------------------------------- | ----- | ---------- |
| Cost of pushing N records is proportional to N's batches, not N                               | bound test (ceiling + floor) | Yes (real strategy + fake box seam) |
| Batch status transitions written with one `Box.putAll` (syncing + synced)                     | bound test floor pins both per batch | Yes |
| Partition metadata from one snapshot instead of N `get` calls                                  | bound test ceiling (84 ≤ 98; 10,129 pre-fix) | Yes |
| No behavior change: every record lands, statuses correct                                      | bound test landed-records assertions + all 11 pre-existing push-only tests | Yes |

Untested criteria: none. Tests tracing to nothing: none.

## 6. Regression sweep (REAL runs in this session)

| Chunk | Result |
| ----- | ------ |
| `test/plugins/sync/` (42 tests: push_only, bidirectional, sync_builder, simulate capability, sync plugin) | `All tests passed!` (re-run green after the format cycle too) |
| `test/integration/sync_with_di_test.dart` (tagged `integration, slow` — run via `--preset=integration`) | `All tests passed!` |
| `test/plugins/repository/repository_engine_crud_shape_test.dart` | `All tests passed!` (3) |
| `test/plugins/repository/repository_trust_tier_test.dart` | `All tests passed!` (4) |
| `test/plugins/repository/repository_compile_test.dart` | `All tests passed!` (1) |

No new failures anywhere. One regression was caught and fixed DURING the
cycle: `_FakeBox` (the simulate capability's in-memory Hive-shaped box)
implements exactly the box members the store uses, so the new `toMap()`/
`putAll` calls surfaced as `NoSuchMethodError` in 4 simulate tests — the
fake gained those two members and the whole sync dir went green. That is
the intended seam-tracking contract of that fake, not a behavior change.

## 7. Formatting

```
dart format . → pre-existing drift only: tools/run_fast_suite.dart
  (dart_style adjacent-string indentation drift on master — unrelated file,
   reverted; this PR does not carry it)
dart format <the 5 changed files> → 0 changed (format-clean)
```

## 8. What was not audited

- Mutation testing was deliberate-mutant sampling (3 mutants + 1 argued
  equivalence), not a tool run: no mutation tool is scoped to these files.
- The `slow`/`e2e` heavy lanes beyond `sync_with_di_test.dart` were not run
  (repo guidance: avoid heavy presets on small disposable agents; the
  changed code paths are covered by the fast-tier suites above).
- `example/` needs a Flutter SDK (pre-existing, out of scope).
- Full-suite single-process run skipped per repo guidance (kernel cache
  growth on small disks); chunked neighbors cover the touched surface.

## 9. Environment notes (honest recording)

- `specify init --here` hangs in this sandbox (interactive/network); the
  repo ships `.specify/` committed and `specify extension list` shows
  `✓ TDD Extension (v1.1.2), Status: Enabled` — expectation met without
  re-init. `specify extension add tdd` 404s on the upstream release asset.
- `dart format .` on Dart 3.13.7 wants to reflow `tools/run_fast_suite.dart`
  (master drift, unrelated to this fix; reverted).
- Full-project analyze errors/warnings live in vendored `packages/*`
  sub-packages without their own resolved package configs (pre-existing).
