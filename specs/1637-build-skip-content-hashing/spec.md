**Template Version**: `zuraffa-1.0`

# Spec: 1637-build-skip-content-hashing

## Overview

The #1624 refactor build-skip gate
(`BuildRelevance.refactorBuildSkipNote`) decides whether `zfa tdd
refactor`'s `build` pass has anything to do by comparing file **mtimes**
against build_runner's asset-graph marker
(`.dart_tool/build/asset_graph.json`): any file not older than the
marker that is a config file forces the build pass to run. In
production (calculator corpus, post-#1629) that comparison loses to a
no-op refresh: the preflight suite's implicit `pub get` rewrites
`pubspec.lock` and `.dart_tool/package_config.json` byte-identically
AFTER the last real build, so on every refactor that follows a suite
run the config files are "newer" than the marker and the gate runs the
whole-project build pass (~26-31s per behavior per #1624's table) even
though nothing builder-facing changed.

This spec makes the refactor gate's config tier CONTENT-based: a config
file whose bytes are identical to the digests the last completed build
consumed no longer forces the build. Mtime stays the cheap pre-filter
(only files not older than the marker are examined at all); on an
mtime hit the gate falls back to a content digest (the
`BuildRelevance.fingerprint` mechanism's FNV-1a digest over
`buildConfigFiles`), compared against a gate-owned baseline recording
the config digests plus the marker mtime observed when the gate last
let the build run. A baseline is trusted only when the current marker
is STRICTLY newer than the recorded one — the marker only moves when a
build completes, so validity proves a completed build consumed exactly
the recorded digests. `dart_test.yaml` and `analysis_options.yaml`
refreshes ride the same tier.

Scope guard (hard constraints from the issue): the fix touches ONLY
the build-relevance gate's config-file comparison (the refactor gate's
config tier + its baseline helper). The build pass itself, the
asset-graph writer, `zfa build`, and the run-loop state machine are
untouched. The make's terminal-build gate
(`canSkipTerminalBuild`) is already content-based (a byte-identical
config refresh hashes equal and `continue`s) and is NOT modified. When
config content actually changes, the build runs exactly as before.

## Acceptance Scenarios

1. **Given** a project whose asset-graph marker exists and whose config
   files (`pubspec.lock`, `.dart_tool/package_config.json`,
   `dart_test.yaml`, `analysis_options.yaml`) were refreshed
   byte-identically after the last completed build (mtime newer than
   the marker, content unchanged), **When** the refactor build gate
   evaluates, **Then** the build pass is SKIPPED — the gate returns the
   skip note, exactly as it does for plain un-annotated Dart writes
   (the mtime-only gate returned RUN here; that is the #1637
   regression).
   **Type**: acceptance
2. **Given** the same setup but a config file whose CONTENT actually
   changed since the last completed build (a real dependency edit —
   digest differs from the baseline), **When** the refactor build gate
   evaluates, **Then** the build pass RUNS (the gate returns null) —
   config content changes keep their fail-closed scheduling contract.
   **Type**: acceptance
3. **Given** no baseline record exists yet (first refactor after this
   fix ships, or the record is missing/corrupt/unreadable), **When**
   the refactor build gate evaluates a newer config file, **Then** it
   fails toward RUN exactly as the #1624 gate did — a missing or
   untrustworthy baseline never fabricates a skip — and the gate
   records a fresh baseline of current config digests so the NEXT
   completed build validates it.
   **Type**: acceptance
4. **Given** a baseline recorded before a build that did not complete
   (the marker's mtime is not strictly newer than the baseline's
   recorded marker mtime), **When** the refactor build gate evaluates,
   **Then** the baseline is treated as untrusted and the gate runs the
   build — validity is tied to the marker moving (a completed build),
   not to the record's mere existence.
   **Type**: acceptance
5. **Given** the digest fallback fires for `dart_test.yaml` or
   `analysis_options.yaml` (refreshed byte-identically vs. really
   changed), **When** the refactor build gate evaluates, **Then** both
   files behave exactly like the lock/config tier — byte-identical
   refreshes skip, real changes run.
   **Type**: acceptance
6. **Given** every pre-#1637 gate shape (missing marker → run; no
   newer file → skip; newer annotated `.dart` → run; newer non-Dart
   file → run; newer plain `.dart` → skip; any filesystem/read error →
   run), **When** the refactor build gate evaluates, **Then** every
   shape keeps its existing verdict — the config tier is the only
   changed comparison.
   **Type**: acceptance

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The refactor build gate MUST treat a config file newer
  than the asset-graph marker as build-forcing ONLY when its content
  digest differs from the digest recorded for it in the gate-owned
  baseline; a byte-identical refresh (mtime moved, bytes unchanged)
  MUST NOT force the build.
            traces: BuildRelevance
