# Bug Assessment: zfa tdd run: cannot resolve zfa entrypoint, requires --zfa-bin

- **Slug**: tdd-run-cannot-resolve-entrypoint
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/690
- **Verdict**: valid
- **Severity**: high

## Report

`zfa tdd run` fails immediately with "cannot resolve the zfa entrypoint (package:zuraffa is not on the package path)". User must pass `--zfa-bin` explicitly.

## Symptom

`zfa tdd run <feature>` exits 2 right after `zfa setup` + `zfa tdd init`, before any TDD work happens.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/step_runner.dart` — uses `Isolate.resolvePackageUri('package:zuraffa/src/zfa_cli.dart')` which fails when the CLI is installed globally or run as a compiled binary.

## Root Cause Hypothesis

The entrypoint resolution relies on package-URI resolution, which fails when `zfa` is installed as a system binary (not a source checkout). The system `zfa` at `~/.local/bin/zfa` is not on the package path. Confidence: **high**.

## Proposed Remediation

Use the same `Platform.resolvedExecutable` + `Platform.script.toFilePath()` final fallback that #665 introduced for `pipeline_runner.dart` and `step_runner.dart`. Use the system-installed `zfa` binary directly.

## Open Questions

- None blocking.