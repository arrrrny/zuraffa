# Implementation Plan: Protect git-tracked hand-authored `.g.dart` placeholders (restore-or-refuse)

**Branch**: `feat/1540-protect-git-tracked-g.dart-from-build`
**Spec**: `specs/1540-protect-git-tracked-g-dart-from-build/spec.md`
**Status**: Complete

## Technical Context

**Language/Version**: Dart 3.x (SDK constraint in `pubspec.yaml`), pure
`dart:io` — no new dependencies.

**Primary components touched** (this is the full blast radius):

1. `lib/src/commands/build_command.dart` — `BuildCommand.run()`:
   the build step. Invokes `dart run build_runner build` via `_runBuild()`
   (initial + clean-cache retry, issue #1303), then runs the completeness
   gates: `verifyOutputsOrFail` (total-zero, zuraffa#276),
   `verifyDeclaredPartsOrFail` (per-file missing declared part, zuraffa#379),
   `verifyAnalyzeOrFail` (issue #395/#1035).
2. `lib/src/plugins/tdd/services/refactor_passes.dart` — `RefactorPasses`:
   the fixed pass registry (build → format → fix) executed by
   `zfa tdd refactor`; per-pass `TreeSnapshot` before/after of `lib/`;
   misfire-stop on first failing pass (spec 048 FR-010).
3. `lib/src/plugins/tdd/commands/refactor_command.dart` — consumes
   `RefactorPassesResult`; prints the misfire-stop block; runs the
   attribution check (FR-005: every changed `lib/` path must be attributable
   to a recorded action).
4. NEW `lib/src/core/generation/tracked_generated_output_guard.dart` — the
   shared snapshot/restore/refusal service (neutral home: `core/generation/`;
   `plugins/` never imports `src/commands/`, so the guard cannot live under
   `commands/`).
5. NEW `docs/hand-authored-g-dart-placeholders.md` — the pattern doc
   (FR-9).

**Root cause chain** (issue #1540):

```
build_runner build
  └─ json_serializable reserves <lib>.g.dart for EVERY library in generate_for
     (root build.yaml / scaffolded build.yaml: lib/src/**, test/**)
  └─ pre-existing hand-authored engine_event.g.dart has NO producing
     generator run this build → classified stale/orphaned output
  └─ build_runner cleanup DELETES it (cannot be prevented from outside —
     hard constraint forbids touching build_runner internals)
  └─ engine_event.dart declares `part 'engine_event.g.dart';`
  └─ verifyDeclaredPartsOrFail: declared part missing → gate fails → exit 1
  └─ zfa tdd refactor: build pass exit ≠ 0 → misfire-stop (FR-010)
  └─ loop dead-ends; tree broken; no remedy named anywhere
```

**Existing conventions this plan reuses**:

- `@visibleForTesting` gates with `projectRoot:` parameter (temp-dir
  testable, no `Directory.current` mutation) — see
  `test/commands/build_command_unit_test.dart`.
- `TddFixture` + `writeFakeZfaBin(sideEffectByArgv:)` for CLI-surface
  refactor tests (`test/plugins/tdd/refactor_command_test.dart` pattern).
- `ProcessRunOutcome`/`RefactorAction` carry pass `output` — restoration
  evidence rides this existing field (no new evidence plumbing).
- `verifyDeclaredPartsOrFail` is called synchronously by existing tests →
  the gate's git check MUST stay sync (`Process.runSync`, failure path only).
- AGENTS.md: CI enforces `dart format --set-exit-if-changed lib test`.

## Constitution Check (project conventions)

- Generation contract untouched: `zfa build` still delegates to
  build_runner; the guard only wraps the invocation with snapshot/restore.
- No `Directory.current` mutation: all new filesystem operations root at an
  explicit `projectRoot` (refactor command passes its resolved `cwd`;
  build command passes `ProjectRoot.safeCurrentPath()`).
- Stop-on-roadblock honesty: refusal paths exit non-zero and name the
  remedy — never silently "succeed" with a broken tree.

## Technical Decisions

### D1 — Restore writes captured bytes, not `git checkout`

`git checkout -- <path>` restores the INDEX content, silently dropping
unstaged hand edits to the placeholder. The guard captures bytes pre-build
and writes them back — restoration is exact to what existed before the
build. `git` is used read-only (`git ls-files -z`) to establish tracking.

### D2 — Snapshot semantics: tracked ∧ exists, deletions only

- Membership = in `git ls-files` output AND `File.existsSync()` at capture
  time. A file the user staged for removal (`git rm`) is not in the index →
  not protected (intended deletion, FR/assumption). A file the user deleted
  unstaged pre-build doesn't exist at capture → not protected.
- Trigger = member absent at post-build detection. Regenerated files exist
  post-build → never flagged (SC-4); modified-in-place files → never
  flagged (content untouched).
- Suffixes: `.g.dart`, `.zorphy.dart` — the two generated-name conventions
  the build already special-cases (`verifyDeclaredPartsOrFail`,
  `hasGeneratedOutputs`).

### D3 — Guard disabled outside git

`git ls-files` failure (not a repo, no git binary, corrupt repo) ⇒ empty
tracking set ⇒ empty snapshot ⇒ no detection, no messages, no subprocess
added to the failure path. Non-git projects (the test fixtures' default!)
keep byte-identical behavior.

### D4 — Ordering in `RefactorPasses.run()` (attribution safety)

For the `build` pass: capture guard snapshot BEFORE executor.run; restore
immediately AFTER executor.run and BEFORE the pass's after-snapshot. A
successful restoration then leaves before/after fingerprints identical —
`filesChanged` unchanged, command-level attribution check unaffected
(US3.AC3). The restoration is recorded as text appended to the action's
`output` (printed pass record + cycle-log evidence). Restore failure ⇒
registry returns `stopped: true, failedPass: 'build'` plus a new
`refusalReason` naming the remedy; the refactor command prints it in the
existing misfire-stop block.

### D5 — Gate remedy stays sync

`verifyDeclaredPartsOrFail` keeps `bool` signature. On
`missing.isNotEmpty` it runs ONE `Process.runSync('git', ['-C', root,
'ls-files', '-z'])` and prints, per tracked missing path, the
`git checkout -- <path>` remedy + doc reference. Untracked paths: message
unchanged. This covers the stale-zfa-binary case where the refactor-side
guard (running in the newer CLI) still protects the tree, and any
future regression in the pre/post layer.

### D6 — Docs + remedy strings reference one path

`docs/hand-authored-g-dart-placeholders.md` is the single documentation
target; all restore/refusal messages print it. The doc carries the exact
two-builder exclusion YAML from the issue workaround.

## Project Structure

```
lib/src/core/generation/tracked_generated_output_guard.dart   # NEW service
lib/src/commands/build_command.dart                           # wire guard + gate remedy
lib/src/plugins/tdd/services/refactor_passes.dart             # build-pass restore-or-refuse
lib/src/plugins/tdd/commands/refactor_command.dart            # print refusal reason
docs/hand-authored-g-dart-placeholders.md                     # NEW pattern doc
specs/1540-protect-git-tracked-g-dart-from-build/…            # spec artifacts
test/core/generation/tracked_generated_output_guard_test.dart # NEW unit (fast)
test/commands/build_command_tracked_outputs_test.dart         # NEW gate/build wiring (fast)
test/plugins/tdd/bug_1540_refactor_tracked_restore_test.dart  # NEW CLI surface (slow)
```

## Testing Strategy

- **Unit (fast)**: guard semantics (tracking parse, membership, byte
  restore, failure reporting, disabled-outside-git) against real temp git
  repos (`git init` in system-temp sandboxes; tests `skip` when git is
  unavailable). No build_runner subprocess.
- **Gate (fast)**: `verifyDeclaredPartsOrFail` tracked-vs-untracked remedy
  assertions via `capturePrint` (build_command_unit_test pattern).
- **CLI surface (slow)**: TddFixture + fake zfa that deletes the tracked
  placeholder (side-effect scripts); asserts restoration, refusal, exit
  codes, summary-line contract (FR-009).
- **Red-first**: tests land against no-op stubs; the recorded red run shows
  behavior-level failures (not compile errors) before implementation.

## Risks / Mitigations

| Risk | Mitigation |
| --- | --- |
| Guard misfires on huge repos (byte snapshot of many files) | Generated-name files are bounded text parts; capture reads only tracked ∧ existing members; one `git ls-files` subprocess |
| Unstaged deletion by user resurrected | Membership requires existence at capture time (D2) |
| Restore loop (build deletes every run) | Restore + explicit recurring-deletion remedy (both builder excludes) printed on every restore; docs explain how to stop it |
| Attribution false-positive after restore | Restore before after-snapshot (D4) |
| Sync gate blocks on git | One `Process.runSync` only on the already-failing path; git absent ⇒ skip (D3) |
