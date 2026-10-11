---
feature: 1634-fresh-app-first-build-skip
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 5
planned_at: 07a675b
updated_at: V1-verify
suite_baseline: green
---

# Test List: Fresh-app first-build static skip (issue #1634)

The behavior under test is the refactor build gate's DECISION when
build_runner has no state in the project: `BuildRelevance.refactorBuildSkipNote`
on a tree without `.dart_tool/build/`. The loop is outside-in at the
gate's seam — every unit behavior is a fast, subprocess-free temp-dir
decision test (the existing `refactorBuildSkipNote` group's style), and
the registry-level recording shape is pinned through the bound gate in
`refactor_passes_test.dart`. The incremental (post-first-build) matrix
is a regression pin: it must pass BYTE-IDENTICAL (spec SC-4 — the hard
constraint "first-build decision only").

## Outer loop: the static first-build decision (issue #1634)

### Static skip — the US1 shape

| id | behavior                                                                                                                                             | traces     | kind    | state | test                                                                                                                                                                                              |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S1  | No `.dart_tool/build/` at all + only un-annotated plain Dart under lib/test/bin/tool + no `build.yaml` → returns `staticFirstBuildSkippedNote` (skip)  | SC-1, FR-1, FR-3 | example | DONE   | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote — static first build (issue #1634)::a fresh app with nothing builder-facing skips the first build statically`         |
| S1b | Same shape through the BOUND registry gate: the build spec's gate returns the static note (recording shape unchanged — skipped action, exit 0, no files) | SC-1, FR-7 | example | DONE   | `test/plugins/tdd/services/refactor_passes_test.dart::the default pass set attaches a skip gate to the build pass only (issue #1624)` (first assertion flipped to the static note)                 |

### Static RUN — the US2 conservative shapes

| id | behavior                                                                                                  | traces     | kind    | state | test                                                                                                                                                                     |
| --- | --------------------------------------------------------------------------------------------------------- | ---------- | ------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| S2  | No graph + an annotated `.dart` file (raw `@JsonSerializable`) → null (run)                                 | SC-2, FR-2 | example | DONE   | `...build_relevance_test.dart::static first build (issue #1634)::a fresh app with a builder-facing annotation runs the first build`                                        |
| S3  | No graph + a non-Dart file inside a walked root (slang/asset shape) → null (run)                            | SC-2, FR-2 | example | DONE   | `...build_relevance_test.dart::static first build (issue #1634)::a fresh app with a non-Dart source in a walked root runs the first build`                                 |
| S4  | No graph + `build.yaml` at the project root (builder registration) → null (run)                             | SC-2, FR-2 | example | DONE   | `...build_relevance_test.dart::static first build (issue #1634)::a fresh app with a build.yaml at the root runs the first build`                                           |

### Unknowns and errors fail toward RUN (US3)

| id | behavior                                                                                                             | traces     | kind    | state | test                                                                                                                                            |
| --- | -------------------------------------------------------------------------------------------------------------------- | ---------- | ------- | ----- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| S5  | Marker missing but `.dart_tool/build/` EXISTS (mid-build/partially cleaned) → null (run) — the static path is only for "no state at all" | SC-3, FR-4 | example | DONE   | `...build_relevance_test.dart::static first build (issue #1634)::a build directory without the asset-graph marker still runs the build`          |
| S6  | Static scan hits an unreadable file (invalid UTF-8) → null (run), never throws — the #1587 error contract               | SC-3, FR-6 | example | DONE   | `...build_relevance_test.dart::static first build (issue #1634)::a non-UTF8 file fails the static decision toward RUN, never throws`              |

## Regression pins (green-before-write by design — the #1624 gate shipped them)

| id | behavior                                                                                                                                                        | traces     | kind             | state | test                                                                                                                                                |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ---------------- | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1  | Marker present: newer annotated `.dart` → run; newer plain `.dart` → incremental skip note; newer non-Dart → run; newer config → run; unchanged tree → incremental skip note — ALL byte-identical to #1624 | SC-4, FR-5 | characterization | DONE   | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1624)` — five tests, source UNCHANGED from base 2ac6b9d7         |
| P2  | Make-side gate (#1587) untouched: fingerprint/canSkip/shouldSkip groups pass unmodified                                                                            | SC-4       | characterization | DONE   | `test/plugins/tdd/services/build_relevance_test.dart` groups `canSkipTerminalBuild` + `fingerprint` (source unchanged)                                |

## Invariants and edge cases still to place

- The static path performs NO mtime comparisons — immune to the
  coarse-mtime flakiness the incremental group backdates around
  (`setLastModifiedSync`); S1–S6 need no backdating at all.
- `bin/` and `tool/` roots are walked by the same code as `lib/`/`test/`
  (FR-1 names all four); the tests place files under `lib/` and `test/`
  — the roots are one loop, not per-root logic, so S3's non-Dart
  trigger and S2's annotation trigger generalize to every root by
  construction (asserted implicitly by the shared walk in the gate).
- `pubspec.yaml` is deliberately NOT a static trigger (plan D3): S1's
  fixture writes NO pubspec on purpose — adding one must not flip the
  verdict, and no test asserts it does (the absence of a pubspec trigger
  is the design, documented in plan.md D3, not an accident to pin).
