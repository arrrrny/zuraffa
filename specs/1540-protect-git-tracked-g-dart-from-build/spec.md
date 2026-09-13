# Feature Specification: Protect git-tracked hand-authored `.g.dart` placeholders from build cleanup (restore-or-refuse)

**Feature Branch**: `feat/1540-protect-git-tracked-g.dart-from-build`

**Created**: 2026-09-13

**Status**: Draft

**Input**: Issue #1540 — `zfa build` (inside a `zfa tdd refactor` pass) deletes a git-tracked hand-authored placeholder `engine_event.g.dart`, then fails its own completeness gate — the loop dead-ends with no restore remedy.

## Mission

json_serializable's builder reserves `<lib>.g.dart` as the output for EVERY
library in `generate_for`. A pre-existing `.g.dart` with no producing
generator run in the current build is treated as a stale/orphaned output and
is deleted by build_runner's cleanup. A hand-authored placeholder is
indistinguishable from an orphaned output by filename convention.

When the deleted placeholder is referenced by a `part` directive, `zfa build`
then fails its own completeness gate (`verifyDeclaredPartsOrFail`) and exits
non-zero. Inside `zfa tdd refactor` the build pass misfire-stops; the tree is
left broken (tracked file gone, package does not compile) and the operator is
given no restore path — the loop dead-ends.

`zfa` must never leave a git-tracked generated-name file deleted by its own
build step without either restoring it or naming the exact restore remedy.
The build step is the only component allowed to change (never build_runner
internals, never json_serializable behavior).

## User Scenarios & Testing *(mandatory)*

### User Story 1 — `zfa build` restores-or-refuses on tracked-output deletion (Priority: P1)

A developer (or the TDD loop) runs `zfa build` in a git project that tracks a
hand-authored placeholder `lib/src/engine/events/engine_event.g.dart`. The
build's cleanup deletes it. `zfa build` detects the deletion, restores the
exact pre-build bytes, reports what it restored, and explains the
hand-authored-placeholder pattern and its `build.yaml` exclusions. If
restoration is impossible, `zfa build` refuses with an actionable remedy
(the exact `git checkout -- <path>` command) instead of exiting leaving the
tree broken.

**Why this priority**: This is the dead-end itself. Without detection the
completeness gate fires on a file the build deleted, and no message names a
remedy.

**Independent Test**: git-initialized fixture with a tracked placeholder
deleted by the build step → after `zfa build`-equivalent recovery, the file
exists again with byte-identical content and the output names the
hand-authored-placeholder remedy.

**Acceptance Scenarios**:

1. **Given** a git-tracked generated-name file exists pre-build, **When** the
   build step deletes it, **Then** the file is restored with its exact
   pre-build bytes (including unstaged hand edits) and the run reports what
   was restored with the pattern documentation reference.
2. **Given** the build deletes a tracked generated-name file whose bytes
   cannot be restored, **When** `zfa build` finishes the recovery step,
   **Then** the command exits non-zero naming the file and printing
   `git checkout -- <path>` plus the `build.yaml` exclusion remedy — it does
   not proceed as if the tree were intact.
3. **Given** a non-git project (or git unavailable), **When** the build runs,
   **Then** the guard is disabled entirely: no snapshot, no messages, no
   behavior change.
4. **Given** a legitimately regenerated `.g.dart` (its producing generator
   ran this build), **When** the build completes, **Then** the file is
   untouched — regeneration is never blocked, reverted, or reported.

### User Story 2 — completeness gate names the restore path (Priority: P1)

A declared part file (`.g.dart`/`.zorphy.dart`) is missing after a build and
that path is tracked in git. The completeness gate
(`verifyDeclaredPartsOrFail`) fails as before, but its message now detects
the git-tracked deletion and prints an actionable restore path:
`git checkout -- <path>`, the placeholder pattern explanation, and the
`build.yaml` exclusion fix. Untracked missing parts keep the existing
message unchanged.

