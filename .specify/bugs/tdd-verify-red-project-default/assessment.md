# Bug Assessment: zfa tdd verify-red defaults to CWD but user had to pass --project .

- **Slug**: tdd-verify-red-project-default
- **Created**: 2026-09-01
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: low

## Report (verbatim or summarized)

> it should not require --project either, by default it should work on current folder just like other zfa commands
>
> ```
> zfa tdd verify-red U1 --feature 001-permission-port --project .
> ```

## Symptom

When running `zfa tdd verify-red` without `--project`, the command defaults to `Directory.current.path` — meaning it **should** already work on the current folder. However, the user felt compelled to pass `--project .` explicitly, which is redundant and suggests the defaulting is either not working as expected or the UX is confusing. The user expects `--project` to be unnecessary for commands run from within the project directory, just like other `zfa` commands.

## Reproduction

1. `cd` into a project directory that contains `specs/`, `test/`, and `.specify/`.
2. Run `zfa tdd verify-red U1 --feature <feature-name>` (without `--project`).
3. [NEEDS CLARIFICATION: Does this succeed or fail? If it fails, what is the error? If it succeeds, why did the user feel `--project .` was necessary?]

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/verify_red_command.dart:107–110` — the project root is resolved as `projectFlag ?? Directory.current.path`. This is correct in principle. The root cause may be that the command was run from the wrong directory, or that the user habitually passes `--project` from another workflow.
- `lib/src/plugins/tdd/commands/init_command.dart:46–49` — same defaulting pattern.
- All other TDD commands (`make`, `run`, `gen`, `refactor`, `verify`, `func`, `wire`, `compose`, `plan`, `corpus_*`) — all use the same `projectFlag ?? Directory.current.path` pattern (confirmed by grep across all TDD command files).

## Root Cause Hypothesis

Confidence: **low** — the code already defaults to `Directory.current.path`, so the bug is not a missing default. The actual root cause is unclear without more information.

Possibilities:
1. The command was run from outside the project directory (e.g., from a parent directory or a CI environment with a different CWD).
2. The command was run with an absolute path that the user interpreted as needing `--project .` for some reason.
3. There is a genuine case where `Directory.current.path` points to the wrong location in a nested/inherited process scenario (e.g., when the CLI is invoked from a build script or test harness that changes CWD).

If option 3 is the cause, the fix would be to auto-detect the project root by walking up from CWD for a `pubspec.yaml` file, similar to how `zfa make` uses `_findProjectRoot()`. This would be more robust than relying on CWD.

## Proposed Remediation

**Preferred** (if root cause is option 3 — CWD unpredictability):

Add a `_findProjectRoot(String cwd)` helper to the TDD commands that walks up from `cwd` looking for `pubspec.yaml`, similar to `lib/src/commands/make_command.dart:121`'s `_findProjectRoot()`. Use this instead of raw `Directory.current.path` when `--project` is absent. This makes the project root self-discoverable, regardless of where the command is invoked from.

**Alternative** (if the issue is purely UX/expectation):

Improve the help text to clearly state the default is CWD, and add a validation that fails fast with a clear message when `pubspec.yaml` is not found in the resolved project root — reducing confusion about why the command might fail silently or unexpectedly.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/verify_red_command.dart` — add project-root auto-detection.
- Or (simpler): all TDD commands that share this pattern, if a shared base/service exists.
- `lib/src/commands/make_command.dart:121` — reference `_findProjectRoot()` for the auto-detection pattern to mirror.

**Tests to add or update**:
- A test for `verify-red` (and other TDD commands) that runs without `--project` from a subdirectory of the project root, verifying it correctly walks up to find `pubspec.yaml`.

## Risks & Considerations

- **Regression risk**: Changing how the project root is resolved could break existing workflows that rely on CWD defaulting. Must verify that the walk-up behavior is equivalent for the common case (running from the project root).
- **Performance**: Walking up the directory tree is O(depth) but typically terminates within 1–3 levels. Negligible cost.
- **Windows**: `pubspec.yaml` is the marker on all platforms; no platform-specific handling needed.

## Open Questions

- [NEEDS CLARIFICATION: Did `zfa tdd verify-red U1 --feature 001-permission-port` (without `--project .`) actually fail, and if so, with what error?]
- [NEEDS CLARIFICATION: Was the command run from within the `zuraffa_permissions` project directory?]
- [NEEDS CLARIFICATION: Is this related to the `--zfa-bin` / `--project` issue in the previous bug assessment (`zfa-tdd-requires-zfa-bin`)?]
