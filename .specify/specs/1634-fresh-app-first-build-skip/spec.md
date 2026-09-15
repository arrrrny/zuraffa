# 1634-fresh-app-first-build-skip

- **Spec ID**: 1634-fresh-app-first-build-skip
- **Created**: 2026-09-15
- **Source**: GitHub issue #1634 (perf: the one-time build_runner entrypoint AOT compile (~4 min) is paid inside the FIRST refactor — the #1624 build-relevance gate cannot skip a fresh app first build)
- **Type**: performance fix (P1 — every fresh app's first `zfa tdd run` pays ~400s of build_runner AOT compile + first build for features that generate nothing)
- **Branch**: feat/1634-fresh-app-first-build-skip
- **Related**: #1624 (R2 gate — the refactor build pass gate this fix extends), #1587 (make-side relevance skip — working, untouched), #1588 (pass-batch ledger), #1587 review findings (gate honesty conventions)

## Problem

After #1587 (make skips irrelevant builds) and #1624 R2 (the refactor's
build pass is gated by build relevance), a fresh app's **first**
`zfa tdd run` still pays the full build_runner cost. Measured on a fresh
`zfa setup calculator` (binary from `26a6fc03`):

```
[run] A1 make -> skipped                       (8.5s  — #1587 correctly skips the build in make)
[run] A1 refactor … 8m03s elapsed
[run] A1 refactor -> refactored                (482.7s)
```

The recorded refactor entry shows the build pass ran and produced
nothing:

```
- action: build
  command: `/Users/arrrrny/.local/bin/zfa build`
  changed: (none)
```

`ps` during the refactor showed `zfa build` → `dart run build_runner` →
`gen_snapshot` compiling `.dart_tool/build/entrypoint/build.dart.aot`
(~18.5 MB) — the one-time AOT compile of the build script. Subsequent
refactors confirm the gate works once the graph exists: A2's refactor
0.5s (ledger-inherited), U2 50.8s / U3 73.7s / U4 71.2s (build pass
gated) — versus 84–197s the day before.

Root cause: `BuildRelevance.refactorBuildSkipNote`
(`lib/src/plugins/tdd/services/build_relevance.dart`) keys the skip
decision on the `.dart_tool/build/asset_graph.json` marker. A fresh app
has no marker (and no `.dart_tool/build/` directory at all) until its
first build completes, so the first relevance check always fails open —
returning "run" on exactly the app state where skipping matters most.
The graph is only needed to reason about *incremental* freshness; it is
NOT needed to answer the different question "can anything in this tree
feed a builder at all?".

## Goal

When build_runner has no state in the project at all (no
`.dart_tool/build/` directory — the fresh-app state), the gate decides
STATICALLY from a source scan of the build-relevant trees: no
builder-facing annotation, no non-Dart source, and no `build.yaml`
means the first build has nothing to emit, so the pass is recorded as a
synthetic skip and the one-time AOT compile is never paid for features
that generate nothing. Any builder-facing signal fails the static
decision toward RUN exactly as the incremental gate does today. The
incremental freshness logic (post-first-build) is unchanged.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Fresh app, nothing builder-facing: first refactor skips the build (Priority: P1)

A developer scaffolds a fresh app (`zfa setup calculator`), runs
`zfa tdd run`, and the first behavior's refactor decides from a static
source scan that no file in the tree can feed a builder: the build pass
is recorded as a synthetic skipped action (issue-naming note, exit 0,
no files changed) and never spawned — the ~4 min one-time AOT compile
is never paid.

**Why this priority**: this is the reported #1634 cost — ~400s of every
fresh app's first TDD run, paid for features whose builders emit zero
outputs.

**Independent Test**: on a temp project with plain un-annotated Dart
under `lib/`, no `.dart_tool/build/` directory, and no `build.yaml`,
`BuildRelevance.refactorBuildSkipNote` returns the static first-build
skip note (non-null).

**Acceptance Scenarios**:

1. **Given** a project with no `.dart_tool/build/` directory and only
   un-annotated plain Dart under the walked roots, **When** the
   refactor build gate evaluates, **Then** it returns the static
   first-build skip note (the pass is recorded skipped, never spawned).
   **Type**: unit
2. **Given** the same project, **When** the refactor runs, **Then** the
   recorded `build` action carries `skipped: true`, `exitCode: 0`,
   `filesChanged: []` and the note as its output — identical recording
   shape to the #1624 incremental skip. **Type**: acceptance

### User Story 2 — Fresh app, builder-facing signal present: first refactor runs the build (Priority: P1)

The static decision is CONSERVATIVE — the build runs unless every file
provably cannot feed a builder. A fresh app whose tree holds a
builder-facing annotation (`@Zorphy`, `@JsonSerializable`, `@HiveType`,
`@HiveField`, `@Route`, `@ZfaRoute` — raw match, comments count), a
non-Dart file inside the walked roots (`lib/`, `test/`, `bin/`,
`tool/` — slang translation sources, assets), or a `build.yaml` at the
root (builder registration; `zfa build` auto-scaffolds one on first
run, so its presence without a graph means a builder was configured)
keeps today's behavior: the gate returns null and the build runs,
paying the one-time AOT compile exactly once and creating the asset
graph the incremental gate then uses.

**Why this priority**: a fabricated skip on a project that needed its
first build would leave generated outputs missing — worse than the cost
the fix removes. The run direction is the safe direction.

**Independent Test**: three temp projects — annotated Dart, non-Dart
file in a root, `build.yaml` at root — each with no
`.dart_tool/build/`, all make `refactorBuildSkipNote` return null.

