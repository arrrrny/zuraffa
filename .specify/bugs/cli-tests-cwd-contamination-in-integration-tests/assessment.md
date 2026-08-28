# Bug Assessment: CLI Tests: CWD contamination in integration tests

- **Slug**: cli-tests-cwd-contamination-in-integration-tests
- **Created**: 2026-08-27T14:26:38.692938+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/506
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

# Bug Assessment: End-to-end CLI tests are non-hermetic under parallel `dart test`

- **Slug**: cli-tests-cwd-contamination
- **Created**: 2026-08-23
- **Source**: pasted `dart test` output + local reproduction (auto-generated slug; no slug supplied)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Running the default `dart test test/commands/` (parallel execution) fails with a
handful of end-to-end CLI tests, while the same files pass individually and pass
when run with `--concurrency=1`:

```
Some tests failed.
  app_shell_command_test.dart: end-to-end generation writes all three glue files when run from a project root [E]
  app_shell_command_test.dart: end-to-end generation --output lib/custom writes glue there and main.dart imports resolve [E]
  app_shell_command_test.dart: end-to-end generation respects the --title flag [E]
  app_shell_command_test.dart: end-to-end generation fails with an actionable error when setupDependencies is missing [E]
  app_shell_command_test.dart: fails when di/index.dart mentions setupDependencies only in a comment [E]
  initialize_dart_inplace_test.dart: InitializeCommand --dart in-place bootstrap (issue #393) --dart --dry-run WITHOUT --deps-only previews entity scaffolding (CodeRabbit follow-up: must not return early) [E]
  xray_mock_cli_test.dart: zfa xray mock CLI integration scaffolds @XRayMock onto a usecase file [E]
```

A minimal two-file experiment confirms `Directory.current` is effectively
**process-global** under `dart test`'s parallel execution: two test files that
each do `Directory.current = <dir>` and then assert the value stomp each other.

## Symptom

Several end-to-end CLI tests mutate the global working directory
(`Directory.current = <sandbox>`) and then invoke `zfa` subcommands that read
`Directory.current` as the project root (`app_shell`, `xray mock`, `initialize`).
Under `dart test`'s default parallel execution, concurrently-running test files
share the process working directory, so one test's sandbox CWD is overwritten by
another test's — leaving a command to operate on the wrong directory. The
symptom manifests as "No pubspec.yaml found at /tmp/.../<other-test's-dir>",
"lib/main.dart missing", or a stray `pubspec.yaml` existing where it should not.

## Reproduction

1. From the repo root, run the default parallel suite:
   `dart test test/commands/app_shell_command_test.dart test/commands/initialize_dart_inplace_test.dart test/commands/xray_mock_cli_test.dart`
2. Observe the `[E]` failures listed above.
3. Re-run the same set with `--concurrency=1` → all pass.
4. (Or) run a single one of those files alone → passes.

## Suspected Code Paths

- `test/commands/app_shell_command_test.dart:104-136` — `setUp` does
  `Directory.current = workspace.path`; the command reads
  `lib/src/commands/app_shell_command.dart:116` `Directory.current.path`.
- `test/commands/xray_mock_cli_test.dart:16-34,38` — sets
  `Directory.current = tempDir.path`; command reads
  `lib/src/commands/xray_mock_command.dart:68` `Directory.current.path`.
- `test/commands/initialize_dart_inplace_test.dart:28-34` — `useDir` sets
  `Directory.current`; command reads `Directory.current` at
  `lib/src/commands/initialize_command.dart:115,139,153,177,198`.
- `test/helpers/project_root.dart:11` — the maintainers' own comment already
  states *"CWD may be contaminated by other test files"*, which is exactly this
  failure mode. The whole `findProjectRoot()` helper exists to be
  CWD-independent for that reason.

## Root Cause Hypothesis

`Directory.current` behaves as a process-global value under `dart test`'s
parallel runner (confirmed empirically). The three test files above mutate it and
rely on it as their sandbox root, while the commands they exercise resolve the
project root from `Directory.current`. When two such test files run
concurrently, their `Directory.current` assignments race, so a command can run
against the wrong directory. Confidence: **high** (reproduced + isolated via the
two-file experiment + `concurrency=1` green).

## Proposed Remediation

**Preferred**: make the affected commands accept an explicit `--root` option
(defaulting to `Directory.current.path` so real CLI usage is unchanged) and
update the three tests to pass `--root <sandbox>` instead of mutating
`Directory.current`. This removes the global-state dependency entirely, making
the tests hermetic and the commands testable without touching the process CWD.
- `lib/src/commands/app_shell_command.dart`: add `--root`; use it as `projectRoot`.
- `lib/src/commands/xray_mock_command.dart`: add `--root`; use it as `projectRoot`.
- `lib/src/commands/initialize_command.dart`: add `--root`; use it for pubspec
  path, package-name derivation, dependency wiring, and config load/init.
- Update the three test files to pass `--root <sandbox>` and make their own
  assertions path-absolute (no reliance on `Directory.current`).

**Alternatives**:
- Run the command tests with `--concurrency=1` / a serial tag — hides the bug
  but leaves the non-hermetic design (and any future contributor hitting it).
- Have the commands resolve root via `findProjectRoot()` — still depends on CWD
  for sandbox discovery, so it does not fully remove the race.

**Files likely to change**:
- `lib/src/commands/app_shell_command.dart`
- `lib/src/commands/xray_mock_command.dart`
- `lib/src/commands/initialize_command.dart`
- `test/commands/app_shell_command_test.dart`
- `test/commands/xray_mock_cli_test.dart`
- `test/commands/initialize_dart_inplace_test.dart`

**Tests to add or update**:
- The three test files above, switched to `--root` + absolute assertion paths.
- Keep the existing behavior coverage (glue files, title flag, setupDependencies
  errors, @XRayMock injection, dry-run-no-write) — just hermetic.

## Risks & Considerations

- `--root` default must stay `Directory.current.path` so real users (who run
  from the project root) see no behavior change.
- `InitializeCommand` also touches `DependencyWirer.ensureProjectStructure` and
  `ZfaConfig.init/load`; these must receive the explicit root too, or they will
  still operate on the (possibly contaminated) CWD.
- `dart pub add` network calls in `initialize` tests remain environment-sensitive;
  those tests already tolerate wiring failures and only assert the in-place
  pubspec bootstrap, so the hermetic change should not regress them.

## Open Questions

- None blocking. The mechanism is reproduced and the fix is localized.

See https://github.com/arrrrny/zuraffa/issues/506.

## Symptom

[NEEDS CLARIFICATION]

## Reproduction

[NEEDS CLARIFICATION]

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: confirm the exact code path and a safe remediation.]
