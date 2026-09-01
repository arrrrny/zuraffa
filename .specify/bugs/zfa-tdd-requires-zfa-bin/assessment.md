# Bug Assessment: zfa tdd commands require explicit --zfa-bin on new projects

- **Slug**: zfa-tdd-requires-zfa-bin
- **Created**: 2026-09-01
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> when using zfa tdd on a new project, to use the binary it still requires --zfa-bin explicitly it is cumbersome. zfa tdd commands should work directly without requirement of --zfa-bin to use zfa compiled binary. the whole process should be seamless.

## Symptom

When running `zfa tdd run` (or other TDD sub-commands) against a project that is a fresh checkout or install of zuraffa — where `zfa` may not yet be on PATH — the driver fails because the entrypoint resolution falls through every fallback:

1. `--zfa-bin` is not passed → skipped.
2. `Platform.script` resolves to a `file://` path not ending in `zfa.dart` or `zuraffa.dart` (e.g., the test runner or a compiled snapshot) → skipped.
3. `zfa` is not found on PATH → throws `PipelineResolutionError` with the message: *"cannot resolve the zfa entrypoint. The command needs to invoke `zfa entity create` / `zfa make` / `zfa build` as sub-processes, but neither --zfa-bin, Platform.script (running from source), nor `zfa` on PATH resolved."*

The user is forced to pass `--zfa-bin <path>` every time, which is cumbersome and defeats the "seamless" UX goal.

## Reproduction

1. On a machine or in an environment where `zfa` is not on PATH (e.g., after `dart pub global activate zuraffa` or a fresh clone without a PATH-wrapped install).
2. Run `zfa tdd run <some-feature>` without `--zfa-bin`.
3. Observe: `PipelineResolutionError: cannot resolve the zfa entrypoint …`

The same applies to `zfa tdd make`, `zfa tdd verify`, `zfa tdd corpus run`, and any other command that spawns the `zfa` CLI as a subprocess.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/pipeline_runner.dart:149–203` (`_resolveEntrypoint`) — the three-tier fallback chain; the PATH lookup is the last resort and throws when `zfa` is absent.
- `lib/src/plugins/tdd/services/step_runner.dart:87–107` (`StepRunner.defaultZfaBin`) — uses `Isolate.resolvePackageUri` for `package:zuraffa/src/zfa_cli.dart` → derives `bin/zfa.dart`. Works when the package is on the package path but fails with the same "not on package path" error when invoked from a compiled binary or an environment without `zfa` on PATH.
- `lib/src/plugins/tdd/commands/run_command.dart:146` — passes `zfa-bin` option value to `StepRunner`.
- `lib/src/plugins/tdd/commands/run_command.dart:100–105` — `--zfa-bin` option defined here.
- `lib/src/plugins/tdd/services/corpus_step_runner.dart:72–81` — `CorpusStepRunner` defaults to `StepRunner.defaultZfaBin` as its `_entryResolver`.

## Root Cause Hypothesis

Two separate but related resolution strategies both fail in the same way for the same root cause:

1. **`PipelineRunner`** (used by `make`, `gen`, `verify`, etc.): The three-tier fallback (`--zfa-bin` override → `Platform.script` → PATH `zfa`) has no working fallback when the CLI runs as a compiled snapshot or when `zfa` is not on PATH. There is no attempt to resolve the entrypoint using the same mechanism that launched the current process (e.g., `Platform.resolvedExecutable` + `Platform.script` path).

2. **`StepRunner`** (used by `run` command to spawn step sub-processes): Uses `Isolate.resolvePackageUri('package:zuraffa/src/zfa_cli.dart')` which requires the package to be on the package path — not true when the CLI is installed globally or run as a compiled binary.

Confidence: **high**. The fix is well-understood: when neither `--zfa-bin` nor `Platform.script` ending in `zfa.dart`/`zuraffa.dart` nor PATH `zfa` resolves, fall back to `Platform.resolvedExecutable` (the Dart VM or compiled AOT binary) with the script path from `Platform.script`. This is exactly what the `Platform.script` branch already does for source-run cases, but it only triggers when the script basename is `zfa.dart` or `zuraffa.dart`. When running from a compiled snapshot or a global activate, `Platform.script` points elsewhere (e.g., the engine binary), so the PATH fallback is the only option — and if `zfa` is not on PATH, everything fails.

## Proposed Remediation

**Preferred**: Extend `PipelineRunner._resolveEntrypoint` to add a fourth fallback tier using `Platform.resolvedExecutable` + the script path from `Platform.script`, mirroring what the `Platform.script` branch already does for source runs. Specifically, when the PATH lookup fails, check whether `Platform.script` is a `file://` URL at all — if it is, invoke `dart <Platform.script.path>` even if the basename is not `zfa.dart`. This handles the compiled-snapshot / global-activate case:

```
dart $(which zuraffa_run) tdd ...
```

or more precisely:

```
${Platform.resolvedExecutable} ${Platform.script.toFilePath()} tdd ...
```

For `StepRunner.defaultZfaBin`, the `Isolate.resolvePackageUri` approach should be replaced with the same `Platform.script` + `Platform.resolvedExecutable` strategy, since the package-path resolution is unreliable when the CLI is installed globally or compiled.

**Alternative 1**: Add a machine-level config file (e.g., `~/.zuraffa/zfa-bin`) that `PipelineRunner` and `StepRunner` consult before throwing. Write it on first run or on `zfa setup`. Trade-off: introduces global state and a new file to manage.

**Alternative 2**: Always pass the resolved entrypoint down from the top-level `zfa` CLI to sub-commands via a shared service that captures it once at startup. Trade-off: requires architectural change to the plugin initialization.

**Files likely to change**:
- `lib/src/plugins/tdd/services/pipeline_runner.dart`
- `lib/src/plugins/tdd/services/step_runner.dart`

**Tests to add or update**:
- `test/plugins/tdd/services/step_runner_test.dart` — add a test where `zfa` is absent from PATH and `Platform.script` points at a non-`zfa.dart` path, verifying the fallback to `Platform.resolvedExecutable` + script path.
- `test/plugins/tdd/services/pipeline_runner_test.dart` — cover the same scenario.

## Risks & Considerations

- **API breakage**: None — this is purely an internal resolution improvement; no public API changes.
- **Performance**: The extra PATH lookup is already there; adding one more fallback check before throwing adds negligible cost.
- **Windows**: `Platform.resolvedExecutable` and `Platform.script` work on Windows. The PATH lookup already handles Windows `PATHEXT`. The new fallback should be tested on Windows.
- **Security**: No new code execution paths — the resolved executable is always either the one the user passed, the one already on PATH, or the one currently running.
- **Observability**: The error message when resolution fails should remain informative; the new fallback should include its own error message if it also fails.

## Open Questions

- [NEEDS CLARIFICATION: Is `zfa` expected to be on PATH for all normal installations, or is running from a fresh `dart pub global activate` without PATH wrapping a supported use case?]
- [NEEDS CLARIFICATION: Should the fix also apply to `CorpusStepRunner`, or is that only used in test/development contexts where `zfa` on PATH is always true?]
