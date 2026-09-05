# TDD Verification Report: Spec #975 — Cache A+ Upgrade

**Feature**: 975-cache-aplus-upgrade (GitHub issue #975)
**Verified**: 2026-09-05
**Branch**: `spec/975-cache-aplus-upgrade`
**Mode**: fallback LLM-guided audit (`/speckit.tdd.verify` Step 0: `zfa --version` → v6.1.0 OK, `.zfa.json` **missing** → `ZFA_MISSING` → the documented non-zuraffa-wired fallback path)

---

## Verdict: **PASS**

All four acceptance criteria of spec #975 are covered by passing, mutation-hardened tests. 38 new behavioral tests land in a dedicated suite under `test/plugins/cache/`; every command in the spec's verify section (`dart analyze`, chunked fast suite, `dart format .`) ran green with real exit codes.

---

## Red-Phase Evidence (test-first)

Tests were written and run BEFORE the implementation. The RED run (recorded, unedited):

```text
dart test test/plugins/cache/  →  +24 passed / -6 failed / 1 suite failed to load
```

The 6 failures + load failure were the new-behavior gaps, not flakiness:

| # | Failing test (RED) | Missing at the time |
|---|---|---|
| 1 | `a cache-adapter receipt lands in .zfa/receipts/ with the full payload` | no receipt ever persisted (Order 2 absent) |
| 2 | `the receipt binds the entity source as its spec` | no spec binding |
| 3 | `zfa proof check is GREEN on a fresh run, RED on a hand-edited registrar` | nothing receipted → proof had nothing to verify |
| 4 | `a second adapter run supersedes the first receipt (latest wins)` | no receipts |
| 5 | `run() reports the subcommand grammar…` (bare pin) | `verify` subcommand did not exist (`Which: does not contain 'verify'`) |
| 6 | `cache_verify_test.dart` — entire suite failed to COMPILE | `CacheAdapterVerifier` / `CacheEntityNotFoundException` did not exist (Order 3 absent) |

Additional honest framing: the issue's literal "bare `zfa cache` crashes with RangeError" was already partially mitigated on master by the #995 sweep (commit 99c4b136, landed the day before this branch); the CLI path exits 64 via the args `UsageException`. What remained red on this branch — and what this feature fixes — is: the **dead positional path** in `run()` (the RangeError source, removed by the state-command mirror), the **silent success** of `zfa cache adapter` (registrar action `'modified'` is a verb `CapabilityCommand` does not summarize → zero output, exit 0), **no receipts**, and **no verify subcommand**. All of these were reproduced and are pinned by tests.

## Green-Phase Evidence

```text
dart test test/plugins/cache/  →  +41: All tests passed!   (3 pre-existing + 38 new)
```

## Test Coverage Summary

| Suite file (all under `test/plugins/cache/`) | Tests | Proves |
|---|---|---|
| `cache_command_bare_test.dart` | 5 | Order 1: bare/positional/flags-only → usage + exit 64, never crash, never generate; `verify` subcommand registered |
| `cache_adapter_discovery_test.dart` | 6 | Order 4: recursive discovery (transitive, generics, KnownTypes excluded, cycle-safe); registrar regeneration preserves prior + cache-file entities |
| `manual_additions_merge_test.dart` | 4 | Order 4: comments preserved, dedup, idempotent re-runs, stable ordering |
| `policy_builder_content_test.dart` | 6 | Order 4: daily/restart/ttl policy content, 1440 default, disableCache guard, timestamp box |
| `cache_adapter_receipt_test.dart` | 6 | Order 2: receipt payload (`entity`, `discoveredEntities[]`, `registrarHash`, `buildStatus`), spec binding, proof check green/red, latest-wins, never-silent re-runs, dry-run ships nothing |
| `cache_verify_test.dart` | 11 | Order 3: service semantics (clean/missing/no-registrar/not-found/JSON) + CLI contract (exit 64 no-arg, exit 0 fresh, exit 1 + `--> fix:` per missing adapter, heal-on-rerun, stale registrar, `--json` verdict) |
| `create_cache_capability_validation_test.dart` | 3 | pre-existing (#772), still green — no semantic regression |

## Mutation Testing (changed files, real runs)

Five targeted mutants of the changed lines, each applied, tested, and reverted:

| Mutant | Change | Result | Killed by |
|---|---|---|---|
| M1 | `run()` no longer reports usage / sets exit 64 | **KILLED** (+4/-1) | `cache_command_bare_test.dart` |
| M2 | verify exit code mutated to always 0 | **KILLED** (4 failures) | drift-gate CLI tests |
| M3 | `registrarHash` faked to `'deadbeef'` | **KILLED** (3 failures) | receipt payload + proof-check tests |
| M4 | missing-adapter detection disabled | **KILLED** (5 failures) | verify service + CLI tests |
| M5 | honest verb `'updated'` reverted to `'modified'` | **SURVIVED → remediated → KILLED** | new regression test: `a re-run that updates the registrar is never silent` |

M5 is the remediation loop working as designed: the mutation exposed an unpinned behavior (silent success on registrar *updates* — the exact pre-#975 bug), a regression test was added, and the re-applied mutant was killed (verified a second time after restoration).

## Acceptance-Criteria Coverage

| Criterion (spec #975) | Status | Proof |
|---|---|---|
| Bare `zfa cache` never throws — usage + exit 64, tested | **PROVED** | 5 bare-command tests + manual run (exit 64, `Missing subcommand`); dead positional path deleted from `run()` |
| `cache adapter` writes the receipt; `zfa proof check` green on fresh run, red on hand-edited registrar | **PROVED** | receipt suite + manual run: fresh → `0 finding(s) — OK` exit 0; hand-edit → `[modified] lib/src/cache/hive_registrar.dart` + `FAIL` exit 1 |
| `cache verify` fails on entity with stale adapter — tested both ways | **PROVED** | CLI tests: drift (graph growth + hand-edit) → exit 1 with `--> fix:` lines; heal → exit 0; both directions asserted in one green suite |
| ≥6 new behavioral tests land | **PROVED** | 38 new tests (6 files) under `test/plugins/cache/` |

## Full Verification Commands (real runs)

- `dart analyze` — 0 issues in all changed files (`lib/src/plugins/cache/`, `lib/src/commands/`, `test/plugins/cache/` analyze clean: "No issues found!"). Repo-wide: 31 errors, **all pre-existing in `examples/todo_tdd`** (a standalone Flutter sub-package outside this change's footprint; untouched by this branch).
- `tools/run_tests_chunked.sh` — all 74 chunks executed: **OK, all chunks passed** (4 legitimate `SKIP: no fast-tier tests` folders — all-slow-tagged tiers, matching the runner's own semantics). Includes `test/plugins/cache` (+41) and `test/property` (+10).
- `dart format .` — idempotent: second run reports `0 changed`; `git diff --stat` shows only the intended files.

## Test-Smell Rubric

- No assertions on implementation internals that mock nothing (all tests exercise real files, real digests, real subprocess CLI).
- No conditional test logic; no sleeps; no order dependence (each test builds its own temp workspace).
- Subprocess tests use the repo's hermetic `runZfaSource` helper (AOT-compiled once, lock-serialized) — no CWD races, no process-global state leaks.
- One intentional characterization group (discovery/merge/policy) pins existing *correct* semantics per the spec's hard constraint ("do not change discovery/merge semantics — make them proven"); those tests are marked as such in their doc headers.

## Remediation Tasks

None — zero surviving mutants, zero failing tests, all acceptance criteria proved.
