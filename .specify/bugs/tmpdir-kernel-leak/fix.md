# Bug Fix: full-suite `dart test` leaks ~50 GB of per-suite kernel snapshots — defensive sweep family + disk preflight

- **Slug**: tmpdir-kernel-leak
- **Fixed**: 2026-09-15
- **Assessment**: ./assessment.md
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1642
- **Status**: applied
- **Branch**: fix/tmpdir-kernel-leak (isolation per bug.fix --branch)
- **TDD artifacts**: ./tdd/cycle-log.md (LLM-guided fallback loop; plan
  artifacts routed via `zfa tdd plan`)

## Summary

Closed the two open gaps from issue #1642's requested fixes: the kernel
sweep now also reclaims the `flutter_tools.*` orphan family under the same
four-guard stack, and an unscoped full-suite baseline now passes a disk
preflight (suites × measured 69 MB/suite + 2 GB margin vs `df -k` free
bytes) that fails fast with a `--> fix:` remedy instead of dying on ENOSPC
mid-sweep and leaking everything compiled. Requested fix 2 (a single shared
kernel) is an upstream package:test compilation-strategy change and stays a
follow-up.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/kernel_cache.dart` | sweep family + preflight | `flutter_tools.*` joins `dart_test.kernel.*` under the identical guard stack (argv liveness probe extended to both families, commandStartedAt, 1-hour age floor, cycle ownership); `diskPreflightMessage` / `freeBytesFromDfOutput` / `fullSuiteBaselinePreflight` / `DiskPreflightRefusal` added with the measured constants (69 MB/suite from the issue's evidence, 2 GB margin) |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | preflight wiring | the UNSCOPED baseline capture runs `fullSuiteBaselinePreflight` and refuses via `DiskPreflightRefusal` — deliberately not a `StateError`, which the enclosing guard reads as "no template" and would silently skip, re-arming the leak |
| `lib/src/plugins/tdd/commands/run_command.dart` | honest stop | catches `DiskPreflightRefusal` around `_runDriven`, prints the stop line, exit 1; the scratch `finally` still disposes |
| `test/plugins/tdd/bug_1642_tmpdir_kernel_sweep_test.dart` | new suite (7 tests) | hermetic (injected env, no shared TMPDIR touched); C1 stale `flutter_tools.*` reclaimed; C2a fresh survives; C2b live-referenced survives; C3/C3b/C5 preflight verdict + boundary margin; C4 `df -k` parsing |

## Tests Added or Updated

- `bug_1642_tmpdir_kernel_sweep_test.dart` — pins the new sweep family and
  the preflight contract (red → green; red was missing-subject compile
  failure, recorded in ./tdd/cycle-log.md).
- Regression: the sibling kernel suites (bug_1507 cycle-start, age guard,
  scratch tmpdir) stay green — `+27: All tests passed!` — proving the
  widened family and the new refusal path broke no existing guard contract.

## Local Verification

- `dart test --preset=regression test/plugins/tdd/bug_1642_tmpdir_kernel_sweep_test.dart` → 7/7.
- `dart test test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart test/plugins/tdd/kernel_cache_age_guard_test.dart test/plugins/tdd/scratch_tmpdir_test.dart --tags "regression || (regression && slow)"` → 27/27.
- `dart analyze lib test --no-fatal-warnings` → 0 errors / 0 warnings (106
  pre-existing style infos = master baseline).
- `dart format` clean on the touched files (CI's 3.13.3 pin).

## Deviations from Assessment

- **FR-002 (delta cleanup on exit) needed no new code**: the spec-1520
  per-run scratch already IS the run's own temp (`dart test` grandchildren
  write their kernel dirs inside it) and `_run()`'s `finally` disposes it;
  crash orphans (`zfa-*` scratch, ambient kernel dirs) are mopped by the
  startup sweep's age floor. Implementing the declared
  `TempKernelSweep.deltaCreated` would have duplicated #1520's mechanism —
  retired instead; the investigation is recorded in ./tdd/cycle-log.md.
- **Requested fix 2 (shared kernel, ~50 GB → ~70 MB)**: upstream
  package:test compilation strategy — out of scope for this fix, tracked as
  a follow-up (the preflight makes the current cost explicit and refused
  when the disk cannot carry it).

## Follow-ups

- File the shared-kernel follow-up issue (`compile-once` loader /
  `.dart_tool/test/kernel-cache` keyed by source hash).
- The preflight estimate uses the measured 69 MB/suite constant — revisit
  if package:test's snapshot strategy changes (the follow-up would delete
  it).