**Acceptance Scenarios**:

1. **Given** a no-graph project containing an annotated `.dart` file,
   **When** the gate evaluates, **Then** it returns null (run).
   **Type**: unit
2. **Given** a no-graph project containing a non-Dart file inside a
   walked root, **When** the gate evaluates, **Then** it returns null
   (run). **Type**: unit
3. **Given** a no-graph project with a `build.yaml` at the root,
   **When** the gate evaluates, **Then** it returns null (run).
   **Type**: unit

### User Story 3 — Unknown and broken states keep failing toward RUN (Priority: P2)

The static path is reachable ONLY when build_runner has no state at
all: no `.dart_tool/build/` directory. A `.dart_tool/build/` directory
that exists WITHOUT the `asset_graph.json` marker (a mid-build or
partially-cleaned state) is an unknown — the gate keeps today's
fail-open and the build runs. Every filesystem/read error (decode
error, unreadable stat, file vanished mid-walk) fails toward RUN, never
fabricating a skip — the same error contract as #1587/#1624.

**Why this priority**: honesty of the recorded evidence; a skip must
never be synthesized from a state the gate cannot read.

**Independent Test**: a temp project with a `.dart_tool/build/`
directory but no marker returns null; a tree whose file read throws
returns null.

**Acceptance Scenarios**:

1. **Given** `.dart_tool/build/` exists but the marker does not,
   **When** the gate evaluates, **Then** it returns null (run).
   **Type**: unit
2. **Given** any filesystem error during the static scan (e.g. a file
   that is not valid UTF-8), **When** the gate evaluates, **Then** it
   returns null (run). **Type**: unit

### User Story 4 — Incremental freshness logic unchanged (Priority: P2)

Everything downstream of the first build — the marker-mtime comparison,
the newer-file collection, the incremental skip note, the deletion
blind-spot honesty — behaves exactly as shipped by #1624. The existing
incremental tests keep passing unchanged.

**Why this priority**: the hard constraint — fix the FIRST-build
relevance decision only.

**Independent Test**: the pre-existing #1624 test group
(`refactorBuildSkipNote` with a written marker) passes unmodified.

**Acceptance Scenarios**:

1. **Given** the marker exists, **When** the gate evaluates against
   newer annotated / plain / non-Dart / config files, **Then** every
   #1624 verdict is unchanged (same notes, same directions).
   **Type**: unit

## Requirements

### Functional Requirements

- **FR-1**: When `.dart_tool/build/asset_graph.json` is missing AND
  `.dart_tool/build/` does not exist, the gate performs a static scan
  of `lib/`, `test/`, `bin/`, `tool/` (skipping `*.g.dart.part`) plus
  the root `build.yaml` and decides without consulting any graph.
- **FR-2**: Static-scan RUN triggers (any one → null): a non-Dart file
  inside the walked roots; a `.dart` file whose raw content matches
  `BuildRelevance.builderFacingAnnotation`; a `build.yaml` present at
  the project root.
- **FR-3**: Static-scan SKIP (none of FR-2's triggers): return the new
  static first-build skip note naming issue #1634 and stating, honestly,
  the skipped whole-project `dart analyze lib/` stage trade-off and the
  scan's coverage boundary.
- **FR-4**: Marker missing but `.dart_tool/build/` present → null
  (run) — the unknown mid-state keeps failing open.
- **FR-5**: Marker present → the existing incremental decision, byte
  for byte (unchanged code path, unchanged note).
- **FR-6**: Any error → null (run), matching the #1587/#1624 error
  contract (catch everything).
- **FR-7**: The synthetic skipped recording shape in
  `RefactorPasses.run()` is unchanged (skipped: true, exitCode: 0,
  empty filesChanged, note as output).

### Key Entities

- `BuildRelevance.refactorBuildSkipNote` — the gate; gains the static
  first-build branch.
- `BuildRelevance.staticFirstBuildSkippedNote` — new note constant.
- `buildConfigFiles`, `builderFacingAnnotation` — reused verbatim (the
  static scan's annotation matcher IS the existing one; pubspec and
  other config files are deliberately NOT static triggers — they exist
  on every app, fresh or not, so their presence cannot discriminate
  "nothing to build" and would disable the skip forever).

## Success criteria (measurable)

- **SC-1**: A no-graph project with only un-annotated plain Dart under
  the walked roots and no `build.yaml` returns the static skip note
  (US1).
- **SC-2**: A no-graph project with an annotated file, a non-Dart file
  in a root, or a `build.yaml` returns null (US2 — three tests).
- **SC-3**: A no-graph project where `.dart_tool/build/` exists without
  the marker returns null; an erroring scan returns null (US3).
- **SC-4**: The existing #1624 incremental group passes UNMODIFIED
  (byte-identical test source) — FR-5.
- **SC-5**: `dart analyze` on every changed file reports no issues;
  `dart test` on the changed tests' files passes with real counts
  recorded in `tdd/verification.md`.

## Out of scope (hard constraints)

- The build pass itself (`zfa build`), the asset-graph writer, and the
  incremental freshness logic (FR-5) are NOT changed.
- The make-side gate (`canSkipTerminalBuild` /
  `shouldSkipTerminalBuild`, #1587) is NOT changed.
- Remedies 2 (JIT first build) and 3 (setup-time warm) from the issue
  are NOT implemented — remedy 1 (static skip) is the fix.
- No change to `RefactorPasses` recording mechanics beyond what the
  gate already plugs into.
