# Traceability: tmpdir-kernel-leak

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:d4be924d0f6c00a4c0cfc6fc8a6a6e49ac8f2c117c9a12c3037f9c008e6e5d0f
statements: 7
automated: 7
manual: 0
fr-manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| FR-001 | 17 | - **FR-001**: the TDD loop startup MUST sweep stale package:test kernel temp | U1 | automated |
| FR-002 | 23 | - **FR-002**: the loop MUST snapshot the temp-kernel dir set before running | U2 | automated |
| FR-003 | 28 | - **FR-003**: before a FULL-suite invocation (the unscoped baseline | U3 | automated |
| AC-1 | 44 | 1. **Given** a temp dir holding a 2-hour-old `dart_test.kernel.old` and a | A1 | automated |
| AC-2 | 49 | 2. **Given** a pre-existing fresh kernel dir and a run that creates two new | A2 | automated |
| AC-3 | 54 | 3. **Given** a temp volume with less free space than suites × 69 MB + margin | A3 | automated |
| AC-4 | 59 | 4. **Given** the wired driver **When** any loop exit path runs (clean, | A4 | automated |

