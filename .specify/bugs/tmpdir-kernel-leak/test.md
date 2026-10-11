# Bug Verification: full-suite `dart test` leaks ~50 GB of per-suite kernel snapshots

- **Slug**: tmpdir-kernel-leak
- **Tested**: 2026-09-15
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/cycle-log.md (LLM-guided fallback loop; red →
  green recorded per cycle)

## Summary

The two open gaps from the issue no longer reproduce: a stale
`flutter_tools.*` orphan is reclaimed by the same guarded startup sweep that
handles `dart_test.kernel.*` (fresh and live-referenced dirs survive), and a
full-suite baseline on an under-provisioned volume now refuses before
spawning — with the `--> fix:` remedies — instead of dying on ENOSPC and
leaking everything compiled. Requested fix 1's own-on-exit cleanup and
startup sweep were already covered by the spec-1333/#1507/#1520 machinery;
fix 2 (shared kernel) remains a tracked follow-up.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| New suite (the fix's contract) | `dart test --preset=regression test/plugins/tdd/bug_1642_tmpdir_kernel_sweep_test.dart` | pass | 7/7 — C1 stale `flutter_tools.*` reclaimed; C2a fresh survives; C2b live-referenced survives; C3/C3b preflight verdict; C5 margin boundary; C4 `df -k` parse |
| Pre-fix reproduction | same suite before the change | fail (expected) | compile errors: `diskPreflightMessage` / `freeBytesFromDfOutput` missing; `flutter_tools.*` unmatched — recorded in ./tdd/cycle-log.md |
| Regression (guard stack) | `dart test test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart test/plugins/tdd/kernel_cache_age_guard_test.dart test/plugins/tdd/scratch_tmpdir_test.dart --tags "regression \|\| (regression && slow)"` | pass | 27/27 — the widened family and refusal path broke no existing guard contract |
| Static analysis | `dart analyze lib test --no-fatal-warnings` | pass | 0 errors / 0 warnings (106 style infos = master baseline) |
| Formatting | `dart format` on the touched files | pass | clean under the CI 3.13.3 pin |
| Live-machine corroboration | the two #1642 incidents' own debris | pass | both `dart_test.kernel.*` orphans from this session were deleted by hand and the disk returned to 58 GiB free; the preflight now refuses that state instead of entering it |

## Output Excerpts

```
00:00 +6: C4: the df -k free-bytes parser reads the POSIX column hermetically
00:00 +7: All tests passed!

00:23 +27: All tests passed!   (bug_1507 + age guard + scratch tmpdir)
```

## Residual Risks

- Requested fix 2 (compile-once shared kernel) is open — a full-suite sweep
  still *costs* ~50 GB of temp when the disk can carry it; the preflight
  makes that explicit and refused, not free.
- The preflight estimates with a fixed 69 MB/suite constant; if the
  per-suite snapshot size grows, the margin (2 GB) absorbs drift and the
  constant is a named, single-point update.
- Windows runners get the sweep but not the preflight (`df` is POSIX); the
  refusal degrades to the pre-#1642 behavior there (documented).

## Recommendation

Close the bug — verified end-to-end with the fix's own suite, the guard
stack's regression suites, and clean analyze/format. File the shared-kernel
follow-up when merging.
