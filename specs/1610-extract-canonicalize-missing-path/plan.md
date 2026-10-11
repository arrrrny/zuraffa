# Implementation Plan: 1610-extract-canonicalize-missing-path

**Branch**: `chore/1610-extract-canonicalize-missing-path` | **Date**: 2026-09-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/1610-extract-canonicalize-missing-path/spec.md`

## Summary

Close issue #1610's two remaining gaps on top of the extraction PR #1611's
review round already landed (994daeb1): document the shared helper's
absolute-input precondition (library + function doc comments — comments only,
zero executable change), and add the direct unit test file the walk-up loop
never had (`test/plugins/tdd/services/path_canonicalizer_test.dart`) pinning
the symlink-resolved nearest existing ancestor, the ORIGINAL-ORDER re-append
of nested missing segments (the `tail.reversed` assertion the command pins
cannot make), the one-segment boundary, and the root-boundary walk — with
deliberate-mutant runs as the recorded red evidence, since the behaviors
already exist (brownfield characterization + mutation sampling per the TDD
playbook).

## Technical Context

**Language/Version**: Dart 3.13.4 stable (pubspec pins `sdk: ^3.11.0`; the
repo's tdd-profile documents Dart 3.13 as the expected stable). Pure-Dart
root package — no Flutter SDK involved on this path.

**Primary Dependencies**: `package:path` (^1.9.1, the `p.` import the helper
uses), `package:test` (^1.25.0) for the new unit test. No new dependencies.

**Storage**: N/A (filesystem-only logic exercised against
`Directory.systemTemp` fixtures).

**Testing**: `dart test test/plugins/tdd/services/path_canonicalizer_test.dart`
(single file), `dart test test/plugins/tdd/commands/view_command_test.dart`
+ `wire_command_test.dart` (+ `func_command_test.dart` run-only) for the
pin-stays-green gate; feature-scoped suite:
`dart test test/plugins/tdd/services/ test/plugins/tdd/commands/` with the
tdd-profile's `--exclude-tags "flutter || e2e"` guard where applicable.

**Target Platform**: Linux x64 (this environment) + macOS (the platform the
symlink semantics exist for — the fixtures reproduce its
`/var/folders` → `/private/var/folders` shape deterministically with a
symlinked temp-root alias). Windows: symlink tests skip via the repo's
`onPlatform` convention.

**Project Type**: library/cli (zuraffa is the zfa CLI + framework package).

**Performance Goals**: N/A — the walk-up loop is O(depth of missing
segments) `resolveSymbolicLinks` calls on an already-cold guard path; no
performance budget is named by the issue.

**Constraints**: Comments-only diff on the helper (no `assert`, no
absolutization inside the helper, no signature change — the issue's
"assert/absolutize OR document" fork is resolved toward DOCUMENT per the
chore's hard constraint); the new tests must be POSIX-safe (no root-owned
paths, no loop symlinks required for the pins) and Windows-skip on symlink
creation.

**Scale/Scope**: 1 source file (doc comments), 1 new test file (4 pinned
behaviors), 0 changes to view/wire/func commands, 0 behavioral diffs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is an UNPOPULATED template (placeholder
principles, `[PROJECT_NAME]`, `[PRINCIPLE_1_NAME]`) — no binding project
principles exist to check against. The repo's de-facto governance observed
from merged chore/fix history is honored instead:

- De-facto TDD discipline: red evidence recorded per cycle (this plan:
  deliberate-mutant reds for characterization pins, the 1623 precedent) — PASS
- De-facto scope hygiene: one PR per chore, minimal diff, no drive-by
  refactors — PASS
- De-facto analysis gate: `dart analyze` clean on touched scope — PASS

**Verdict**: GATE PASS (no populated constitution; de-facto rules honored;
re-check after design: unchanged — the design adds no structure beyond one
test file).

## Project Structure

### Documentation (this feature)

```text
specs/1610-extract-canonicalize-missing-path/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output — inlined below (see Research Notes)
├── tasks.md             # Phase 2 output (/speckit-tasks command)
├── checklists/
│   └── requirements.md  # Spec-quality checklist (from /speckit-specify)
└── tdd/
    ├── test-list.md     # /speckit.tdd.plan output
    ├── cycle-log.md     # /speckit.tdd.run evidence (append-only)
    └── verification.md  # /speckit.tdd.verify audit (real run)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/services/
└── path_canonicalizer.dart        # DOC COMMENTS ONLY (absolute precondition,
                                   #   CWD-join failure mode, fallback contract)
test/plugins/tdd/services/
└── path_canonicalizer_test.dart   # NEW — the direct walk-up pins (FR-004)

