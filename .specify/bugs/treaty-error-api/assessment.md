# Bug Assessment: Treaty + error API unification

- **Slug**: treaty-error-api
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/917
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> Part of #908. Absorbs: #776 (manifest --verify), #778 (exit codes + --format json), #838 (--json/--stream), #839 (exit protocol 0/1/2/3/4), and the live drift evidence from #904 (manifest-declared flags CLI rejects: 'feature scaffold --use-mock', 'mock json --outputDir') + #876 (needs-reproducer note: silent parent-option inertness).
>
> Required: (1) `zfa manifest --verify` conformance gate in CI: manifest inputSchemas ↔ CLI flags ↔ help text; drift = exit 3. (2) Exit protocol ratified (0/1/2/3/4) with a golden table asserted in CI; legacy 64/255/-9 paths mapped or removed. (3) --json on every tdd/corpus command; `tdd run --stream` NDJSON per-step verdicts. (4) Every non-zero exit ends with a machine-actionable 'fix:' line.

## Symptom

The CLI's machine-readable interface is inconsistent: (a) `zfa manifest` has no `--verify` flag to self-validate that its published inputSchemas match the actual CLI flags, (b) exit codes are ad-hoc (64 for usage, 1 for failures, but 255, -9, and other codes appear in legacy paths), (c) most tdd/corpus commands do not support `--json` output, (d) `tdd run` does not stream per-step NDJSON verdicts, and (e) non-zero exits do not always end with a machine-parseable `fix:` line. This makes it difficult for CI pipelines and MCP agents to deterministically interpret zfa's output.

## Reproduction

1. **manifest --verify**: Run `zfa manifest --verify` — the flag does not exist. The manifest command only supports `--format json|mcp` (see `lib/src/commands/manifest_command.dart:11-13`).
2. **exit code inconsistency**: Run `zfa feature scaffold --use-mock` (a manifest-declared flag that the CLI rejects) — this is the #904 evidence. Run `zfa mock json --outputDir /tmp` — another manifest-declared flag the CLI rejects. The exit codes are inconsistent.
3. **--json missing**: Run `zfa tdd run <feature> --json` — most tdd subcommands do not accept `--json`.
4. **stream missing**: Run `zfa tdd run <feature> --stream` — no NDJSON streaming output.
5. **fix: line missing**: Trigger a non-zero exit (e.g., missing required arg) — not all error paths end with a `fix:` line.

## Suspected Code Paths

- `lib/src/commands/manifest_command.dart:1-76` — `ManifestCommand` currently only has `--format` flag (json/mcp); no `--verify` subcommand or flag exists
- `lib/src/cli/cli_runner.dart:1-100` — top-level CLI runner that registers all commands; exit code handling is scattered across individual commands
- `lib/src/commands/capability_command.dart` — shared capability runner; uses exit 64 for usage errors, exit 1 for capability failures (per `test/commands/capability_command_exit_code_test.dart:18-19`)
- `lib/src/plugins/tdd/commands/make_command.dart:64-66` — make uses `dart:io` `exitCode` for non-zero exits
- `lib/src/plugins/tdd/commands/run_command.dart:1-80` — run driver; no `--json` or `--stream` flags
- `lib/src/plugins/tdd/commands/plan_command.dart:70-95` — plan uses exit 3 for contract drift
- `lib/src/plugins/tdd/commands/doctor_command.dart:31-32` — doctor uses exit 0/1
- `test/commands/manifest_flag_conformance_test.dart:1-60` — existing tests for schema↔CLI flag conformance (slice subset)
- `test/commands/capability_command_exit_code_test.dart:1-60` — existing exit code contract tests

## Root Cause Hypothesis

