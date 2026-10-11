# Tasks: Test Plugin `--explain` Flag (Spec 1129)

**Branch**: `spec/1129-test-explain-flag` | **Date**: 2026-09-07 | **Spec**: `specs/1129-test-explain-flag/spec.md`

## TDD Task List (red → green per task)

- [x] T1 RED: `test/plugins/test/test_explain_test.dart` — MVP slice (US1): drive the real command tree (`CommandRunner` + `TestCommand` with a fake `ScopedAnalyzer`) for `zfa test create <Entity> --explain`; assert the separator `--- explain: test create ---` plus the five mandated sections (`generated files:`, `test kinds:`, `self-certification:`, `trust tier:`, `summary:`), the additive placement (verdict line + file list still present), and the opt-in guard (no separator without the flag). RED today: `Could not find an option named "--explain"`.
- [x] T2 RED (US2): same suite — `--explain --json` prints the parseable certification envelope `{entity, tests, compile, errors[], schema:1}` FIRST, then the prose block; `--json` alone stays envelope-only (byte-identical keys, no explain prose).
- [x] T3 RED (US3): same suite — tier attribution: passing analyzer ⇒ every written file `tier=certified`, block tier `certified`; failing analyzer ⇒ offending file `tier=failed` with the first error quoted, block tier `failed`; skipped (pre-existing) file ⇒ `tier=pre-existing` and no block-tier lowering.
- [x] T4 RED (capability contract): `CreateTestCapability.execute` with `explain: true` returns `data['explain']` containing the sections while `data['certification']` keeps its exact spec 980 shape; `explain: false` attaches nothing.
- [x] T5 GREEN: `lib/src/plugins/test/test_explain.dart` — pure `buildTestExplain(...)` builder + read-only trust-tier derivation (`certified`/`failed`/`unverified`/`pre-existing`, floor rule) + honest kind lanes (`unit`/`integration`/`widget` counts).
- [x] T6 GREEN: `lib/src/commands/test_create_command.dart` — bespoke `create` subcommand (route precedent): real ArgParser (`--name`, `--methods`, `--domain`, `--dry-run`, `--force`, `--verbose`, `--revert`, `--json` OUTPUT flag, `--explain`), positional entity, delegation to `CreateTestCapability.execute()` via `CapabilityInvocationWrapper` (same gate, same receipts), #769 zero-files guard, exit codes.
- [x] T7 GREEN: `lib/src/commands/test_command.dart` — register the manual subcommand + `manualSubcommandNames => {'create'}`.
- [x] T8 GREEN: `lib/src/plugins/test/capabilities/create_test_capability.dart` — schema declares `explain` (boolean, described); `execute()` attaches `data['explain']` when asked; `data['certification']` and the gate untouched.
- [x] T9 VERIFY: `dart analyze` (changed files only) + `dart test test/plugins/test/` + `dart format .` (zero diff) + `zfa manifest --verify test` (SC-5) + sandbox CLI demo of both acceptance invocations.
- [x] T10 `/speckit.tdd.verify` → `specs/1129-test-explain-flag/tdd/verification.md` with REAL results.
- [x] T11 PR: commit spec artifacts + code, push branch, open PR to master, `Closes #1129`.

## Acceptance Mapping

| Acceptance criterion (issue #1129) | Proving task(s) |
|---|---|
| `zfa test create <Entity> --explain` emits the explanation block | T1/T5/T6 (SC-1) |
| Explain block appears on stdout alongside the regular output | T1 (SC-2/SC-3) |
| `--explain --json` produces both JSON and prose | T2 (SC-2) |
| Unit test asserting the explain output contains the expected sections | T1 |
| `--json` semantics unchanged | T2/T4 (FR-004) |
| Self-certification gate behavior unchanged | T4/T9 (FR-005) |
| Trust tiers honest per file | T3 (SC-4) |
| Manifest treaty clean after schema change | T9 (SC-5) |

## Non-behavioral Tasks (config, docs, wiring)

- Wiring: `TestCommand` constructor registers `TestCreateCommand` (T7) — no behavioral change to the dead direct grammar.
- Config: capability `inputSchema` gains the `explain` property so `zfa manifest --verify` certifies the flag surface (T8).
- Docs: the explain block's own `summary:` section doubles as in-output documentation; no openwiki changes required (flag help text documents the flag).