- **FR-002**: The gate MUST keep raw mtime comparison as the cheap
  pre-filter — only files not older than the marker enter the changed
  set, and the digest fallback runs only for config files inside that
  set.
            traces: BuildRelevance
- **FR-003**: The digest fallback MUST reuse the
  `BuildRelevance.fingerprint` mechanism — the same FNV-1a
  `_digestOf` content digest and the same `buildConfigFiles` set —
  for config-file hashing, so fingerprint-derived digests and
  baseline digests are interchangeable.
            traces: BuildRelevance
- **FR-004**: The baseline MUST record the config digests together
  with the asset-graph marker's mtime observed at record time, and the
  gate MUST trust it only when the current marker's mtime is STRICTLY
  newer than the recorded one (a completed build moved the marker
  after the digests were current).
            traces: BuildRelevance
- **FR-005**: The gate MUST fail toward RUN on every unknown: missing
  baseline, corrupt/unreadable/unparseable baseline, digest mismatch,
  or any filesystem error — a hiccup must never fabricate a skip.
            traces: BuildRelevance
- **FR-006**: The gate MUST record a fresh baseline (current config
  digests + current marker mtime) when it decides the build must run
  because of a config file, and MUST NOT rewrite the baseline on the
  skip path (rewriting with the current marker mtime would
  self-invalidate the record until the next build).
            traces: BuildRelevance
- **FR-007**: `dart_test.yaml` and `analysis_options.yaml` MUST be
  covered by the same content-hash logic as `pubspec.lock` and
  `.dart_tool/package_config.json`.
            traces: BuildRelevance
- **FR-008**: The build pass itself, the asset-graph writer, `zfa
  build`, the make's `canSkipTerminalBuild` gate, and the run-loop
  state machine MUST remain untouched.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A byte-identical `pubspec.lock` /
  `.dart_tool/package_config.json` refresh after a completed build
  no longer forces the refactor build pass — the gate returns the
  skip note (AC-1, the reported regression).
- **SC-002**: A config file with genuinely changed content still
  forces the build pass — the gate returns null (AC-2).
- **SC-003**: With no baseline (fresh checkout / deleted record), the
  gate's verdict is identical to the #1624 behavior: run — and a
  baseline is recorded for the next cycle (AC-3).
- **SC-004**: A baseline whose recorded marker mtime is not strictly
  older than the current marker is ignored (run) even when digests
  match (AC-4).
- **SC-005**: `dart_test.yaml` / `analysis_options.yaml` byte-identical
  refreshes skip and real changes run (AC-5).
- **SC-006**: The pre-existing #1624 gate test suite passes unchanged
  (AC-6) — no non-config verdict drifts.
- **SC-007**: The perf regression is closed end to end: on a tree
  where the only "changed" inputs are byte-identical config
  refreshes, `refactorBuildSkipNote` returns the skip note and the
  ~26-31s per-behavior build pass is not spawned by the pass registry.

## Assumptions

- The implicit `pub get` during preflight refreshes config files
  byte-identically when the dependency set is unchanged — the
  production evidence (post-#1629 calculator corpus) shows exactly
  this shape; a real dependency change rewrites bytes and stays
  build-forcing.
- build_runner rewrites the asset-graph marker when a build completes,
  so "marker mtime strictly newer than the baseline's recorded marker
  mtime" is a reliable completed-build signal; a build that fails or
  never spawns leaves the marker untouched and the baseline untrusted.
- The gate-owned baseline lives under `.dart_tool/zfa/` (the repo's
  established zfa-owned state area — `.dart_tool/zfa_cli_bin`,
  `.dart_tool/zfa_tdd_cycle.pid`), is best-effort, and its loss only
  costs one fail-safe build run, never a wrong skip.
- Concurrent config writes between gate evaluation and build completion
  are out of scope — the same mtime race existed in the #1624 gate,
  and every ambiguity here fails toward RUN.
