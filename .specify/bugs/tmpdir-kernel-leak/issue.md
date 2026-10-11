# Bug Issue: tdd/test-infra — full-suite dart test writes ~50 GB of per-suite kernel snapshots into TMPDIR and leaks them on crash

- **Slug**: tmpdir-kernel-leak
- **Fetched**: 2026-09-15
- **Issue**: 1642
- **URL**: https://github.com/arrrrny/zuraffa/issues/1642
- **State**: open
- **Severity**: unknown (labels: build, tdd, track-tdd-loop)
- **Author**: arrrrny
- **Labels**: build, tdd, track-tdd-loop

## Body

Running the **full** zuraffa test suite (`dart test`, no path filter) makes
package:test's VM runner compile **every suite into its own self-contained
kernel snapshot** (`test.dart_N.dill`), each embedding the entire transitive
library graph (zuraffa src + generated mocks + test framework). There is no
dedup across suites: ~765 suites × ~69 MB ≈ **50 GB of temp files per
full-suite invocation**, all inside one `$TMPDIR/dart_test.kernel.*`
directory that is only deleted when the run exits cleanly.

On a 233 GB machine this is a guaranteed crash-loop: the sweep needs
~50 GB free, the run dies mid-sweep on ENOSPC, cleanup never runs, and the
whole directory leaks as an orphan. This happened **twice today**.

**Evidence (measured 2026-09-15)**

- Incident 1 (~04:00): two orphaned `dart_test.kernel.*` dirs totalling
  **23.5 GB** (~340 suites) plus six 264 MB `flutter_tools.*` dirs with
  138 MB `listener.dart.dill` files from hung `flutter test` runs; 6
  `flutter_tester` processes pinned at ~96% CPU. Disk at **100% (2.1 GB
  free)**.
- Incident 2 (~07:14): a fresh full-suite sweep wrote
  `$TMPDIR/dart_test.kernel.toVltp` = **47 GB / 766 entries** (~765 × 69 MB
  `test.dart_N.dill` + one `output.dill`). The generated bootstrap proves
  provenance (`packageConfigLocation` → this checkout). The sweep started
  with ~59 GB free, exhausted the disk, and died at 07:14 without cleanup.
  ~72 GB of orphaned temp had to be reclaimed manually across the two
  incidents.

**Why #1634 does not cover this**: #1634 is the build_runner entrypoint AOT
compile cost on the `zfa build` path. This issue is a different subsystem:
package:test kernel compilation strategy + temp hygiene on the `dart test`
path.

**Requested fixes**

1. **Defensive sweep (small, do first):** the TDD loop (`zfa tdd run` /
   cycle runner) sweeps `$TMPDIR/dart_test.kernel.*` and stale
   `flutter_tools.*` dirs at loop start and deletes its own on exit
   (try/finally). Guard startup sweeps to dirs older than ~1 hour or with no
   live owning process, so concurrent runs are safe.
2. **Compile once** — a single shared kernel, never recompile per suite or
   per run; pin the cache under `.dart_tool/test/kernel-cache` keyed by a
   source hash.
3. **Never run the full suite in the loop** + a **disk preflight**: require
   free space ≥ estimated suite temp footprint + margin, else fail fast.

**Impact**: two disk-full incidents in one day; 6 hung `flutter_tester`
processes; ~72 GB orphaned temp reclaimed by hand.

**Related**: #1634 (orthogonal), #1624, #1587

## Comments

None.
