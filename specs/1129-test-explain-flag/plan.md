# Implementation Plan: Test Plugin `--explain` Flag (Spec 1129)

**Branch**: `spec/1129-test-explain-flag` | **Date**: 2026-09-07 | **Spec**: `specs/1129-test-explain-flag/spec.md`

## Summary

Upgrade the `test` plugin from A- to A+ by adding the `--explain` flag to `zfa test create <Entity>`: after the regular output, the CLI prints a human-readable explain block (separator `--- explain: test create ---`, then the sections `generated files:`, `test kinds:`, `self-certification:`, `trust tier:`, `summary:`) describing which test files were generated, which test kinds (unit/integration/widget) were produced, the self-certification result per file, and the trust tier of the generated artifacts. `--explain --json` prints the spec 980 certification envelope `{entity, tests, compile, errors[], schema:1}` first, then the prose block (the issue #1125 human-twin convention). The `--json` semantics and the self-certification gate are unchanged; the tiers are derived read-only from the certification evidence.

## Technical Context

**Language/Version**: Dart 3.13+ (SDK 3.13.3 used for dev). Pure-Dart package — no Flutter dependency.

**Primary Dependencies**: `args` (command grammar), `analyzer` (existing self-certifier, unchanged), `test` (suite). No new dependencies.

**Storage**: none new — the explain block is derived at print time from the generation result (files, actions, `lastCertification`). Receipts stay exactly as spec 980 shipped them.

**Testing**: `dart test test/plugins/test/` (fast tier — new tests carry NO `slow` tag). The explain suite drives the real command tree (`CommandRunner` + `TestCommand`) with a fake `ScopedAnalyzer`, so no `dart analyze` subprocess is needed except the existing spec-980 integration proofs.

**Target Platform**: CLI (`bin/zfa.dart`), Linux/macOS/Windows CI.

**Project Type**: CLI / code generator plugin.

## Key Implementation Decisions

1. **Bespoke `TestCreateCommand` (the route precedent)** — `zfa test create` currently serves `CreateTestCapability` through the generic `CapabilityCommand`, whose `--json` is the machine-INPUT option (`--json '<args>'`), so a bare `--explain --json` cannot parse. Following the sanctioned route pattern (issue #971 orders 2-5: `RouteCommand` registers `RouteCreateCommand` manually and `manualSubcommandNames` skips the generic registration), `TestCommand` gains a manual `TestCreateCommand` subcommand whose `--json` is the machine-OUTPUT flag (the spec 980 FR-002 semantics — envelope `{entity, tests, compile, errors[], schema:1}`) and whose `--explain` flag prints the prose block. Generation is NOT duplicated: the bespoke command delegates to `CreateTestCapability.execute()` (same self-certification gate, same receipts via `CapabilityInvocationWrapper`, same `ExecutionResult`).
2. **Explain builder is a pure function** — `lib/src/plugins/test/test_explain.dart` exposes `buildTestExplain(...)` (no I/O): entity, files with actions, certification, receipt path → the block string. Both the CLI command and the capability consume it, so CLI output and `ExecutionResult.data['explain']` cannot drift.
3. **Capability is the second consumer** — `CreateTestCapability.inputSchema` declares `explain` (boolean); `execute()` attaches `data['explain']` when asked. The generic `CapabilityCommand` path already prints `data['explain']` verbatim (Spec #1131), so MCP/manifest clients get the same block. `data['certification']` keeps its exact shape (FR-004/FR-005: `--json` semantics and the gate are unchanged).
4. **Trust tiers are read-only derivations** — per written file: `certified` when no certification error names it, `failed` when one does, `unverified` when there is no certification evidence; skipped files are `pre-existing`. Block-level tier is the honest floor over the files this run wrote (`failed` > `unverified` > `certified`; `pre-existing` never lowers it). The gate itself is untouched.
5. **Test kinds are honest lanes** — the test plugin emits unit tests only; the `test kinds:` section counts the produced lanes (`unit=N, integration=0, widget=0`) rather than claiming kinds it never produced.
6. **Manifest treaty compliance** — adding `explain` to the capability inputSchema requires the serving command's parser to accept and advertise `--explain` (the #902/#904 drift classes); the bespoke command registers real options with help text for every schema property, so `zfa manifest --verify` stays clean.

## Tasks / Steps

1. RED: `test/plugins/test/test_explain_test.dart` — drive the real command tree with a fake analyzer; assert the separator + sections (SC-1), additive placement (SC-2/SC-3), combined `--explain --json` (envelope then prose), failing-analyzer tier attribution (SC-4), `pre-existing` handling, and capability-level `data['explain']`. Prove RED (flag does not exist yet).
2. GREEN: `test_explain.dart` (pure builder + tier derivation), `TestCreateCommand` (bespoke subcommand), `TestCommand` wiring (`manualSubcommandNames`), `CreateTestCapability` schema + `data['explain']`.
3. VERIFY: `dart analyze` on changed files, `dart test test/plugins/test/`, `dart format .` (zero diff), manifest verify for the test plugin.
4. `/speckit.tdd.verify` → `specs/1129-test-explain-flag/tdd/verification.md` (REAL run results).
5. Disk housekeeping, commit (spec artifacts + code), push, PR (`Closes #1129`).

## Risks & Mitigations

- Generic-path regression (`zfa test create --json '<args>'` machine input) → the bespoke command replaces the generic grammar for the test plugin ONLY; the generic `CapabilityCommand` is untouched for every other plugin. The capability itself keeps honoring `args['explain']` for programmatic callers.
- Manifest treaty drift → the bespoke parser registers every schema property (name, methods, domain, dry-run, force, verbose, explain) with help text; verified by `zfa manifest --verify test`.
- Output-shape drift vs `CapabilityCommand` → the bespoke command mirrors the #769 zero-files guard and the success/skipped printout so existing CLI expectations (receipts, exit codes) hold.
