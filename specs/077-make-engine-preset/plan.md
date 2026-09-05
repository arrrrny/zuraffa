# Implementation Plan: `zfa make engine` One-Shot Preset (issue #1109)

**Branch**: `077-make-engine-preset` | **Date**: 2026-09-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/077-make-engine-preset/spec.md`

## Summary

Close the gap between the existing spec-1002 engine infrastructure and the requirements
of issue #1109 (parent #1013 ENGINE-PIPELINE). The engine preset chain and check command
already exist; what is missing is: (1) idempotent generated DI registrations
(unregister-first) plus a `resetDependencies()` companion, (2) the engine receipt in the
`specs/<feature>/tdd/` location with `mock_class` per method (shape consumed by
#1014/CERT-GATE), (3) static analysis (`dart analyze`) as a third leg of
`zfa engine check`, and (4) verified trust-tier generator test suites for the five
artifact types. All validated end-to-end in the `~/zik_zak_test` sandbox.

## Technical Context

**Language/Version**: Dart 3.13 (stable), pure-Dart CLI package (`zfa`)

**Primary Dependencies**: `args`, `analyzer` (AST parsing), `code_builder`, `crypto`, `path`, `package:test`

**Storage**: Filesystem only — generated files under `lib/`, `test/`; receipts under `.zfa/` and `specs/<feature>/tdd/`

**Testing**: `dart test` (fast unit suite; chunked runner for wide sweeps), `dart analyze` on touched paths

**Target Platform**: macOS/Linux/Windows CLI (developer machines, CI agents)

**Performance Goals**: Engine generation of one slice completes in the same order of magnitude as the current `zfa make` chain (< ~10s excluding `dart pub get`)

**Constraints**: Zero Flutter imports in the engine tree; generated code must compile in a fresh Flutter project; receipts must be machine-readable JSON

**Scale/Scope**: Touches the DI plugin's registration/index builders, the engine receipt writer, the engine checker + command, and test suites under `test/plugins/{usecase,service,repository,datasource,mock}/`; validated against one sandbox entity

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- The repo constitution is an unfilled template; the effective gates come from AGENTS.md: v5 fixed layout (`lib/src/domain/entities/<snake>/`), receipts convention, `dart format lib test` before every commit, and the stop-on-roadblock rule for zfa-command misfires. All design below respects the fixed layout; formatting is a commit-time gate.
- **Post-design re-check**: no violations — the change is confined to existing generator modules plus tests.

## Project Structure

### Documentation (this feature)

```text
specs/077-make-engine-preset/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (engine.receipt.json schema, engine check contract)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/src/
├── commands/
│   ├── make_command.dart            # engine mode token → preset chain → receipt tail
│   └── engine_command.dart          # `zfa engine check <Entity>` CLI
├── engine/
│   ├── engine_models.dart           # EngineCheckResult, MockCertificationResult, paths
│   ├── engine_checker.dart          # getIt resolution + flutter-import guard (+ NEW: analyze leg)
│   ├── engine_receipt_writer.dart   # `.zfa/engine.receipt.json` (engine.v1)  → EXTEND
│   └── mock_certifier.dart          # per-method mock certification (mock_class source)
└── plugins/
    └── di/di_plugin.dart            # registration/index builders → idempotent + resetDependencies

test/plugins/
├── usecase/                         # trust-tier suites (≥2 behavioral tests each)
├── service/
├── repository/
├── datasource/
├── mock/
└── di/                              # idempotency + resetDependencies behavioral tests
```

**Structure Decision**: Single-package CLI repo; all changes live in the existing `lib/src/engine`, `lib/src/commands`, and `lib/src/plugins/di` modules with tests mirrored under `test/plugins/`. No new top-level directories.

## Gap Analysis (research summary — full detail in research.md)

| #1109 requirement | Current state (verified in source) | Work |
|---|---|---|
| Idempotent DI (unregister-first) | `di_plugin.dart` emits plain `registerLazySingleton`/`registerFactory` calls; zero `isRegistered`/`unregister` matches | Change registration-call emission to unregister-first form |
| `resetDependencies()` beside `setupDependencies()` | Not emitted anywhere | Emit a reset function in the DI index file |
| Engine receipt at `specs/<feature>/tdd/` with `mock_class` | Receipt written to `.zfa/engine.receipt.json` (schema `engine.v1`), no `mock_class`, no `source_files` key | Add the issue-shaped receipt (`engine.v2`) beside the existing one; keep `.zfa/` artifact for backward compatibility |
| `zfa engine check` runs `dart analyze` on engine tree | Checker does AST-level getIt resolution + flutter-import guard only; no analyze invocation | Add an analyze leg with actionable failure reporting |
| Trust-tier generator tests (≥2 behavioral per generator) | Suites exist for all five types; coverage depth varies | Audit each suite; add structural + compile behavioral tests where missing |
| Zero Flutter imports as built-in guard | Already implemented (`EngineFindingCode.flutterImport`) | Keep; covered by tests |
| `engine.receipt.json` `mock_certified: true` for all methods | Certifier already gates this | Receipt v2 must carry it per method |

## Complexity Tracking

> No constitution violations to justify.
