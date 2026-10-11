# Bug Assessment: full-suite `dart test` leaks ~50 GB of per-suite kernel snapshots into TMPDIR on crash — the TDD loop needs a defensive sweep + a disk preflight

- **Slug**: tmpdir-kernel-leak
- **Created**: 2026-09-15
- **Source**: https://github.com/arrrrny/zuraffa/issues/1642
- **Verdict**: valid
- **Severity**: high (recurring disk-full crash-loop; two same-day incidents, ~72 GB manually reclaimed; blocks every full-suite run on ~233 GB machines)

## Report (verbatim or summarized)

See ./issue.md — the issue body is quoted in full. First-hand corroboration:
both incidents happened during this session's #1640 verification — the
killed 25-minute `zfa tdd run` baseline and the concurrent IDE churn left a
47 GB `dart_test.kernel.jnBEjD` + an 11 GB `dart_test.kernel.hD4tSV` in
`$TMPDIR`, exhausted the disk, and killed a verification run with
`No space left on device` while writing the run baseline (errno 28 recorded
in the #1632 bug records). Both dirs were deleted by hand and the disk
returned to 58 GiB free.

## Symptom

Every `dart test` invocation makes package:test's VM runner compile each
suite into a self-contained kernel snapshot (~69 MB × ~765 suites ≈ 50 GB)
inside one `$TMPDIR/dart_test.kernel.*` directory. The directory is deleted
only on clean exit; any crash, kill, timeout, or ENOSPC mid-run leaks the
whole thing. Expected: the TDD loop defends its machine — sweep stale
kernel/orphaned `flutter_tools.*` temp at start, clean up its own delta on
exit, and refuse a full-suite run that would exceed the disk.

## Reproduction

1. Run the full suite (`dart test`, no path filter) or a TDD-loop full-suite
   baseline.
2. Kill it mid-run (timeout, Ctrl-C, ENOSPC).
3. `$TMPDIR/dart_test.kernel.*` remains, containing one ~69 MB `.dill` per
   suite compiled so far. Repeat until the disk fills.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_driver_core.dart` — the loop's entry
  (`runFeatureDriver`) and exit paths; no temp hygiene today (verified: the
  killed 25-min baseline left its kernel dir behind).
- `lib/src/plugins/tdd/services/step_runner.dart` /
  `differential_ref_runner.dart` / `corpus_step_runner.dart` — the spawned
  `dart test` children whose package:test runner writes the snapshots.
- The full-suite baseline capture (`SingleTestRunner.runSuite` with the
  unscoped suite template) is the largest single allocator: one full sweep ≈
  the whole 50 GB.
- No `flutter_tools.*`/`listener.dart.dill` hygiene anywhere in `lib/src`
  (the hung `flutter test` orphans from incident 1).

## Root Cause Hypothesis

package:test's VM runner has no cross-suite kernel dedup and no orphan
cleanup, and the zuraffa TDD loop (a) triggers full-suite sweeps (baseline
capture) without a disk-budget check and (b) takes no responsibility for
temp hygiene around its spawned runs — so every abnormal exit leaks tens of
GBs until the machine dies. Confidence: high (measured twice, provenance
proven via the generated bootstrap's `packageConfigLocation`).

## Proposed Remediation

**Preferred** (items 1 + 3 of the issue; item 2 is an upstream package:test
change and is explicitly out of scope — recorded as a follow-up):

1. **`TempKernelSweep` service** (new, pure-ish, injectable clock):
   - `planStartupSweep(tmpDir, {now, maxAge})` → the `dart_test.kernel.*` and
     `flutter_tools.*` dirs whose mtime is older than ~1 hour (concurrent-run
     safe: never touches fresh dirs another live run may own).
   - `Plan-run delta cleanup`: snapshot the dir set before the loop; after
     the run (try/finally), delete the dirs that appeared during it (ours),
     never the pre-existing fresh ones.
   - Wired into `runFeatureDriver`: sweep at start (logged, best-effort),
     delta cleanup in a finally.
2. **Disk preflight for full-suite sweeps** (`DiskPreflight`):
   - estimate = suite-file count under `test/**/*_test.dart` × 69 MB
     (the measured per-suite snapshot size) + 2 GB margin; compare against
     free space of the temp volume; fail fast with a `--> fix:` message
     naming the remedy (scope the baseline, free space, or chunked runner)
     instead of dying on ENOSPC.
   - Only guards FULL-suite invocations (the unscoped baseline); scoped runs
     are small by construction.

**Alternatives**:
- Item 2 (shared kernel under `.dart_tool/test/kernel-cache`) — the real
  50 GB → 70 MB fix, but it means replacing package:test's compilation
  strategy (custom loader or upstream work). Follow-up issue, not this fix.
- Cron-style external cleanup — outside the repo's control and doesn't fix
  the ENOSPC-during-run failure mode.

**Files likely to change**:
- new `lib/src/plugins/tdd/services/temp_kernel_sweep.dart` (sweep + delta
  tracking + preflight, injectable clock/stat).
- `lib/src/plugins/tdd/commands/run_driver_core.dart` (wire start sweep +
  finally delta cleanup + baseline preflight).
- new `test/plugins/tdd/services/temp_kernel_sweep_test.dart`.

**Tests to add or update**:
- Startup sweep selects stale dirs only (age boundary), leaves fresh dirs.
- Delta cleanup deletes only dirs that appeared during the run; a pre-existing
  fresh dir survives an abnormal exit.
- Preflight fails fast below the estimated footprint (with the remedy
  message) and passes with headroom; estimate matches the measured
  ~69 MB/suite.

## Risks & Considerations

- Deleting a concurrent run's dir would corrupt it — the age guard (>1h) and
  the delta-only exit cleanup are the guardrails; both must be pinned by
  tests.
- `Directory.stat`/free-space: use `Process.run('df', …)`? No —
  `dart:io` has no free-space API; implement via `Process.run('df', ['-k', dir])`
  (POSIX) with a conservative fallback (skip preflight when df is
  unavailable) — Windows gets the sweep but not the preflight (documented).
- Best-effort semantics: sweep failures must never fail the loop (logged).

## Open Questions

- None blocking. (Follow-up: the shared-kernel compile strategy = new issue.)
