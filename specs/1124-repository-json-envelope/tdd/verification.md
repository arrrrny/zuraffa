# TDD Verification: SPEC 1124 — `zfa repository create --json` envelope

**Feature**: `1124-repository-json-envelope` (issue #1124)
**Verified**: 2026-09-07 (this session — every number below is from a REAL
test run executed on this branch; kernel caches cleaned before runs)
**Verifier**: `/speckit.tdd.verify` fallback audit — this repo is the zfa
CLI itself, not a zuraffa-wired feature project (no `.zfa.json`), so the
LLM-guided path applies; all evidence captured from live `dart test` /
`dart analyze` / `dart run bin/zfa.dart` executions
**Branch**: `spec/1124-repository-json-envelope` → PR #1245
**Commits**: `d68c0bd2` (envelope + command + tests) → this session's
increment (`--explain`, classified finding kinds, digest-proof assertion,
this artifact)

## 1. TDD cycle evidence (red → green → verify)

| Phase | Action | REAL evidence |
|-------|--------|---------------|
| RED   | The generic `CapabilityCommand` owns `--json` as the JSON-INPUT option, so `zfa repository create Product --json` could not even parse (no bare flag) — reproduced structurally, then pinned by tests written against the not-yet-existing first-party command | `dart test test/plugins/repository/repository_command_test.dart` before the fix: **compile failure, 0 passed** (`RepositoryCreateCommand` not found) — no envelope surface existed |
| GREEN | `lib/src/core/verdict_envelope.dart` (`ZuraffaVerdictEnvelope`, the canonical `zuraffa.verdict.v1` per issue #1105 order 1) + first-party `RepositoryCreateCommand` (the `manualSubcommandNames` seam, same as `StateCreateCommand`) delegating through `CapabilityInvocationWrapper` | `dart test test/plugins/repository/repository_command_test.dart test/core/verdict_envelope_test.dart` → **11 passed, 0 failed** |
| Refactor | Audit-driven hardening, no gate-semantics change: (a) `--explain` added to the create verb — resolves the SAME `RepositoryEmissionPlanner` `explainEmission` serves, with `datasourcePluginActive: false` because the direct path's context is null (the plugin emits the datasource interface itself, #406 — the plan must not lie); (b) gate findings get a stable kind vocabulary (`missing_implementation` / `missing_override` / `override_without_declaration`) instead of one opaque `conformance_mismatch`; (c) SC-1 gains the digest-PROOF assertion (sha256 of the manifest bytes == envelope `manifest.sha256`); (d) SC-7 added for `--explain` | Re-run: **12 passed, 0 failed** |
| Verify | see §2 | see §2 |

## 2. Verification commands (all executed in this session)

| # | Command | Exit | Outcome |
|---|---------|------|---------|
| 1 | `dart analyze lib/src/commands/repository_create_command.dart lib/src/commands/repository_command.dart test/plugins/repository/repository_command_test.dart` | 0 | **No issues found!** |
| 2 | `dart test test/plugins/repository` | 0 | **55 passed, 0 failed** (48 pre-existing + 7 SC tests) |
| 3 | `dart test test/plugins/repository/repository_command_test.dart test/core/verdict_envelope_test.dart` | 0 | **12 passed, 0 failed** |
| 4 | `dart test test/commands/manifest_flag_conformance_test.dart test/commands/manifest_verify_gate_test.dart test/commands/dead_positional_grammar_test.dart` | 0 | **28 passed, 0 failed** — the manifest treaty still certifies the new serving command (`resolveServingCommand` now resolves `repository create` → first-party `RepositoryCreateCommand`) |
| 5 | `dart test test/commands/exit_code_sweep_1139_test.dart test/commands/exit_protocol_golden_test.dart test/commands/capability_command_test.dart test/commands/capability_command_exit_code_test.dart test/commands/capability_command_receipt_hook_test.dart` | 0 | **36 passed, 0 failed** |
| 6 | Full `test/commands/` sweep (65 files, disk-sharded at low concurrency, kernel caches cleaned between shards) | 0 | **All batches passed** |
| 7 | Sibling plugin suites: `api` (30), `app_shell` (83), `benchmark` (59), `cache` (29), `datasource` (41), `di` (46), `feature` (6), `graphql` (6), `gym` (40), `method_append` (4), `mock` (147), `route` (97), `state` (21), `usecase` (42) | 0 | **All passed** |
| 8 | Live CLI: `dart run bin/zfa.dart -C <tmp> repository create Product --json` | 0 | Single-line envelope: `{"schema":"zuraffa.verdict.v1","command":"zfa repository create","verdict":"pass","exit_class":0,"subject":{"kind":"repository","entity":"Product"},"findings":[],"manifest":{"path":".zfa/receipts/repository-product.json","sha256":"5781…6eb","methods":["get","update"]},"drifts":[],"details":{…created:3},"timestamp":…}` |
| 9 | Live CLI receipt parity: `ls <tmp>/.zfa/receipts/` | — | BOTH `repository-create-Product-<ts>.json` (proof.v1 capability receipt, #996/#1130) AND `repository-product.json` (contract manifest) present — the manual command did not regress the receipt flow |
| 10 | Live CLI: `dart run bin/zfa.dart -C <tmp> repository create Product --explain` | 0 | `Emission plan (repository): interface emit … implementation emit … datasource_interface emit … emitted by the repository plugin because the datasource plugin is NOT active` |
| 11 | Live CLI: `dart run bin/zfa.dart -C <tmp> manifest --verify repository` | 0 | `treaty holds: manifest inputSchemas ↔ CLI flags ↔ help text are in conformance (exit 0)` |

### Not runnable on this host (environmental, PRE-EXISTING — not caused by this branch)

| Suite | Blocker |
|-------|---------|
| Suites driving `test/plugins/helpers/flutter_cluster_fixture.dart` (e.g. `controller_compile_test`, `presenter_compile_test`) | Requires the Flutter SDK (`flutter pub get` → `ProcessException: No such file or directory`); this host has the Dart SDK only |
| `test/plugins/mcp`, `test/plugins/tdd`, `test/plugins/slice`, `test/plugins/sync`, `test/plugins/sqlite` and remaining peripheral plugin dirs | Too slow for this 10GB-disk sandbox (each test file compiles a ~100MB kernel snapshot); **zero import-path relation to the diff** — verified by grep, only `repository_plugin.dart` and a dispatch probe reference `RepositoryCommand` |

## 3. Acceptance criteria — PROVED vs NOT

| Criterion (issue #1124) | Status | Proof |
|-------------------------|--------|-------|
| `zfa repository create Product --json` emits the envelope | **PROVED** | §2 #8 live run + SC-1 (schema/command/verdict/exit_class/subject/findings/drifts/timestamp, last-stdout-line single-line contract) |
| Canonical `zuraffa.verdict.v1` (issue #1105) with `manifest: {path, sha256, methods}` | **PROVED** | SC-1 + §2 #8; `manifest.sha256` is PROVABLE — sha256 of the manifest file bytes equals the envelope digest (SC-1 digest assertion); path is project-relative POSIX; methods = the interface method set |
| Gate failure + `--json` → gate findings in `findings[]` and expected/actual methods in `details` | **PROVED** | SC-5: finding `{side: implementation, kind: missing_implementation, method, fix: --> fix: …}`; `details.expected_methods` / `details.actual_methods` from `ConformanceResult`; no `manifest` key claimed (a failed gate writes none) |
| Human-readable output unchanged when `--json` absent | **PROVED** | SC-3 (success prose) + SC-6 (gate failure keeps the existing exception → runner catch-all channel) |
| Conformance gate semantics unchanged — only the output channel | **PROVED** | No edits to `repository_conformance_checker.dart` / `RepositoryPlugin._runConformanceGate`; the command only catches `RepositoryConformanceException` and classifies the already-reported failures for output |
| `zfa repository create Product --explain` continues to use the existing explainEmission machinery | **PROVED** | SC-7 + §2 #10: the verb resolves the SAME `RepositoryEmissionPlanner` `explainEmission` serves; `--explain` never generates |
| All existing repository tests still pass | **PROVED** | §2 #2: 55/55 |
| Receipt parity preserved (#996/#1130) | **PROVED** | §2 #9: wrapper-delegated execution still ships the standalone proof receipt |
| SPEC 917 exit-code honesty | **PROVED** | SC-4 (usage family: exit 2 with machine-actionable fix, envelope under `--json`) / SC-5 (gate failure exit 1) / SC-1 (pass exit 0) |

## 4. Files changed by this branch

| File | Change |
|------|--------|
| `lib/src/core/verdict_envelope.dart` | **NEW** — `ZuraffaVerdictEnvelope`: the canonical `zuraffa.verdict.v1` envelope (issue #1105 order 1): typed model, stable key order, single-line last-stdout encoding, `emit()` helper. The tdd plugin's `verdict.v1` envelope is deliberately NOT migrated (that sweep is #1105's own scope) |
| `lib/src/commands/repository_create_command.dart` | **NEW** — first-party `RepositoryCreateCommand`: `--json` → canonical envelope; gate failures → `findings[]` (classified `side`/`kind`/`fix`) + `details.expected_methods`/`actual_methods`; `manifest` binding `{path, sha256, methods}` on pass; `--explain` → the explainEmission planner; dry-run → the generic EffectReport; usage errors → exit 2 (envelope under `--json`); execution through `CapabilityInvocationWrapper` so proof receipts keep flowing |
| `lib/src/commands/repository_command.dart` | Registers `RepositoryCreateCommand` as the manual `create` subcommand (`manualSubcommandNames: {'create'}` — the #761-safe seam) |
| `test/core/verdict_envelope_test.dart` | **NEW** — envelope model unit contract (schema id, omitted-null-keys, round-trip, emit) |
| `test/plugins/repository/repository_command_test.dart` | **NEW** — SC-1…SC-7: positive envelope (+ digest proof), receipt parity, human channel, usage error, gate-failure findings/details, gate-failure human channel, `--explain` |
| `specs/1124-repository-json-envelope/tdd/verification.md` | This artifact |

Verdict: **PASSED** — all nine acceptance criteria hold on REAL runs; the
red phase was proven by the missing-surface compile failure, and the
refactor-phase audit fixes (`--explain` truthfulness, finding vocabulary,
digest provability) are covered by their own assertions.
