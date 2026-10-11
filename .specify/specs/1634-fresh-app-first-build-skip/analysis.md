# Analysis: 1634-fresh-app-first-build-skip

Cross-artifact consistency check: spec.md ↔ plan.md ↔ tasks.md ↔
tdd/test-list.md ↔ code reality at HEAD (2ac6b9d7 + spec artifacts).
Verdict after each finding: FIXED in this pass.

## Findings

### A1 — Ambiguity: "no marker" vs "no `.dart_tool/build/`" (spec FR-1 vs issue remedy text) — RESOLVED

The issue's remedy 1 says "if no `.dart_tool/build/` exists at all",
while the root-cause section keys on the missing `asset_graph.json`
marker. These differ for the mid-build state (directory present,
marker absent). Resolution (plan D2, spec FR-1/FR-4): the static
decision requires BOTH the marker and the directory to be absent;
directory-without-marker stays fail-open (run). tasks T002 S5 pins
that state. test-list S5 traces FR-4/US3. Consistent across artifacts.

### A2 — `build.yaml` as a static trigger vs fresh-app reality — VERIFIED SAFE

Risk: a fresh `zfa setup` app might carry a `build.yaml`, which would
block the static skip (US1 unachievable). Verified against code:
`BuildYamlGuard.check` (`lib/src/commands/build_yaml_guard.dart:41`)
returns `missing` for a never-built app, and `BuildCommand` scaffolds
it lazily during the first `zfa build` — so a no-graph app has no
`build.yaml` unless a human added one. The trigger is safe and
conservative. Spec FR-2/US2.3 stand.

### A3 — Existing tests contradict the new decision (expected drift) — PLANNED

- `build_relevance_test.dart` "a missing marker runs the build" (line
  ~271) asserts the fail-open #1634 removes. T001 rewrites that test
  into the static matrix; the REWRITE is the red phase (undefined
  constant + changed verdict).
- `refactor_passes_test.dart` line ~357 asserts `isNull` on an empty
  scratch project — under the new gate that project IS the skip shape.
  T003 flips the assertion to the static note; the incremental half of
  that test (marker-mtime skip) is unchanged. Both edits are scoped to
  the two tests; SC-4 requires every OTHER #1624 test byte-identical.

### A4 — Honest-note wording vs incremental note — RESOLVED (D4)

`refactorBuildSkippedNote` claims "every file newer than the asset
graph is un-annotated plain Dart" — FALSE when no graph exists. The
new `staticFirstBuildSkippedNote` must NOT reuse that sentence; it
claims only what the static scan proves (no annotation, no non-Dart
source in roots, no build.yaml, nothing for a first build to emit) and
states the analyze-stage trade-off + copied-tree boundary. Spec FR-3,
plan D4, test-list S1's note assertion.

### A5 — make-side gate untouched — VERIFIED IN SCOPE

`canSkipTerminalBuild` / `shouldSkipTerminalBuild` (#1587) and
`fingerprint` are not referenced by any 1634 artifact requirement; the
hard constraint holds (only `refactorBuildSkipNote` + a new constant +
docs change). No test in the #1587 groups exercises the refactor gate,
so no drift is possible there.

### A6 — tasks.md checkbox honesty — FIXED IN PASS

tasks.md was drafted with all boxes ticked; reset to `[ ]` before
commit 64efc2c3. Boxes are ticked only in later commits, alongside the
evidence that completes them.

## Coverage matrix (spec SC → tasks → tests)

| SC | task | test |
| -- | ---- | ---- |
| SC-1 | T002 | S1 |
| SC-2 | T002 | S2, S3, S4 |
| SC-3 | T002 | S5, S6 |
| SC-4 | T004 | #1624 incremental group (byte-identical) |
| SC-5 | T006/T007 | analyze + real test runs (verification.md) |

No orphan requirements; no orphan tests.
