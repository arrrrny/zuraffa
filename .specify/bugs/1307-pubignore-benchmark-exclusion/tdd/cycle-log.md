# TDD Cycle Log — 1307-pubignore-benchmark-exclusion

- Engine: raw (zfa ZFA_MISSING → LLM-guided fallback per `speckit.tdd.run`)
- Test runner: `dart test test/pubignore_export_guard_test.dart` (scoped —
  per tdd-profile: full suite not run for bug work)
- Started: 2026-09-08T12:33:00Z
- SDK: Dart 3.13.3 (stable); root package resolved (106 packages)

## Baseline

- Pre-existing tree: `.pubignore` unanchored `benchmark/` (+ 7 sibling latent
  hazards: `benchmarks/`, `coverage/`, `.worktrees/`, `specs/`, `contracts/`,
  `apps/`, `build/`), `lib/zuraffa.dart:294-301` exports 8 files from
  `src/core/benchmark/`.
- Pre-test cache hygiene: `rm -rf .dart_tool/test/` before first run.

## B1 — export guard (AC-1) — RED → GREEN

**RED (test written first, before any `.pubignore` change):**

```
$ dart test test/pubignore_export_guard_test.dart --plain-name "export guard"
00:00 +0 -1: export guard: every export/part directive target under lib/
             exists in the would-publish set [E]
  Expected: empty
    Actual: [
      'lib/zuraffa.dart: export 'src/core/benchmark/benchmark_contract.dart'
       -> lib/src/core/benchmark/benchmark_contract.dart (on disk: yes)',
      'lib/zuraffa.dart: export 'src/core/benchmark/benchmark_result.dart'
       -> ... (on disk: yes)',
      'lib/zuraffa.dart: export 'src/core/benchmark/benchmark_registry.dart'
       -> ... (on disk: yes)',
      'lib/zuraffa.dart: export 'src/core/benchmark/benchmark_runner.dart'
       -> ... (on disk: yes)',
      'lib/zuraffa.dart: export 'src/core/benchmark/metric_collector.dart'
       -> ... (on disk: yes)',
      'lib/zuraffa.dart: export 'src/core/benchmark/baseline_store.dart'
       -> ... (on disk: yes)',
      'lib/zuraffa.dart: export 'src/core/benchmark/standard_metrics.dart'
       -> ... (on disk: yes)',
      'lib/zuraffa.dart: export 'src/core/benchmark/isolate_benchmark_runner.dart'
       -> ... (on disk: yes)'
    ]
```

Exactly the 8 bug-1307 targets: on disk but excluded from the would-publish
set by the unanchored `benchmark/` pattern. Fails for the RIGHT reason.

First loader attempt had a compile error (`FileSystemEntity.name` does not
exist → `p.basename(entity.path)`), fixed without touching assertions
(classification=compile-error handling per the run skill). The parser was
also refined during RED to skip `$`-interpolated URIs — code-generation
template text inside `initialize_command.dart`/`package_scaffold.dart` is
not a directive of this package (a real export/part URI cannot contain
interpolation). After that refinement RED still showed exactly the 8 real
targets.

**GREEN (after anchoring 8 patterns in `.pubignore`):**

```
$ dart test test/pubignore_export_guard_test.dart
00:00 +3: All tests passed!
```

## B2 — would-publish set regression wall (AC-2) — RED → GREEN

RED: `benchmark_contract.dart is exported by lib/zuraffa.dart and MUST ship
in the published tarball` (expect(contains) failure). GREEN after fix.

## B3 — .pubignore hygiene (AC-3) — RED → GREEN

RED listed the 8 unanchored hazards verbatim: `coverage/`, `.worktrees/`,
`specs/`, `contracts/`, `apps/`, `benchmark/`, `benchmarks/`, `build/`.
GREEN after fix.

## Refactor (while green)

- Formatted via `dart format`; analyzer clean (`dart analyze
  test/pubignore_export_guard_test.dart` → No issues found).

## Deliberate mutant sampling (verify rubric)

- Mutant: restore unanchored `benchmark/` at `.pubignore:31` (the 1307 root
  cause reintroduced).
- Result: suite RED under mutant → **mutant killed**; restored → suite GREEN
  again. The guard is not vacuous.

## Authoritative publish gate

- `dart pub publish --dry-run` (post-fix): tarball tree includes
  `lib/src/core/benchmark/` (benchmark_contract.dart 7 KB, benchmark_registry,
  benchmark_result, benchmark_runner, isolate_benchmark_runner) and
  `lib/src/plugins/benchmark/` (benchmark_plugin.dart + capabilities +
  commands). 4 warnings + 1 hint — all pre-existing layout advisories
  (tools/examples/docs rename hints, gitignored-but-checked-in files),
  unrelated to 1307 and present before the fix.

## Final suite state

GREEN — 3/3 behaviors pass. Tracked diff: `.pubignore` only
(13 insertions, 8 deletions).
