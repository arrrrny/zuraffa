# Bug Issue: zfa tdd requires explicit --zfa-bin on new projects (not seamless)

- **Slug**: tdd-zfa-bin-required-on-new-projects
- **Fetched**: 2026-09-01
- **Issue**: 665
- **URL**: https://github.com/arrrrny/zuraffa/issues/665
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

When running `zfa tdd` commands (e.g., `zfa tdd run`, `zfa tdd make`, `zfa tdd verify`) against a project that is a fresh checkout or install, the commands fail because the zfa binary entrypoint cannot be resolved automatically. Users are forced to pass `--zfa-bin <path>` explicitly every time, which is cumbersome and defeats the "seamless" UX goal.

## Steps to Reproduce

1. On a machine or in an environment where `zfa` is not on PATH (e.g., after `dart pub global activate` without PATH wrapping, or a fresh clone).
2. Run `zfa tdd run <feature>` without `--zfa-bin`.
3. Observe: `PipelineResolutionError: cannot resolve the zfa entrypoint. The command needs to invoke \`zfa entity create\` / \`zfa make\` / \`zfa build\` as sub-processes, but neither --zfa-bin, Platform.script (running from source), nor \`zfa\` on PATH resolved.`

## Root Cause

There are two separate but related resolution strategies:

1. **PipelineRunner** (used by `make`, `gen`, `verify`): Uses a three-tier fallback (`--zfa-bin` → `Platform.script` ending in `zfa.dart`/`zuraffa.dart` → PATH `zfa`). When running from a compiled snapshot or global activate, `Platform.script` points elsewhere, and if `zfa` is not on PATH, everything fails with no further fallback.

2. **StepRunner** (used by `run` command): Uses `Isolate.resolvePackageUri('package:zuraffa/src/zfa_cli.dart')` which requires the package to be on the package path — not true when the CLI is installed globally or run as a compiled binary.

## Proposed Fix

Extend the resolution chain to use `Platform.resolvedExecutable` + `Platform.script.toFilePath()` as a final fallback, regardless of whether the script basename is `zfa.dart`. This mirrors the source-run case but catches the compiled-snapshot and global-activate scenarios too.

Files to change:
- `lib/src/plugins/tdd/services/pipeline_runner.dart` — add fallback using `Platform.resolvedExecutable` + `Platform.script`
- `lib/src/plugins/tdd/services/step_runner.dart` — replace `Isolate.resolvePackageUri` with the same `Platform.script` + `Platform.resolvedExecutable` strategy

## Severity

medium (UX degradation; forces verbose `--zfa-bin` on every command)

## Comments

None.