**Why this priority**: The gate is the component that dead-ends the loop
today; it must always provide the remedy even when the pre/post-build
snapshot layer could not act (e.g. a stale `zfa` binary ran the build).

**Independent Test**: Fixture with a source declaring
`part 'engine_event.g.dart';`, placeholder file deleted, path tracked in
git → gate returns false and its message contains
`git checkout -- lib/src/engine/events/engine_event.g.dart`.

**Acceptance Scenarios**:

1. **Given** a missing declared part whose path is git-tracked, **When** the
   completeness gate fails, **Then** the message names the file as a
   git-tracked hand-authored placeholder deletion and prints the exact
   `git checkout -- <path>` restore command and the doc reference.
2. **Given** a missing declared part NOT tracked in git, **When** the gate
   fails, **Then** the existing message is unchanged (no spec-1540 remedy
   lines, no false tracking claim).

### User Story 3 — `zfa tdd refactor` build pass restores-or-refuses (Priority: P1)

The refactor pass registry's `build` pass (which invokes `zfa build`) no
longer deletes-and-fails: after the build pass executes, git-tracked
generated-name files deleted by the pass are restored from the pre-pass
snapshot; the restoration is recorded in the pass action's output (printed
pass record + cycle-log evidence). When restoration is impossible, the
registry refuses — misfire-stop with the failure named `build` and a refusal
reason carrying the exact restore remedy.

**Why this priority**: The refactor pass is where the dead-end loop
materializes; the loop must be able to continue after a spurious deletion.

**Independent Test**: TddFixture whose fake `zfa` deletes a tracked
placeholder and exits 0 → after `zfa tdd refactor`, the placeholder exists
byte-identical, and the recorded pass output contains the restoration note.

**Acceptance Scenarios**:

1. **Given** the build pass deletes a git-tracked placeholder and exits 0,
   **When** the pass registry records the action, **Then** the file is
   restored byte-identical before the pass's after-snapshot (no spurious
   attribution deltas) and the action output contains the restoration note.
2. **Given** the build pass deletes a git-tracked placeholder and the
   restore fails, **When** the registry evaluates the pass, **Then** the
   registry stops (misfire-stop, failed pass `build`), names the refusal
   with the `git checkout -- <path>` remedy, and exits non-zero.
3. **Given** the build pass restores a deleted placeholder, **Then** the
   change is attributable (recorded in the action output) — the attribution
   check never flags the restoration as an unattributed edit.

### User Story 4 — the pattern is documented (Priority: P2)

The hand-authored-placeholder pattern (`.g.dart` files with no owning
generator) is documented with its `build.yaml` exclusions for BOTH builders
(`json_serializable` and `source_gen:combining_builder`), how to legitimize
a placeholder, and how zfa protects it. The remedy messages reference the
doc page.

**Why this priority**: Without documentation the operator cannot stop the
recurring deletion; the guard would restore on every build forever.

**Independent Test**: `docs/hand-authored-g-dart-placeholders.md` exists and
contains exclusion YAML for both builder keys; remedy strings reference it.

**Acceptance Scenarios**:

1. **Given** the docs page, **When** an operator follows it, **Then** they
   can add both builder exclusions and the deletion stops recurring.
2. **Given** the guard's restore message, **When** it prints, **Then** it
   references the documentation path.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-1** (US1): Before invoking build_runner, `zfa build` snapshots every
  generated-name file (`.g.dart`, `.zorphy.dart`) that is BOTH tracked in
  git's index AND present on disk, capturing its exact bytes.
- **FR-2** (US1): After each build_runner invocation (initial and clean-cache
  retry), `zfa build` detects snapshot members that no longer exist and
  restores their exact pre-build bytes. Unstaged hand edits are preserved
  (restore writes captured bytes, not `git checkout`).
- **FR-3** (US1): Every restoration is reported with the file path, the
  hand-authored-placeholder explanation, the convention-derived owning
  library, both `build.yaml` exclusion lines, and the docs reference.
- **FR-4** (US1): If any deletion cannot be restored, `zfa build` exits
  non-zero naming the file and the exact `git checkout -- <path>` remedy.
