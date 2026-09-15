---
feature: 1637-build-skip-content-hashing
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 7
planned_at: aa5fe281
updated_at: aa5fe281
suite_baseline: green
---

# Test List: 1637-build-skip-content-hashing

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`. The gate is a pure-Dart
service whose observable contract is `refactorBuildSkipNote`'s verdict
(skip note vs null) plus the baseline record it maintains — the A-row
tests drive that contract through the REAL gate on temp project trees,
and A6 rides the registry-bound gate (`refactor_passes_test.dart`) to
prove the pass is not spawned.

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | a config file refreshed byte-identically after a completed build (mtime newer than the marker, bytes unchanged) does NOT force the refactor build pass — the gate returns the skip note | AC-1, SC-001 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > a byte-identical config refresh after a completed build skips the build` |
| A2 | a config file whose CONTENT changed since the last completed build still forces the build pass — the gate returns null and re-records the baseline | AC-2, SC-002 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > a config file whose content actually changed still runs the build and re-records the baseline` |
| A3 | with no baseline / corrupt baseline / wrong-version baseline, the gate runs the build exactly as #1624 did AND records a fresh baseline for the next cycle | AC-3, SC-003 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > a missing, corrupt, or wrong-version baseline fails toward RUN and records a fresh baseline` |
| A4 | a baseline whose recorded marker mtime is not strictly older than the current marker is untrusted — the gate runs even when digests match | AC-4, SC-004 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > a baseline whose recorded marker mtime is not strictly older is untrusted even with matching digests` |
| A5 | dart_test.yaml and analysis_options.yaml ride the same content-hash tier: byte-identical refresh skips, real change runs | AC-5, SC-005 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > dart_test.yaml and analysis_options.yaml ride the same content-hash tier` |
| A6 | every pre-#1637 gate shape keeps its verdict and the pass registry binds the fixed gate without spawning the build on a cleared tree | AC-6, SC-006, SC-007 | example | DONE | `test/plugins/tdd/services/refactor_passes_test.dart::RefactorPasses (T006 / T010) bug #689 — build pass resolves the zfa entrypoint > the default pass set attaches a skip gate to the build pass only (issue #1624)` + `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > the skip path never rewrites or invalidates the baseline` |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`, grouped by the component
that owns them (`build_relevance.dart`).

### `lib/src/plugins/tdd/services/build_relevance.dart`

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | `configFingerprint` hashes exactly the existing `buildConfigFiles` entries with the fingerprint digest — its digests equal `fingerprint`'s config entries for the same tree | FR-003 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > a baseline seeded from BuildRelevance.fingerprint digests is trusted (mechanism reuse)` |
| U2 | a trusted baseline with matching digests clears the config tier even when a newer plain .dart file also exists — the mixed-tree skip | FR-001, FR-002 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > a cleared config tier plus a newer plain .dart file still skips (mixed tree)` |
| U3 | a baseline seeded with a wrong digest for exactly one config file forces the run — per-file comparison, not per-tier | FR-001, FR-005 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > a baseline with one wrong config digest still runs the build` |
| U4 | the recorded baseline is a version-1 JSON at `.dart_tool/zfa/build_config_baseline.json` carrying markerMtimeMillis and a digests map covering every existing config file | FR-004, FR-006 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > the recorded baseline is version-1 JSON with markerMtimeMillis and full config digests` |
| U5 | the skip path never rewrites the baseline — after a skip decision the baseline bytes on disk are unchanged, so a follow-up call still skips | FR-006 | example | DONE | `test/plugins/tdd/services/build_relevance_test.dart::refactorBuildSkipNote (issue #1637 config content hashing) > the skip path never rewrites or invalidates the baseline` |
| U6 | the #1624 verdict table is unchanged for non-config shapes: missing marker → run, no newer file → skip, newer annotated .dart → run, newer non-Dart → run | FR-005 | example | DONE | existing group `refactorBuildSkipNote (issue #1624)` — 6 tests, unchanged and green |

## Invariants and edge cases still to place

- A config file created AFTER the baseline was recorded (absent from
  the baseline's digests map) must force the run — covered by U3's
  per-file comparison shape (absent key ≠ matching digest); folded
  into U3 rather than a separate row to keep one bug per line.

## Out of scope

- The make's `canSkipTerminalBuild` gate: already content-based
  (byte-identical refresh hashes equal and `continue`s) — no bug, no
  test change (`specs/1587` suites cover it).
- The build pass / asset-graph writer / `zfa build`: hard constraint
  FR-008; their behavior is asserted unchanged via A6's binding test.
- Mutation testing via a real mutator: none wired in the repo
  (tdd-profile); deliberate-mutant sampling per the verify rubric
  instead (see verification.md).

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md`:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (feature scope): `dart test test/plugins/tdd/ --exclude-tags "flutter || e2e"`
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
