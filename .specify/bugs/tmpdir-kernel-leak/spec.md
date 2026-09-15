**Template Version**: `zuraffa-1.0`

# Bug Spec: TMPDIR kernel-snapshot leak — the TDD loop needs a defensive sweep and a disk preflight

**Input**: GitHub issue #1642 — every `dart test` invocation compiles each
suite into a self-contained ~69 MB kernel snapshot; a full-suite sweep ≈
50 GB inside one `$TMPDIR/dart_test.kernel.*` directory that only a CLEAN
exit deletes. Two same-day incidents (23.5 GB + 47 GB orphans, ~72 GB
reclaimed by hand; a verification run died on ENOSPC mid-baseline). The TDD
loop must defend its machine: sweep stale kernel temp at start, delete its
own delta on exit, and refuse a full-suite run that would exceed the disk.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: the TDD loop startup MUST sweep stale package:test kernel temp
  (`$TMPDIR/dart_test.kernel.*`) and orphaned `flutter_tools.*` dirs whose
  mtime is older than ~1 hour, and MUST leave fresh dirs untouched (a
  concurrent run may own them). The sweep is best-effort: a failure to
  delete is logged, never fatal.
            traces: TempKernelSweep.planStartupSweep
- **FR-002**: the loop MUST snapshot the temp-kernel dir set before running
  and, in a `finally`, delete exactly the dirs that appeared during the run
  (its own delta) — never pre-existing fresh dirs — so an abnormal exit
  still cleans up after itself.
            traces: TempKernelSweep.deltaCreated
- **FR-003**: before a FULL-suite invocation (the unscoped baseline
  capture), the loop MUST check the temp volume's free space against an
  estimate of suite-count × ~69 MB per-suite snapshot + a 2 GB margin, and
  fail fast with a `--> fix:` remedy message (scope the baseline, free
  space, or the chunked runner) instead of dying on ENOSPC. Scoped runs are
  not gated; the preflight is skipped when free space cannot be determined.
            traces: DiskPreflight.check

## Layer Contracts

**Function**:
- `TempKernelSweep`: `planStartupSweep(String tmpDir, DateTime now, Duration maxAge) -> List<String>`, `deltaCreated(Set<String> before, Set<String> after) -> List<String>` — planStartupSweep lists the dart_test.kernel.* and flutter_tools.* dirs under tmpDir whose mtime is older than maxAge (fresh dirs excluded), sorted by path; deltaCreated returns the dirs in after that were not in before (the run's own delta).
- `DiskPreflight`: `check(int freeBytes, int suiteCount, int perSuiteBytes, int marginBytes) -> String?` — null when the estimate fits, otherwise the fix remedy message naming scope-the-baseline / free-space / chunked-runner.

## Acceptance Scenarios

1. **Given** a temp dir holding a 2-hour-old `dart_test.kernel.old` and a
   5-minute-old `dart_test.kernel.live` **When** the startup sweep plans
   with a 1-hour max age **Then** only the stale dir is selected and the
   fresh dir survives.
   **Type**: acceptance
2. **Given** a pre-existing fresh kernel dir and a run that creates two new
   kernel dirs **When** the delta cleanup runs in a finally (simulating an
   abnormal exit) **Then** the two created dirs are deleted and the
   pre-existing fresh dir survives.
   **Type**: acceptance
3. **Given** a temp volume with less free space than suites × 69 MB + margin
   **When** a full-suite baseline starts **Then** the loop fails fast with
   the `--> fix:` remedy instead of spawning the sweep; a scoped run on the
   same volume is not gated.
   **Type**: acceptance
4. **Given** the wired driver **When** any loop exit path runs (clean,
   stop, error) **Then** the startup sweep ran once before the first spawn
   and the delta cleanup ran exactly once.
   **Type**: acceptance
