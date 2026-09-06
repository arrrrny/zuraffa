# TDD Verification — Bug 1185 (make view no-methods crash)

- **Bug:** `1185-make-view-no-methods-crash` — GitHub issue #1185
  (`[MAKE] zfa make <E> --with=vpc --view --skin without --methods` crashes
  `Bad state: No element`, severity medium).
- **Generated:** FRESH from the actual run in this session (2026-09-06, UTC+8) —
  not a copy of a prior verification.
- **Command path:** `/speckit.tdd.verify` semantics executed manually against
  the bug branch `fix/1185-make-view-no-methods-crash` (spec-kit `specify` CLI
  v1.0.5.dev0 installed and checked; the repo's `.specify/extensions.yml`
  already carries the TDD extension v1.1.2 — `specify extension add tdd`
  is catalog-gated upstream and the installed registration was left
  untouched, per the do-not-clobber rule for `.specify/`).

## Verdict: **PASSED**

| Gate | Result |
|------|--------|
| RED (repro before fix) | ✅ `tdd/red-T001-issue1185-repro.log` — 2/5 new regression tests fail with the exact issue signature: plugin-level `Bad state: No element` at `PresenterPlugin._buildMethods (presenter_plugin.dart:450:55)` and CLI-level exit 1 (`❌ Generation failed: Bad state: No element`) |
| GREEN (after fix) | ✅ `tdd/green-T001-issue1185-fixed.log` — `+5: All tests passed!` (5/5 regression tests) |
| Live repro of the issue's exact command | ✅ `zfa make Product --with=vpc --view --skin --no-entity` → `✅ Done.` exit 0, 4 files (was: crash, exit 1) |
| `dart analyze` | ✅ changed files: **No issues found!** repo-wide 134 pre-existing issues (examples/todo_tdd subpackage + lib/tdd naming infos) — baseline identical on master (134 with the fix stashed) |
| `tools/run_tests_chunked.sh` (fast suite) | ✅ `tdd/chunked-suite.log` — 90 chunks: 84 ran, 6 "no fast-tier tests" skips, **3490 passed / 0 failed**, `OK: all chunks passed.` |
| Chunks the chunker structurally skips (>40 flat files) | ✅ `dart test test/commands --exclude-tags flutter` → **+246 passed**; `dart test test/regression --exclude-tags flutter` → **+20 passed** (includes the 5 new #1185 tests) |
| `dart format .` | ✅ `Formatted 2350 files (0 changed)` — zero remaining diffs; the only absorbed changes are 3 pre-existing format-drift files under `examples/todo_tdd/test/tdd/` (master drift, pure re-wrapping, disclosed in the PR) |
| Mutation-style guard checks | ✅ negative test proves the guard does not over-skip (entity-backed custom-usecase path still emits the synthetic `ProductUseCase` method); `--methods=get --no-entity` shape locked unchanged |

## 1. Red → green cycle log

- **T001 (red):** `tdd/red-T001-issue1185-repro.log` — with the fix stashed,
  `dart test test/regression/issue_1185_make_view_no_methods_test.dart`:
  `+3 -2` — the two repro tests fail with the issue's exact signature
  (`Bad state: No element` / CLI exit 1); the three guard/shape tests pass
  (they encode behavior that already worked and must keep working).
- **T001 (green):** `tdd/green-T001-issue1185-fixed.log` — with the fix
  applied, same command: `+5: All tests passed!` (exit 0).
- **Refactor:** none required (fix is 2 guard/default layers + docs).

## 2. The fix (what changed)

1. `lib/src/plugins/presenter/presenter_plugin.dart` — `_buildMethods`
   custom branch: `config.isCustomUseCase && config.methods.isEmpty &&
   useCases.isNotEmpty` (was: unguarded `useCases.first`). `_buildUseCaseInfo`
   legitimately returns an empty list for `--no-entity` no-methods runs
   (its synthetic branch requires `!config.noEntity`); skipping the custom
   method emits the bare presenter — byte-identical to the issue's own
   accepted success shape (`--methods=get --no-entity` → `✅ Done.`).
2. `lib/src/commands/make_command.dart` — spec-1002-style default for
   view-bearing runs: `_viewDefaultMethods = ['get', 'update', 'toggle']`
   (the same set the presenter/controller plugins already fall back to)
   injected AFTER `resolvePlan` when the plan carries `view`/`presenter`/
   `controller`, `--methods` was never parsed, no `--from-json` config
   supplied methods, and the run is entity-backed. Post-resolution injection
   guarantees the plugin chain can never change
   (`PlanResolver._hasEntityMethods` implies `usecase` from a non-empty
   method set — that stays an explicit user choice).

## 3. Success criteria — PROVED vs not

| Criterion | Status |
|-----------|--------|
| Crash fixed: bare `--with=vpc --view --skin --no-entity` no longer throws | **PROVED** (CLI test + live repro, exit 0) |
| Default methods or clear error naming the missing flag | **PROVED** (default set for entity-backed view-bearing runs; guarded bare scaffold for `--no-entity` — both success paths, no bare `Bad state` possible on this path) |
| Minimal fix with tests (red → green) | **PROVED** (2 lib files, 1 test file, RED log → GREEN log) |
| No behavior change for existing invocations | **PROVED** (full fast suite 3490/0; commands 246/0; plugin chunks presenter+3/controller+5/view+11; `--methods=get --no-entity` golden shape asserted unchanged) |
| `tdd/verification.md` (REAL) | **PROVED** (this file, generated from the actual run logs stored beside it) |

## 4. Environment notes (honest disclosure)

- Toolchain: Dart SDK 3.13.3 stable (linux x64). The Flutter-only `example/`
  subpackage and flutter-tagged tests are excluded by the repo's own
  convention (`--exclude-tags flutter`) on Dart-only installations; the
  issue's Flutter-fixture repro was emulated with the repo-standard
  fixture pubspec (flutter + zuraffa_flutter markers) that the presenter
  flavor gate requires — the same convention `presenter_structural_test.dart`
  uses.
- The sandbox reaps background processes, so the chunked suite ran through a
  resumable foreground wrapper (`tools/resume_chunked_1185.sh`, deleted
  before commit) that executes the exact per-chunk recipe of
  `tools/run_tests_chunked.sh` (same chunk list, same
  `dart test <chunk> --exclude-tags flutter`, same kernel-cache cleanup)
  with a time budget per invocation; per-chunk results were state-tracked
  until all 90 chunks completed.
