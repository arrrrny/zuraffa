# TDD Verification — Spec 0973 (repository A+ upgrade)

- **Feature:** `0973-repository-a-plus-upgrade`
- **Generated:** FRESH from the actual run in this session (2026-09-05, UTC+8) —
  not a copy of a prior verification.
- **Command path:** `/speckit.tdd.verify` → Step 0 engine detection →
  `zfa --version` OK, but **no `.zfa.json`** at repo root → **ZFA_MISSING** →
  **fallback LLM-guided audit** (test-first evidence, red evidence, test-smell
  rubric, mutation testing on changed files, acceptance coverage).

## Verdict: **PASSED** (gate green, 3/3 mutants killed)

| Gate | Result |
|------|--------|
| Preflight (suite green before audit) | ✅ `tools/run_tests_chunked.sh` → `OK: all chunks passed.` (full fast suite, chunked; evidence: `tdd/chunked-suite-T005.log`) |
| Test-first evidence | ✅ red logs committed before implementations |
| Red-phase evidence | ✅ T001 compile-fail RED, T002 integration RED (+3 −8) |
| Test-smell rubric | ✅ no sleeps/order deps; deterministic snapshots; isolated temp dirs with teardown |
| Mutation testing (changed files) | ✅ 3/3 mutants killed (M3 required test strengthening — remediation applied and re-run) |
| Acceptance-criteria coverage | ✅ all four acceptance bullets map to passing tests |
| `dart analyze` (spec-0973 code) | ✅ No issues found (repo-wide findings pre-existing: `examples/` subpackage, `test/tdd` infos — untouched by this branch) |
| `dart format` | ✅ zero diffs (`Formatted 1849 files (0 changed)`) |

## 1. Test-first evidence (git history)

Commits on `spec/0973-repository-a-plus-upgrade`, in order:

1. `e368446a` feat(0973): generation-time repository interface-impl conformance gate
   — preceded by `tdd/red-T001.log` (compile-fail: `RepositoryConformanceException`
   isn't a type — checker did not exist when the test was written and run).
2. `0d4be4dd` feat(0973): repository contract manifest + guard/proof integration
   — preceded by `tdd/red-T002.log` (test compiled against the new store/extractor
   unit surface, but ALL integration assertions failed: +3 −8 — generation wrote no
   manifest, guard consumed nothing, proof check had no manifest findings).
3. `60385bc2` feat(0973): --explain / --json resolved emission plan
   — preceded by `tdd/red-T003.log` (compile-fail: `RepositoryEmissionPlanner` did
   not exist).
4. `6ab994de` test(0973): variant content tests (simple/synced/append)
5. `75aa712e` refactor(0973): analyze-clean, format-clean, chunked suite green
6. `1edc6bb7` test(0973): strengthen guard fallback tests to kill mutation M3

## 2. Red-phase evidence (cycle log)

- **T001 (red → green):** `tdd/red-T001.log` — loading the test failed
  (`RepositoryConformanceChecker isn't a type`). After implementing the checker +
  wiring the gate + fixing the pre-existing `syncPending`/`pullRemote` missing-
  `@override` drift: 8/8 green (`tdd/green-T001.log`).
- **T002 (red → green):** `tdd/red-T002.log` — `+3 -8`: the 3 unit-level
  extractor/hash tests passed, all 8 integration tests failed
  (`No such file: .zfa/receipts/repository-product.json`). After wiring the plugin,
  guard and proof checker: 11/11 green (`tdd/green-T002.log`).
- **T003 (red → green):** `tdd/red-T003.log` — compile-fail. After the planner +
  make-command surface: 6/6 green (`tdd/green-T003.log`).
- **T004 (green):** 3/3 variant content suites pass (`tdd/green-T004.log`).
- **T005 (verify):** `dart analyze` scoped → 0 issues; `dart format` → 0 diffs;
  full chunked suite → `OK: all chunks passed.`

## 3. Test-smell rubric

- No `print`-based assertions; content asserted via AST-parsed or string content
  with normalization where whitespace varies.
- No sleeps, no inter-test ordering, no shared mutable fixtures — every test
  builds its own `Directory.systemTemp` workspace and tears it down.
- Snapshots are fully deterministic (output-relative POSIX paths, no timestamps,
  fixed key order) — the T003 snapshot golden is inline and stable.
- The deliberate-mismatch test exercises the REAL plugin path (unknown `--methods`
  verb → impl-side orphaned `@override`), not a mocked checker.

## 4. Mutation testing on changed files (real runs, this session)

| Mutant | Mutation | Target test | Result |
|--------|----------|-------------|--------|
| M1 | remove `@override` from generated `syncPending` | `repository_conformance_test.dart` (synced pair conforms) | **KILLED** — gate reports mismatch, test fails |
| M2 | `hashOfMethods` returns constant `deadbeef` | `repository_contract_manifest_test.dart` | **KILLED** — hash stability + integrity tests fail |
| M3 | guard parse-fallback returns methods unfiltered | `repository_contract_manifest_test.dart` | initially **SURVIVED** → tests strengthened (`1edc6bb7`) → **KILLED** (+9 −2 with mutant, +11 green clean) |

Remediation for the surviving mutant was applied within this verification pass
(strengthened the two fallback tests with a ghost-method assertion) and re-run —
the remediation loop closed with 0 surviving mutants.

## 5. Acceptance-criteria coverage

| Acceptance (issue #973) | Evidence |
|---|---|
| Deliberate mismatch fails at generation time with `--> fix:` — tested | `repository_conformance_test.dart`: “a deliberate mismatch fails at generation time with --> fix:” (unknown verb → impl-side orphaned override → exception naming `purgeAll` + both sides; CLI catch-all exits 1) |
| Fresh generation writes the contract manifest; `zfa proof check` green, red on hand-edit | `repository_contract_manifest_test.dart`: manifest written with schema/entity/digests; `ProofChecker.check()` ok on fresh; `manifest_drift` on artifact hand-edit; `manifest_corrupt` on method-table tampering |
| `--explain` output shows the resolved emission plan for a cache+sync+datasource config — snapshot-tested | `repository_emission_plan_test.dart`: inline JSON snapshot for cache+sync+datasource (variant resolution + mutual-exclusivity warning) + CLI `--explain --json` equality with the planner |
| Synced, simple, and append variants each have content-asserting tests | `repository_variant_content_test.dart`: simple (direct `_dataSource` delegation, no cache/sync machinery), synced (local-first reads, `markPending`/`markDeleted`, sync ops with `@override`), append (members preserved + appended on both sides, no duplicates, no augment files) |

## 6. Remediation tasks

None — gate passed with all mutants killed after the in-pass M3 strengthening.