# UNTOUCHED (verified green, not edited):
lib/src/plugins/tdd/commands/view_command.dart   # imports the shared helper
lib/src/plugins/tdd/commands/wire_command.dart   # imports the shared helper
lib/src/plugins/tdd/commands/func_command.dart   # imports the shared helper
test/plugins/tdd/commands/view_command_test.dart # U-V3, U-V11..V13, U-1603a/b
test/plugins/tdd/commands/wire_command_test.dart # U-W3, U-1603e
```

**Structure Decision**: The helper already lives in the services/ layer beside
its sibling TDD services; the test mirrors the source layout per the repo's
documented test convention (source
`lib/src/plugins/tdd/services/foo.dart` → test
`test/plugins/tdd/services/foo_test.dart`). No new directories, no moves.

## Phase 0: Research Notes (research.md, inlined)

All Technical Context items resolved from the repo itself; no NEEDS
CLARIFICATION remain:

- **Decision**: DOCUMENT the precondition; do NOT assert or absolutize.
  **Rationale**: the chore's hard constraint forbids changing
  canonicalization logic or command behavior; an `assert(p.isAbsolute(path))`
  throws in debug mode (observable behavior change) and a silent absolutize
  masks caller bugs — the issue explicitly lists "document" as a satisfying
  option. All three call sites already absolutize, so the doc pins a contract
  reality already satisfies.
  **Alternatives considered**: runtime assert (rejected: behavior change);
  absolutize inside the helper (rejected: masks bugs, changes output for
  relative inputs); `@visibleForTesting` filesystem seam to test the
  no-ancestor fallback (rejected: restructures the helper for a
  POSIX-unreachable defensive branch).
- **Decision**: Deliberate-mutant runs as the red evidence for the new pins.
  **Rationale**: the helper's behaviors already exist on master (brownfield);
  the TDD playbook's characterization + deliberate-mutant procedure and the
  tdd-profile ("Mutation tool: none wired in CI ... falls back to
  deliberate-mutant sampling") both name this as the sanctioned strength
  evidence. The 1623 spec's cycle log records the same pattern ("passes by
  design (pin, recorded as such — NOT a fabricated red)").
  **Alternatives considered**: fabricating a red by writing tests before
  code (impossible — code exists); skipping strength evidence (verify would
  fail the audit honestly).
- **Decision**: Tail-order assertion via a TWO-segment missing path.
  **Rationale**: with one missing segment, `tail` has a single element and
  `.reversed` is invisible; with two (`missing_a/missing_b/subject.dart`),
  dropping `.reversed` yields `root/subject.dart/missing_b/missing_a` — a
  detectably different path. This is exactly the distinguishing power the
  issue says the command pins lack.
- **Decision**: Symlink reproduction technique — alias the fixture root.
  **Rationale**: identical to the merged command pins (U-1603a: create the
  fixture under `Directory.systemTemp`, create a symlink alias pointing at
  it, pass the ALIAS path so the resolved form differs from the raw form).
  POSIX-only; Windows skips.
- **Decision**: The no-ancestor fallback is pinned as DOCUMENTED-DEFENSIVE,
  not unit-hosted. **Rationale**: on POSIX the filesystem root always
  resolves, so `parent.path == dir.path` with a throwing root is unreachable
  through the public surface; the root-boundary test (missing path directly
  under the resolved root) pins the loop's NORMAL exit at that boundary, and
  the doc comment states the fallback contract (FR-002). Faking reachability
  would need a seam the constraint forbids.

## Phase 1: Design & Contracts

- **data-model.md**: N/A — no data entities; the "entity" is one function
  whose contract is restated in spec FR-001/FR-002 and re-derived in the test
  list.
- **contracts/**: N/A — no external interface changes; the function signature
  is existing and unchanged (`Future<String> canonicalizeMissingPath(String
  path)`), already declared under spec "Layer Contracts".
- **quickstart.md**: the validation flow is short enough to inline:

  ```bash
  # from repo root, Dart 3.13+ on PATH:
  dart pub get
  dart analyze lib/src/plugins/tdd/services/ test/plugins/tdd/services/
  dart test test/plugins/tdd/services/path_canonicalizer_test.dart
  dart test test/plugins/tdd/commands/view_command_test.dart \
            test/plugins/tdd/commands/wire_command_test.dart
  dart format --output=none --set-exit-if-changed lib test
  ```

  Expected: analyze → No issues found; the new test file → all green; the
  two pin suites → green unchanged; format → zero diffs.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

None — the design adds one test file and doc comments; no constitutional
(de-facto or templated) violations exist.
