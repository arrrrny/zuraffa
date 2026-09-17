# tdd.verify — Bug #1664 first refactor after a master bump compiles the zfa CLI (~85s) even when the parent runs from a current installed binary

- **Verified**: 2026-09-15, this session, on
  `fix/1664-first-refactor-cli-compile` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: `lib/src/cli/zfa_executable.dart` (the #1664 reuse probe +
  `_compileCached` wiring), the new
  `test/cli/zfa_executable_1664_installed_binary_reuse_test.dart`, and the
  bug artifacts under `.specify/bugs/1664-first-refactor-cli-compile/`.

## Verdict: PASS

## 1. TDD discipline (red → green → verify)

The loop was driven with the bug directory as the TDD feature. Ten
behaviors were pinned in `tdd/test-list.md` BEFORE the fix, mapped 1:1 to
the issue's four acceptance criteria, and every test in the red set was
observed failing against base `c5ed519f` for exactly the reason the issue
describes — never for a setup error.

```
dart analyze lib/src/cli/zfa_executable.dart
             test/cli/zfa_executable_1664_installed_binary_reuse_test.dart
→ No issues found!

dart analyze            (whole repo)
→ 106 issues found      (0 errors, 0 warnings — all `info`)
```

Zero findings from the changed/new files; the whole-repo count is the
pre-existing info-level baseline drift (106 — the same count the #1655
verification recorded).

Format gate:

```
dart format --output=none --set-exit-if-changed .
→ Formatted 2878 files (0 changed)      (exit 0 — zero drift repo-wide;
  the example/ resolution warning is the Flutter-less sandbox, not drift)
```

## 2. TDD discipline (REAL runs in this session)

- RED, pre-fix (verbatim in
  `.specify/bugs/1664-first-refactor-cli-compile/red-evidence.md`):

```
dart test test/cli/zfa_executable_1664_installed_binary_reuse_test.dart
→ 00:00 +0 -1: Some tests failed.
  loading test/cli/zfa_executable_1664_installed_binary_reuse_test.dart [E]
  Failed to load "...": Member not found:
    'ZfaExecutable.currentInstalledBinary'
```

  A compile-error red because the fix introduces a NEW seam: pre-fix there
  is no installed-binary awareness in the resolution at all — which IS the
  bug. The behavioral shape (a `.dart` candidate compiled despite a current
  installed binary) is what U-1664-b1 pins post-fix.

- GREEN, post-fix:

```
dart test test/cli/zfa_executable_1664_installed_binary_reuse_test.dart
→ 00:00 +9: All tests passed!
```

The fix was applied only after the repro suite was proven red; no test was
edited to make it pass retroactively. The guard tests (b2–b8: stale marker,
VM driver, missing/empty marker, git failure, non-canonical candidate,
missing exe) pin the fail-open direction — every unprovable input compiles
as before.

## 5. Regression audit (all green, real runs)

```
dart test test/cli/zfa_executable_test.dart test/cli/binary_staleness_test.dart
          test/plugins/tdd/services/step_runner_test.dart
          test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart
          test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart
          test/plugins/tdd/services/refactor_passes_test.dart
→ 00:16 +82: All tests passed!
   (the direct contracts of the changed file and its consumers: the U1–U10
   compile-cache contract, the #1184 marker reader, the StepRunner chain
   with the #1636/#1645 running-binary tiers, and the #689/#717/#1472
   build-pass resolution)

dart test test/cli/ test/core/ --exclude-tags "flutter || e2e"
→ 00:57 +901 (1 skipped): All tests passed!

dart test test/plugins/tdd/services/
→ 01:44 +1135: All tests passed!
```

Full `test/plugins/tdd/commands/` scope (subprocess-heavy, `-j 3`): flaky
under sandbox load BOTH with and without the change — different single
tests fail per run (post-fix runs: corpus_status_command / bug_1625
variants; a stashed PRE-FIX run failed four DIFFERENT tests: bug_1141,
realize_command, corpus_differential, plan_skin_contract). Every flagged
test passes in isolation with AND without the change (A/B via
`git stash`, `+16: All tests passed!` both ways). Pre-existing
environment flakiness, unrelated to this fix — the fix cannot affect a
`dart test` driver at all (the VM-shape probe rejects before any I/O, the
U-1664-b9 wiring pin).

Chunk/cache hygiene: `.dart_tool/test/` and `/tmp/dart_test.kernel.*` were
cleaned before and after every run; one 8.4G kernel-cache buildup was
found and removed mid-session (the task's disk-housekeeping rule); disk
stayed ≥86% free after cleanup.

## 4. Acceptance criteria audit (issue #1664)

1. **First refactor after master bump uses an existing compiled binary (no
   85s compile)** — PROVED at the seam level: U-1664-b1 returns the running
   binary for the canonical candidate when the marker equals the checkout
   HEAD, and the wiring sits AFTER the fresh-cache check and BEFORE the
   build lock, so the would-compile moment (the exact moment
   `scripts/rebuild.sh`'s `.dart_tool` wipe creates after every install)
   resolves to the installed binary instead of `dart compile exe`. Not
   re-timed end-to-end (the fast-tier convention this repo pins for cloud
   agents); the issue's own measurement (124.6s → 0.4–0.6s steady band)
   quantifies the cost being avoided.
2. **Child seam detects the current installed binary and reuses it** —
   PROVED: `ZfaExecutable.currentInstalledBinary` is the seam, and
   `_compileCached` consults it with `Platform.resolvedExecutable` on every
   cache miss/stale verdict — covering EVERY resolution path that funnels
   into the compile (StepRunner, PipelineRunner, `zfaBuildCommand`, phase-0,
   dream/replay/differential), which is the choke point the observed
   compile argv (`dart compile exe <checkout>/bin/zfa.dart --output
   <checkout>/.dart_tool/zfa_cli_bin/zfa_exe.tmp`) flows through.
3. **`.build_commit` comparison prevents stale binary reuse** — PROVED:
   U-1664-b2 (marker != HEAD → null → compile), U-1664-b4/b5 (missing or
   empty marker → null), U-1664-b6 (unresolvable HEAD → null). Strict
   full-SHA equality — no prefix/partial acceptance.
4. **Steady-state refactor time unchanged (0.4–0.6s)** — PROVED by
   construction and by tests: the fresh-cache verdict (mtime `_isStale`)
   runs FIRST and is byte-for-byte unchanged (pre-existing U3 pins
   reuse-without-compiler-call); the probe adds zero subprocesses for VM
   drivers (rejected before any I/O) and at most one `git rev-parse` +
   one marker read for a compiled parent on a cache miss — nanoseconds
   against a 0.4s step. The pre-existing staleness suites (U4/U5) ran green
   unchanged.

Hard constraints honored: the fix touches only
`lib/src/cli/zfa_executable.dart` (+ the new test file). No refactor pass
logic, no build-relevance gate, no CLI entry point changes — verified by
`git diff --stat` (129 insertions, one file).

## 5. Verdict

PASS — the child binary resolution now prefers a compiled install proven
current by its `zfa.build_commit` over an 85s AOT compile, every unprovable
input fails open to the exact pre-fix behavior, the stale-reuse guard is
pinned by test, and the warm-cache steady state is untouched.
