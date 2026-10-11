# Cycle Log — tmpdir-kernel-leak (#1642)

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Loop mode: LLM-guided fallback (recorded 2026-09-15)

`zfa tdd plan` routed all 10 behaviors cleanly (4 acceptance, 3 unit
func-surface, 3 contract) after the spec's contract rows were shaped for the
declared-routing grammar (exact row names, method-qualified traces,
backtick-free descriptions). The deterministic driver was NOT dispatched:
its func surface would scaffold the subjects under `lib/tdd/<feature>/`
instead of the plugin's `services/` home, and the acceptance scenarios are
process-level — the same shape that stopped `A1:make` vacuous-green for
#1632. The loop continues on the LLM-guided fallback path (the #1585/#1632
precedent), with the plan artifacts preserved.

## Investigation (pre-code)

The issue's three requested fixes met more existing machinery than the
issue assumed:

- Startup sweep of `dart_test.kernel.*` — EXISTS (spec 1333/#1507/#1520,
  `kernel_cache.dart`, four guard stacks: argv liveness, commandStartedAt,
  1-hour age floor, cycle ownership). Wired at `tdd run`/`tdd refactor`
  cycle start.
- "Delete its own on exit (try/finally)" — EXISTS for driver runs: the
  spec-1520 per-run scratch is the `TMPDIR` every spawned `dart test`
  writes into, and `_run()`'s `finally` disposes it. The residual leak-on-
  crash is a `zfa-*` scratch orphan, mopped by the next cycle's startup
  sweep after the 1-hour floor.
- NOT covered: the `flutter_tools.*` orphan family (incident 1's six
  264 MB dirs with 138 MB `listener.dart.dill` files) and any disk-budget
  check before the unscoped full-suite baseline (incident 2's 47 GB ENOSPC
  death). These two gaps are the fix.

## Cycle: sweep family + preflight (red)

- behavior: U1/U3 (FR-001, FR-003)
- kind: red (missing-subject: compile errors for `diskPreflightMessage` /
  `freeBytesFromDfOutput`; the `flutter_tools.*` family unmatched)
- test: test/plugins/tdd/bug_1642_tmpdir_kernel_sweep_test.dart
  (`@Tags(['regression', 'slow'])` — hermetic injected env, no shared
  TMPDIR touched; `ps`/`touch` per the #1507 fixture discipline)
- command: `dart test --preset=regression test/plugins/tdd/bug_1642_tmpdir_kernel_sweep_test.dart`
- exit: 1

## Cycle: sweep family + preflight (green)

- behavior: U1/U3 (FR-001, FR-003)
- kind: green
- change applied:
  - `kernel_cache.dart`: the sweep family gains `flutter_tools.*` (same
    guard stack); the argv liveness probe matches both leak families;
    `diskPreflightMessage` + `freeBytesFromDfOutput` +
    `fullSuiteBaselinePreflight` + `DiskPreflightRefusal` (est. =
    suites × 69 MB measured per-suite snapshot + 2 GB margin).
  - `run_driver_core.dart`: the UNSCOPED baseline capture runs the
    preflight and refuses via `DiskPreflightRefusal` — deliberately NOT a
    `StateError` (the enclosing guard reads that as "no template" and would
    silently skip, re-arming the leak).
  - `run_command.dart`: catches the refusal around `_runDriven`, prints the
    honest stop, sets exit 1 — the scratch `finally` still disposes.
- command: `dart test --preset=regression test/plugins/tdd/bug_1642_tmpdir_kernel_sweep_test.dart`
- exit: 0
- output:
```
00:00 +6: C4: the df -k free-bytes parser reads the POSIX column hermetically
00:00 +7: All tests passed!
```

## Regression pin (green)

- Sibling kernel suites stay green with the widened family:
  `dart test test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart
  test/plugins/tdd/kernel_cache_age_guard_test.dart
  test/plugins/tdd/scratch_tmpdir_test.dart --tags "regression || (regression && slow)"`
  → **+27: All tests passed!**
- FR-002 (delta cleanup on exit) — NO new code: the spec-1520 scratch
  `dispose()` already deletes the run's own kernel temp in a `finally`,
  and crash orphans are mopped by the startup sweep's `zfa-*` + age-floor
  rules. Declaring a parallel `deltaCreated` mechanism would duplicate
  1520's; retired as a deviation (see ./fix.md).