**High confidence.** The exit code protocol was built incrementally as individual commands were added: exit 64 for usage errors (pre-existing, likely from `package:args` convention), exit 1 for runtime failures (the shared `CapabilityCommand` pattern), exit 3 for contract drift (plan command). But there was never a ratified protocol defining what each code means across the whole CLI, and legacy paths (exit 255, exit -9 from signal kills, etc.) were never cleaned up. Similarly, `--json` and `--stream` were added to some commands but not systematically to all. The manifest `--verify` gate was never implemented — the `manifest_flag_conformance_test.dart` validates a subset of commands in tests but there is no runtime CI gate.

## Proposed Remediation

**Preferred**:
1. **Exit protocol**: Define and document the ratified exit codes (0=success, 1=runtime failure, 2=spec/coverage gap, 3=contract drift, 4=timeout/misfire). Assert this table in a golden test. Map legacy codes: exit 64 stays as `package:args` convention, exit 255 and -9 are eliminated by proper signal handling.
2. **manifest --verify**: Add a `--verify` flag (or subcommand) to `ManifestCommand` that iterates all registered capabilities, checks each `inputSchema.required` property against the command's `argParser` options, and reports any drift. Drift = exit 3. The existing `manifest_flag_conformance_test.dart` provides the pattern.
3. **--json everywhere**: Add `--json` flag to all tdd/corpus commands. When set, the command's output is JSON instead of human-readable text. The existing pattern from `capability_command.dart` (machine-readable summary line) provides the model.
4. **--stream for run**: Add `--stream` flag to `tdd run` that emits NDJSON per-step verdicts as they complete. Schema-versioned (`schema_version: 1`).
5. **fix: line**: Ensure every non-zero exit path ends with a `--> fix:` or `--> fix:` line containing a machine-parseable remediation instruction.

**Alternatives**:
- **Exit code 64 migration**: Map exit 64 to exit 1 (since usage errors are a subset of runtime failures) — simpler protocol but loses granularity for `package:args` consumers.
- **JSON-only for corpus**: Only add `--json` to corpus commands (which are the primary CI consumers) rather than all tdd commands — smaller scope but leaves the inconsistency.

**Files likely to change**:
- `lib/src/commands/manifest_command.dart` — add `--verify` flag
- `lib/src/cli/cli_runner.dart` — centralized exit code protocol
- `lib/src/plugins/tdd/commands/run_command.dart` — add `--json`/`--stream`
- `lib/src/plugins/tdd/commands/plan_command.dart` — add `--json`
- `lib/src/plugins/tdd/commands/make_command.dart` — add `--json`
- All tdd/corpus subcommands — add `--json` flag
- `lib/src/commands/capability_command.dart` — ensure `fix:` line on all error exits
- New: exit code golden test

**Tests to add or update**:
- Exit code golden test: every command's non-zero exit matches the protocol table
- manifest --verify test: drift detection catches #904 sites (feature scaffold --use-mock, mock json --outputDir)
- --json output test: all tdd/corpus commands produce valid JSON when `--json` is set
- --stream test: tdd run emits NDJSON with schema_version
- fix: line test: every non-zero exit message contains a `--> fix:` line

## Risks & Considerations

- **Breaking change**: Changing exit codes (especially mapping legacy 255/-9) may break CI scripts that depend on specific codes. The golden test should be additive first, then legacy codes deprecated.
- **Stream performance**: NDJSON streaming from `tdd run` requires real-time flushing of each step's verdict — this is natural for the subprocess-spawning architecture but adds IO overhead.
- **Manifest verify accuracy**: The `--verify` gate must handle edge cases: aliased flags, negatable flags, flags with defaults that differ from schema defaults.
- **Backward compatibility of --json**: Adding `--json` to commands that previously had no structured output is additive and non-breaking, but the JSON schema must be documented and versioned.

## Open Questions

- [NEEDS CLARIFICATION: Should exit code 64 (usage errors from `package:args`) be preserved or mapped to exit 1?]
- [NEEDS CLARIFICATION: What is the NDJSON schema for `tdd run --stream` — one line per step, or one line per behavior?]
- [NEEDS CLARIFICATION: Are the #904 drift sites (feature scaffold --use-mock, mock json --outputDir) already fixed on master, or are they still broken?]