- **FR-5** (US1): The guard is a no-op when the project is not inside a git
  work tree or git cannot be executed.
- **FR-6** (US2): `verifyDeclaredPartsOrFail` keeps its sync signature; on
  the missing-parts failure path it checks each missing path against
  git's index (single `git ls-files` call) and, for tracked paths, prints
  the restore remedy. It never claims tracking it cannot verify.
- **FR-7** (US3): The refactor pass registry snapshots tracked generated-name
  files around the `build` pass only, restores deletions before the pass's
  after-snapshot, records restoration in the action output, and refuses
  (misfire-stop + refusal reason with remedy) when restoration fails.
- **FR-8** (US3): `RefactorPassesResult` carries the refusal reason; the
  refactor command prints it in its misfire-stop block. Attribution and
  test-immutability checks are unaffected by a successful restoration.
- **FR-9** (US4): A documentation page exists at
  `docs/hand-authored-g-dart-placeholders.md` covering the pattern, both
  builder exclusions, and the protection behavior; all remedy messages
  reference it.

### Hard Constraints (from the issue)

- Fix ONLY the build step's file cleanup/recovery logic or the refactor pass
  recovery. Do NOT change json_serializable behavior or build_runner
  internals.
- Must not break legitimate `.g.dart` regeneration: only files deleted
  (present pre, absent post) and git-tracked are acted on.
- `dart analyze` with no new warnings.

## Success Criteria (measurable)

- **SC-1**: In a git fixture, a tracked placeholder deleted by the build step
  exists again byte-identical after the recovery step; the output names it
  and the docs reference. (US1.AC1)
- **SC-2**: Forced restore failure makes `zfa build` exit non-zero with
  `git checkout -- <path>` in its output. (US1.AC2)
- **SC-3**: In a non-git sandbox the new code paths produce no output and no
  subprocess-driven behavior change. (US1.AC3)
- **SC-4**: A regenerated tracked `.g.dart` (exists pre and post) is never
  reported or rewritten by the guard. (US1.AC4)
- **SC-5**: Gate failure for a tracked missing part contains
  `git checkout -- <path>`; for an untracked missing part it does not.
  (US2.AC1/AC2)
- **SC-6**: In a TddFixture, fake-zfa deletion of a tracked placeholder is
  undone by the refactor build pass; action output records the restoration;
  run exits 0 with the file present. (US3.AC1/AC3)
- **SC-7**: Forced restore failure in the fixture stops the registry
  (`failedPass: build`), prints the refusal + remedy, exits non-zero.
  (US3.AC2)
- **SC-8**: The docs page contains exclusion YAML for
  `json_serializable` and `source_gen:combining_builder`.
- **SC-9**: Full suite (`dart test`) green; `dart analyze` reports no new
  warnings on changed files; `dart format` clean on `lib` and `test`.

## Key Entities

- **Tracked generated-name file**: a `.g.dart` / `.zorphy.dart` path present
  in git's index. May be a legitimate generator output (produced this build)
  or a hand-authored placeholder (no producing generator run).
- **Hand-authored placeholder**: a generated-name file whose producing
  generator never runs for its owning library; indistinguishable from an
  orphaned output by filename, distinguishable by git tracking.
- **Pre-build snapshot**: map of project-relative path → exact bytes, taken
  before build_runner runs, containing only tracked ∧ existing files.
- **Restoration**: writing captured pre-build bytes back to the deleted
  path; distinct from `git checkout`, which would drop unstaged edits.

## Assumptions & Out of Scope

- build_runner's deletion happens inside the child process; `zfa` cannot
  prevent it, only detect and recover. (Consistent with the constraint not
  to touch build_runner internals.)
- Untracked generated-name files are not protected (no signal to
  distinguish placeholder from scratch output).
- Files removed from the index by the user (`git rm` staged) are deletions
  the user intends — the guard must not resurrect them.
- No change to build.yaml defaults, builder configs, or generator behavior.
