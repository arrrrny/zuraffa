## Summary

Fixes the two open gaps from #1642: the kernel sweep now also reclaims the
`flutter_tools.*` orphan family (incident 1's six 264 MB dirs with 138 MB
`listener.dart.dill` files) under the identical four-guard stack, and an
**unscoped full-suite baseline now passes a disk preflight** — suites ×
measured 69 MB/snapshot + 2 GB margin vs the temp volume's `df -k` free
bytes — refusing with a `--> fix:` remedy before anything spawns, instead of
dying on ENOSPC mid-sweep and leaking everything compiled (incident 2's
47 GB orphan).

What already existed and is NOT duplicated (documented in the TDD records):
the startup sweep of `dart_test.kernel.*` (spec 1333/#1507) and the
own-on-exit cleanup (the spec-1520 per-run scratch `dispose()`). Requested
fix 2 — a single shared kernel across suites (~50 GB → ~70 MB) — is an
upstream package:test compilation-strategy change, tracked as a follow-up.

## Changes

- `kernel_cache.dart` — sweep family gains `flutter_tools.*`; argv liveness
  probe extended to both leak families; `diskPreflightMessage` /
  `freeBytesFromDfOutput` / `fullSuiteBaselinePreflight` /
  `DiskPreflightRefusal` with the measured constants.
- `run_driver_core.dart` — the UNSCOPED baseline capture runs the preflight
  and refuses via `DiskPreflightRefusal` (deliberately not `StateError`:
  the enclosing guard reads that as "no template" and would silently skip,
  re-arming the leak).
- `run_command.dart` — catches the refusal around `_runDriven`; honest stop,
  exit 1; the scratch `finally` still disposes.
- New suite `test/plugins/tdd/bug_1642_tmpdir_kernel_sweep_test.dart`
  (regression+slow, hermetic — injected env, no shared TMPDIR touched).

## Verification

- New suite 7/7 (stale reclaimed / fresh survives / live-referenced
  survives / preflight verdict + margin boundary / `df -k` parse). Pre-fix
  run was RED (missing subjects) — recorded in the TDD cycle log.
- Sibling guard-stack suites stay green: bug_1507 cycle-start + age guard +
  scratch tmpdir → **27/27**.
- `dart analyze lib test --no-fatal-warnings` → 0 errors / 0 warnings;
  `dart format` clean (CI's 3.13.3 pin).

Closes #1642.

Assessment: `.specify/bugs/tmpdir-kernel-leak/assessment.md` · Fix: `fix.md` · Verification: `test.md`
