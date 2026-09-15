# tdd.verify — Bug #1636 the running compiled binary outranks the PATH tier

- **Verified**: 2026-09-15, this session, on
  `fix/1636-refactor-build-resolves-path-zfa` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: `lib/src/plugins/tdd/services/step_runner.dart` (the tier
  reorder + docs), `lib/src/plugins/tdd/services/refactor_passes.dart`
  (doc-only), the new suite
  `test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart`, and
  the re-labeled/re-shaped `test/plugins/tdd/services/step_runner_test.dart`.

## Verdict: PASS

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/services/step_runner.dart
             lib/src/plugins/tdd/services/refactor_passes.dart
             test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart
             test/plugins/tdd/services/step_runner_test.dart
→ No issues found!          (re-checked after dart format)

dart analyze            (whole repo)
→ 106 issues found      (0 errors, 0 warnings — all `info`)
```

Zero findings from the changed/new files; the whole-repo count is the
pre-existing info-level baseline drift (106 here vs 111 recorded by the
#1626 verification), not this change.

## 2. TDD discipline (REAL runs in this session)

- RED, pre-fix (verbatim in `.specify/bugs/1636-refactor-build-resolves-path-zfa/red-evidence.md`):

```
dart test test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart
→ 00:00 +3 -2: Some tests failed.
  B1 Expected: '/tmp/zfa1636_cacheNSSXIE/zfa_exe'
     Actual:   '/tmp/zfa1636_pathLAZCWU/zfa'      ← the PATH install won
  B2 Expected: '/tmp/zfa1636_cache2CMNPFE/zfa_exe'
     Actual:   '/tmp/zfa1636_path2OUCSPU/zfa'     ← the PATH install won
```

- GREEN, post-fix:

```
dart test test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart
→ 00:00 +5: All tests passed!
```

The fix was applied only after the repro tests were proven red; no test
was edited to make it pass retroactively. B3/B4/B5 (the backward-compat
guards) passed both pre- and post-fix, proving the fix did not need them
loosened.

## 3. Regression suites (REAL runs in this session)

```
dart test test/plugins/tdd/services/
→ 01:42 +1104: All tests passed!
   (includes step_runner_test.dart, refactor_passes_test.dart — the
   #689/#717 build-pass suites, bug_1371_entrypoint_existence_test.dart,
   pipeline/runner suites, and every services neighbor)

dart test test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart
          test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart
→ 00:00 +18: All tests passed!
   (the #1472 pin driven through zfaBuildCommand's delegation:
   candidate==driving keeps the resolution; provably-different versions
   still swap; unresolvable replacements fail open — acceptance
   criterion 4)

dart test test/utils/dart_toolchain_resolver_test.dart
          test/plugins/tdd/bug_1329_step_failure_diagnostics_test.dart
          test/plugins/tdd/bug_1159_baseline_timeout_test.dart
→ 00:02 +18: All tests passed!

dart test test/core/no_jit_zfa_spawn_scan_test.dart
→ 00:00 +5: All tests passed!
   (the no-JIT sweep: the promoted tier returns a compiled binary, never
   a VM spawn — the directive the bug cites is now enforced at the tier
   that matters)
```

Chunked execution note: the one-attempt whole-directory run
(`test/plugins/tdd/ --exclude-tags "flutter || e2e"`) was abandoned — its
kernel cache ballooned until the filesystem hit 100% and the run was
killed at the 10-minute tool ceiling (a disk-housekeeping incident, not a
test failure). The suites above were then run in chunks with
`.dart_tool/test/` + `/tmp/dart_test.kernel.*` cleaned between chunks;
every chunk completed green.

## 4. Acceptance criteria audit (issue #1636)

1. **Compiled driving CLI → build pass uses the same binary** — PROVED at
   the tier level: B1/B2 red pre-fix, green post-fix; the build pass
   resolves through `StepRunner.resolveEntrypoint` (delegation unchanged,
   `refactor_passes.dart` code untouched). Not proven by spawning a real
   compiled binary end-to-end (the fast-tier convention this repo pins;
   the compile-cache shape is exercised via injected driver facts).
2. **`dart run` (VM) drivers keep the PATH tier** — PROVED: B3/B4 green,
   plus the re-labeled #690 PATH-tier test, plus the #717 build-pass test
   ("executes the system zfa on PATH") green under `dart test` itself.
3. **Tier order documented and tested per driver shape** — PROVED: the
   doc comments renumber the chain (1-3 source → 4 running binary →
   5 PATH → 6 script) with the #1636 rationale; B1-B5 + the re-labeled
   #690 group cover cache-exe, stale-dill, `dart run`, `dartaotruntime`,
   and JIT-snapshot driver shapes.
4. **The #1472 version pin still fires for same-binary upgrades** —
   PROVED by the untouched pin code + the #1472 gate suites (18 tests):
   with the fix a compiled driver's candidate IS the driving binary, so
   the probe returns equal and no swap fires (the honest no-op), while a
   provably-different candidate version still swaps.

## 5. Verdict

PASS — the bug is fixed at the tier level with red→green evidence, the
documented order matches the implemented order, the backward-compat and
pin contracts are pinned by suites that ran green in this session, and
the changed files carry zero analyzer findings.
