# Bug Assessment: zfa tdd verify-red should not require --project (should default to CWD)

- **Slug**: tdd-verify-red-project-default-679
- **Created**: 2026-09-01T00:00:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/679
- **Verdict**: valid
- **Severity**: low

## Report (verbatim or summarized)

Issue #679 reports that `zfa tdd verify-red` (and other TDD sub-commands) require an explicit `--project .` flag even when run from within the project directory. The author notes the code defaults to `Directory.current.path` but the UX is unclear. The proposed fix is to add auto-detection by walking up for `pubspec.yaml`, mirroring `zfa make`'s existing `_findProjectRoot()`.

URL policy: `github.com` — allowlisted, fetched successfully.

## Symptom

When `zfa tdd verify-red` (and all other TDD commands) are invoked without `--project`, they fall back to `Directory.current.path` rather than auto-detecting the project root. This is fragile when `Directory.current` points to an unexpected location (e.g., a contaminated CWD from concurrent tests, CI containers, or a deleted temp dir). In contrast, `zfa make` already uses `ProjectRoot.find()` which robustly walks up from CWD looking for `pubspec.yaml`, making it immune to CWD contamination.

## Reproduction

1. Run `zfa tdd verify-red U1 --feature 001-permission-port` from the project root (without `--project`).
2. Observe whether it succeeds. If `Directory.current` is contaminated (e.g., a test runner changed it to a temp dir), the command looks for `specs/` in the wrong location and fails.
3. Workaround: pass `--project .` explicitly.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/verify_red_command.dart:110–113` — `final cwd = projectFlag != null && projectFlag.isNotEmpty ? p.absolute(projectFlag) : Directory.current.path;`
  Uses bare `Directory.current.path` as the fallback instead of a robust project-root finder.
- `lib/src/plugins/tdd/commands/make_command.dart:136–139` — same pattern: `final cwd = projectFlag != null && projectFlag.isNotEmpty ? p.absolute(projectFlag) : Directory.current.path;`
  All other TDD commands share the identical pattern (confirmed by code review).
- `lib/src/commands/make_command.dart:121–127` — `_findProjectRoot()` wraps `ProjectRoot.find()`, which walks up from CWD for `pubspec.yaml`. This is the established pattern to mirror.
- `lib/src/core/project/project_root.dart:45–68` — `ProjectRoot.find()` is the robust, already-tested project-root resolver that tolerates an invalid CWD (fallback to `PWD` env var, then `Platform.script`).

## Root Cause Hypothesis

**Confidence: high.**

All TDD commands use `Directory.current.path` as the implicit `--project` default. `Directory.current` is a process-global, mutable value — any concurrent test or subprocess that calls `Directory.current = ...` poisons it for all subsequent operations in the same isolate. When this happens, TDD commands look for `specs/`, `test/`, and `.specify/` in the wrong directory and fail silently or with confusing errors.

`zfa make` already avoids this via `ProjectRoot.find()`, which:
1. Falls back to `$PWD` if `Directory.current` throws `PathNotFoundException`.
2. Walks up the directory tree from the resolved start point looking for `pubspec.yaml`.

The TDD commands need the same treatment. There is no existing `ProjectRoot.find()` call anywhere in the TDD plugin — the bug is an omission, not a design error.

## Proposed Remediation

**Preferred**: Replace `Directory.current.path` with `ProjectRoot.find()` as the implicit default in all TDD commands that take `--project`, mirroring `MakeCommand._findProjectRoot()`.

Specifically, add `import 'package:zuraffa/src/core/project/project_root.dart';` and replace:

```dart
final cwd = projectFlag != null && projectFlag.isNotEmpty
    ? p.absolute(projectFlag)
    : Directory.current.path;
```

with:

```dart
final cwd = projectFlag != null && projectFlag.isNotEmpty
    ? p.absolute(projectFlag)
    : ProjectRoot.find();
```

This applies to: `verify_red_command.dart`, `make_command.dart` (in the TDD plugin), `run_command.dart`, `gen_command.dart`, `refactor_command.dart`, `verify_command.dart`, `func_command.dart`, `wire_command.dart`, `compose_command.dart`, `plan_command.dart`, `init_command.dart`, and all `corpus_*` commands.

**Alternatives**:
- **Option A (minimal)**: Fix only `verify-red` (the reported command). The other TDD commands would remain inconsistent but functional.
- **Option B (refactor)**: Extract a shared `TddProjectRoot` helper or base class that all TDD commands inherit, so the fix is applied in one place. This avoids repeating the pattern across 10+ command files.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/verify_red_command.dart` — add import and replace `Directory.current.path` fallback.
- `lib/src/plugins/tdd/commands/make_command.dart` (tdd plugin) — same change.
- Likely all other TDD command files under `lib/src/plugins/tdd/commands/`.
- `test/plugins/tdd/verify_red_command_test.dart` — add a test case for running without `--project` from a subdirectory.

**Tests to add or update**:
- A test that calls `verify-red` (and/or `make`) without `--project` from a subdirectory, confirming it walks up to find the project root.
- A test that confirms the command tolerates a contaminated `Directory.current` (deleted temp dir) and still resolves correctly via `ProjectRoot.find()`.

## Risks & Considerations

- **Regression risk: low.** `ProjectRoot.find()` walks up from `Directory.current.path` by default — for the common case (running from the project root), it finds `pubspec.yaml` immediately and returns the same path as the old code. Behavior is identical in the happy path.
- **Performance: negligible.** The walk terminates at the first `pubspec.yaml` found, typically at depth 0–2.
- **No API breakage.** `--project` still works as before. The change only affects the implicit default.
- **Scope.** All TDD commands need this fix; doing it piecemeal leaves the inconsistency in place.

## Open Questions

- [RESOLVED: The default uses `Directory.current.path` — confirmed by code. The fix is to replace it with `ProjectRoot.find()`.]
- [RESOLVED: `zfa make`'s `_findProjectRoot()` calls `ProjectRoot.find()` — the pattern to mirror is `lib/src/commands/make_command.dart:121–127`.]
- [NEEDS CLARIFICATION: Is there a shared TDD command base class or mixin that all TDD commands inherit from? If so, the fix could be applied in one place rather than per-command.]
