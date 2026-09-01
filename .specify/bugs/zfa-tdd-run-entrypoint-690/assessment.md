# Bug Assessment: zfa tdd run: cannot resolve zfa entrypoint, requires --zfa-bin

- **Slug**: zfa-tdd-run-entrypoint-690
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/690
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

`zfa tdd run <feature>` fails immediately with exit code 2 and the error:
"cannot resolve the zfa entrypoint (package:zuraffa is not on the package path); pass --zfa-bin explicitly."
After `zfa setup` and `zfa tdd init`, the `run` command should work without extra flags. The workaround (`--zfa-bin /Users/ahmettok/.local/bin/zfa`) is acceptable for developers but not for seamless first-run UX.

Source: [github.com/arrrrny/zuraffa/issues/690](https://github.com/arrrrny/zuraffa/issues/690)

## Symptom

`zfa tdd run` exits with code 2 before executing any TDD step. The sub-process spawn inside `StepRunner.run()` calls `defaultZfaBin()` to resolve the `zfa` entrypoint. That resolution fails because every tier falls through and the `Isolate.resolvePackageUri` fallback (the last resort) also fails — the package is not on the package path in the environment created by `zfa setup`.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec into `specs/`
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd run 001-app-bootstrap`
   → exit 2: `cannot resolve the zfa entrypoint; pass --zfa-bin explicitly`

## Suspected Code Paths

- `lib/src/plugins/tdd/services/step_runner.dart:99–134` (`StepRunner.defaultZfaBin`) — the 3-tier resolution chain; the `Isolate.resolvePackageUri` fallback (tier 3, line 115–122) throws when `package:zuraffa` is not on the package path. This is the direct source of the error message.
- `lib/src/plugins/tdd/services/step_runner.dart:148` — `run()` calls `defaultZfaBin()` without a `zfaBin` override, triggering the broken chain.
- `lib/src/plugins/tdd/commands/run_command.dart:146` — passes `--zfa-bin` from the CLI option to `StepRunner`.
- `lib/src/plugins/tdd/services/pipeline_runner.dart:154–222` (`_resolveEntrypoint`) — parallel resolver used by `zfa tdd make`, `gen`, `verify`; has a 4th tier using `Platform.resolvedExecutable` (line 205–211) that `StepRunner` lacks. This is the structural mismatch.

## Root Cause Hypothesis

`StepRunner.defaultZfaBin()` implements a 3-tier resolution chain (direct Platform.script → derived `bin/zfa.dart` path → `Isolate.resolvePackageUri` fallback), while `PipelineRunner._resolveEntrypoint()` already has a 4th tier: `Platform.resolvedExecutable` + `Platform.script.toFilePath()`. When `zfa` is not on PATH and `Platform.script` does not resolve to `zfa.dart`/`zuraffa.dart`, `StepRunner` reaches `Isolate.resolvePackageUri` as its last resort — which fails when `package:zuraffa` is not on the package path (compiled snapshot or global-activate context). The `PipelineRunner` avoids this by falling back to `${Platform.resolvedExecutable} ${Platform.script}` as a 4th tier.

Confidence: **high**. The error message string (`step_runner.dart:120`) matches verbatim. The structural gap (StepRunner missing the Platform.resolvedExecutable tier) is confirmed by reading both files.

## Proposed Remediation

**Preferred**: Mirror the `PipelineRunner` 4th-tier fallback into `StepRunner.defaultZfaBin()`. After the `Isolate.resolvePackageUri` block (tier 3), if `Platform.script` is a `file://` URL, return `${Platform.resolvedExecutable} ${Platform.script.toFilePath()}` — the same Dart VM/binary that is currently running, pointed at the current script. This handles the compiled-snapshot / global-activate case without requiring the package to be on the package path.

```dart
// Add as tier 4 after line 133 (before the closing brace of defaultZfaBin):
// Tier 4: compiled snapshot / global-activate — use the current runtime.
if (script.scheme == 'file') {
  return '${Platform.resolvedExecutable} ${script.toFilePath()}';
}
```

Note: `StepRunner` runs as `dart entry.dart tdd run`, so the resolved entry is itself a `.dart` path and is wrapped in `dart` at call site (`step_runner.dart:158–160`). Tier 4 should return the `.dart` path, not a pre-wrapped command.

**Alternative 1**: Add `Platform.resolvedExecutable` + script path as tier 4 in `StepRunner.defaultZfaBin()` — same as preferred but implemented as a fallback after the Isolate path rather than replacing it.

**Alternative 2**: Add a machine-level config file (e.g., `~/.zuraffa/zfa-bin`) written on `zfa setup` / first run, and consulted before throwing. Trade-off: introduces global state and a file to manage across machines.

**Files likely to change**:
- `lib/src/plugins/tdd/services/step_runner.dart` (primary fix)
- `test/plugins/tdd/services/step_runner_test.dart` (add coverage for the compiled-snapshot scenario)

**Tests to add or update**:
- Add a test to `step_runner_test.dart` where `Platform.script` points at a non-`zfa.dart` path, `zfa` is absent from PATH, and `package:zuraffa` is not on the package path — verify the fallback to `Platform.resolvedExecutable` + script path succeeds.

## Risks & Considerations

- **API breakage**: None — purely internal resolution improvement.
- **Performance**: One extra `File.exists()` call in the derived-path tier; negligible.
- **Windows**: `Platform.resolvedExecutable` and `Platform.script` work on Windows. The PATH lookup already handles `PATHEXT`.
- **Relationship to issue #665**: The same bug; `PipelineRunner` got tier 4 but `StepRunner` did not. A single fix to `StepRunner.defaultZfaBin()` addresses both.

## Open Questions

- [NEEDS CLARIFICATION: Does `CorpusStepRunner` (used by `zfa tdd corpus run`) have the same gap? Its entry resolver delegates to `StepRunner.defaultZfaBin`, so fixing that method also fixes `corpus run`.]
