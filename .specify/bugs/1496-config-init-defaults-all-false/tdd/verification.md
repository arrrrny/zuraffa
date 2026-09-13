# TDD Verification — #1496 config-init-defaults-all-false

- **Date**: 2026-09-13
- **Branch**: `fix/1496-config-init-defaults-all-false`
- **Runner**: real `dart test` / `dart analyze` / live CLI executions
  (Dart 3.13.3, linux x64). Every claim below cites a command that was
  actually run in this session; nothing is transcribed from memory.

## 1. Test-first evidence (red → green)

RED was recorded BEFORE the fix existed, on pristine master b621f38b:

```
$ dart test --preset=all test/commands/bug_1496_config_init_defaults_test.dart
00:00 +0 -6: Some tests failed.
```

All 6 behaviors (B1-B6) failed for the exact reasons the assessment
names: stack plugins false everywhere (B1-B3), `--minimal` unsupported
(B4), "No active plugins to run." dead end (B5), remedy-free message
(B6). Full transcripts in `red-evidence.md`.

GREEN on the fix branch, same suite:

```
$ dart test --preset=all test/commands/bug_1496_config_init_defaults_test.dart
00:02 +6: All tests passed!
```

The pre-existing suite that encoded the BUGGY intent
(`test/config/zfa_config_test.dart` — init → test/mock default false)
was updated to the fixed intent in the same commit series, per
test-first discipline: the behavior contract moved, so the pin moved
with it.

## 2. Test-smell rubric

| Smell | Verdict |
| ----- | ------- |
| Vacuous green (assert nothing / assert true) | NONE — every test asserts concrete map values, resolver output, or on-disk artifacts (file existence checks in B5, exact default values in B1/B4, message content in B6) |
| Tautological (test mirrors the implementation) | NONE — B2 drives the REAL PluginLoader registry through PlanResolver; B5 runs real generation and inspects the file tree; no test reads `_builtinPluginDefaults` directly |
| Fixture-of-itself (arrange produces the expected value) | NONE — configs are written by `ZfaConfig.init`/`init --minimal` or hand-edited JSON in the test, then re-LOADED through the production `ZfaConfig.load` path |
| Hidden ordering/coupling | NONE — each test builds its own temp dir; teardown tolerates late children (repo #503 convention) |
| Assertion-free error paths | NONE — B6 asserts the remedy strings (`--preset=crud`, `--with=`) appear in the captured output |

## 3. Mutation-style spot checks (behavior actually pinned)

- Flip check: B4's minimal map asserts EVERY stack id `false` — a fix
  that only flipped `di` would fail B1 AND B2 (both iterate the full
  stack list) and B4 (minimal asserts all-off).
- Merge-order check: B3 writes `mock: false`/`route: false` into a
  stack-on file and asserts they stay off while untouched stack members
  stay on — catches any regression that makes `fromJson` clobber
  explicit keys with the builtin map.
- Symptom check: B5 asserts `isNot(contains('No active plugins'))` AND
  four on-disk artifacts — the issue's exact symptom cannot recur
  silently.

## 4. Acceptance criteria coverage (from issue.md "Expected")

| AC | Covering test/evidence | Status |
| -- | ---------------------- | ------ |
| 1. Stack plugins default true (12 ids) | B1 (on-disk), B2 (in-memory + resolver) | PASS |
| 2. Opt-in plugins stay false (graphql/gql, sqlite, view, skin, state, feature, gym, xray, agent) | B1 + B2 assert the full opt-in list `isFalse` (plus observer/service) | PASS |
| 3. Empty-plan remedy names the fix | B6 + live CLI capture | PASS |
| 4. `zfa config init --minimal` for the all-off behaviour | B4 + live CLI (0 true defaults on disk) | PASS |
| Constraint: registry/resolver/state machine untouched | diff scope + guardrails table in test-list.md | PASS |
| Constraint: custom configs not broken | B3 + plugin_manager/compare_outputs suites green | PASS |
| Constraint: dart analyze, no new warnings | analyze on changed files → only the master-verified pre-existing info lint | PASS |

## 5. Full-suite regression (chunked, disk-safe)

`tools/run_tests_chunked.sh` semantics over all 105 fast-suite chunks:

- 99 chunks: **All tests passed** (including every chunk touching the
  changed surfaces: test/config, test/core/planning,
  test/core/plugin_system, test/commands, test/cli, test/agent,
  test/graphql, test/plugins/graphql, compare_outputs).
- 6 chunks failed — ALL verified to fail IDENTICALLY on pristine
  master (stashed run, same 6 chunks, exit 6):
  - `test/plugins/controller`, `test/plugins/view`, `test/templates`
    → `flutter pub get` missing (no Flutter SDK in this environment;
    compile-gate fixtures require it),
  - `test/integration`, `test/plugins/tdd/scenarios`,
    `test/tdd/077-make-engine-preset`
    → "No tests ran" (every suite in the chunk is `slow`-tagged; the
    fast tier excludes them and `dart test` exits non-zero on an empty
    selection).
  → **0 new failures** attributable to this fix.

## 6. Live CLI end-to-end (fresh repro, post-fix)

```
$ zfa config init          → 12 true defaults in .zfa.json
$ zfa make Task            → ✅ Done. (30 files; was "No active plugins to run.")
$ all-off .zfa.json + zfa make Task2 --no-entity
   ❌ No active plugins to run.
   --> fix: pass --preset=crud for the standard data slice, or
      --with=<plugin> to select individual plugins (e.g.
      --with=usecase,repository). See `zfa make --help`.
$ zfa config init --minimal → 0 true defaults (pre-#1496 behaviour preserved)
```

Verdict: **VERIFIED** — red evidence, green evidence, guardrails,
acceptance coverage, chunked regression, and live repro all real.
