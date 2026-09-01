# Bug Assessment: zfa tdd verify-red should not require --project (should default to CWD)

- **Slug**: tdd-verify-red-requires-project-flag
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/679
- **Verdict**: valid
- **Severity**: low

## Report (verbatim or summarized)

Running `zfa tdd verify-red` (and other TDD sub-commands) requires `--project` to be passed explicitly, even though the code already defaults to `Directory.current.path` when `--project` is absent. The user still felt `--project .` was necessary — suggesting either the default is not working in some scenarios, or the UX is unclear about when it is needed.

Expected: `zfa tdd verify-red U1 --feature 001-permission-port` works from within the project directory without `--project`, matching other `zfa` commands that auto-detect the project root.

## Symptom

All TDD sub-commands (`verify-red`, `make`, `run`, `gen`, `refactor`, `verify`, `func`, `wire`, `compose`, `plan`, `init`, and all `corpus_*` commands) default `--project` to `Directory.current.path` rather than auto-detecting the project root by walking up for `pubspec.yaml`. This means:
- Running from a subdirectory of the project resolves the wrong root.
- `Directory.current` pointing unexpectedly (deleted temp dir under `dart test`, chdir in CI/containers) resolves to a wrong/invalid location.
- The UX implies `--project` is required even when it is not.

## Reproduction

1. `cd` into a subdirectory of a zuraffa project.
2. Run `zfa tdd verify-red <behavior> --feature <feature>` (no `--project`).
3. Observe the command resolves the wrong project root (or fails).

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/verify_red_command.dart:104-110` — defaults to `Directory.current.path`.
- `lib/src/plugins/tdd/commands/verify_command.dart:72-77` — same pattern.
- `lib/src/plugins/tdd/commands/init_command.dart:44-49` — same pattern.
- `lib/src/plugins/tdd/commands/func_command.dart:109`, `wire_command.dart:132`, `compose_command.dart:132`, `run_command.dart`, `make_command.dart`, `corpus_run_command.dart:92`, `corpus_status_command.dart:63`, `corpus_step_runner.dart` — same pattern across the TDD command surface.
- `lib/src/commands/make_command.dart:121-127` — `_findProjectRoot()` already routes through `ProjectRoot.find()`, which tolerates an invalid CWD (issue #441). This is the pattern to replicate.
- `lib/src/generator/code_generator.dart:246` — `ProjectRoot.find(startPath)` walks up for `pubspec.yaml`.

## Root Cause Hypothesis

Every TDD command defaults `--project` to `Directory.current.path` instead of routing through `ProjectRoot.find()`. `ProjectRoot.find()` already exists and is proven (used by `make_command.dart`); it walks up from CWD looking for `pubspec.yaml` and tolerates an invalid CWD. The TDD commands simply never adopted it. Confidence: **high** — the helper exists and the pattern is a one-line swap per command.

## Proposed Remediation

**Preferred**: Replace every `--project` default of the form
```dart
final projectRoot = args['project'] as String? ?? Directory.current.path;
```
with a call to the existing auto-detection helper:
```dart
final projectRoot = args['project'] as String? ?? ProjectRoot.find();
```
across all TDD commands (`verify_red_command.dart`, `verify_command.dart`, `init_command.dart`, `func_command.dart`, `wire_command.dart`, `compose_command.dart`, `run_command.dart`, `make_command.dart`, `corpus_run_command.dart`, `corpus_status_command.dart`, and any other TDD command that defaults to `Directory.current.path`).

This makes the project root self-discoverable even when the command is run from a subdirectory, or when `Directory.current` points unexpectedly to a different location — matching the behavior of `zfa make`.

**Files likely to change**:
- All `lib/src/plugins/tdd/commands/*.dart` that default `--project` to `Directory.current.path`
- `lib/src/plugins/tdd/services/corpus_step_runner.dart` (if it passes `Directory.current.path` through)
- `lib/src/plugins/tdd/services/mutation_verifier.dart:140` (if `workingDirectory ?? Directory.current.path` should also auto-detect)

**Tests to add or update**:
- `zfa tdd verify-red <behavior> --feature <feature>` works from a subdirectory without `--project`
- `zfa tdd run/make/verify/init` work from a subdirectory without `--project`
- Regression: explicit `--project <dir>` still overrides auto-detection
- Invalid CWD (deleted temp dir) does not throw `PathNotFoundException` (issue #441 parity)

## Risks & Considerations

- `ProjectRoot.find()` may walk up past the intended project if there is no `pubspec.yaml` in the chain — ensure it falls back to `Directory.current.path` when nothing is found (verify the existing behavior).
- Changing defaults across ~12 commands is broad; keep the change mechanical (one-line swaps) and run the full suite.

## Open Questions

- None blocking.