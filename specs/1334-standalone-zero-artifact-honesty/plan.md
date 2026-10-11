# Implementation Plan: Standalone Zero-Artifact Honesty — `test create` / `api` Verbs

**Branch**: `verify/epic1-honesty-sweep` · **Spec**: [spec.md](spec.md) · **Created**: 2026-09-09

## Technical Context

**Language/Version**: Dart 3.13 (SDK constraint `^3.11.0`, pure-Dart package — no Flutter dependency in `lib/`)
**Primary dependencies**: `args`, `code_builder`, `dart_style` (existing; no new deps)
**Storage**: filesystem only (`.zfa/` receipts remain untouched by this feature)
**Testing**: `dart test` (repo tiers per `dart_test.yaml`; this feature adds fast regression tests tagged `['regression', 'slow']` following the house pattern, plus in-process capability unit tests)
**Target platform**: zfa CLI (Dart VM)

## Constitution Check

- **Engine purity (VII)**: no Flutter imports introduced; all touched code is core/Dart-only. PASS.
- **Honesty floor (EPIC 1)**: the feature IS an honesty upgrade — zero-artifact runs stop reporting success. PASS.
- **Receipt contract (#769)**: unchanged — zero-artifact runs still persist no receipt; the fix verdict is text/exit-code only. PASS.
- **Exit-code protocol (#767 family)**: reuses the established `exitCode = 1` failure path; no new exit class invented (usage errors remain parser exit 2; the `64` family stays where it exists today). PASS.

## Technical Approach

1. **`GeneratedFile.skipReason`** (additive): optional `String?` field + serialization in `toJson()`. All existing call sites compile unchanged (named optional).
2. **Test builders tag skip causes**: `test_builder_entity.dart` (UseCase file + native-mock files), `test_builder_custom.dart` (UseCase file), `test_builder_polymorphic.dart` (Repository source) set `skipReason: 'missing-dependency'`; existing-target skips in the same builders set `skipReason: 'overwrite-conflict'`.
3. **`CreateTestCapability.execute` verdict gate**: after `_generateFiles`, compute `artifacts` (actions created/overwritten/updated/deleted) and `missingDepSkips` (action skipped + skipReason missing-dependency). When `!dryRun && artifacts.isEmpty && missingDepSkips.isNotEmpty` → `success: false`, message: `Nothing generated: N test generation(s) skipped — dependency sources missing (UseCase / native mock / repository)` + fix hint `--> fix: create the missing sources first (e.g. zfa usecase create <Entity> --methods=...), then re-run zfa test create`. Message is embedded in `ExecutionResult.message`; the command layer prints it via its existing failure branch (`❌ Failed: ...`, `exitCode = 1`).
4. **`CreateApiBridgeCapability.execute` verdict gate**: when `!dryRun && files.isEmpty` (the only zero-file non-dry-run cause in the builder is the no-UseCases discovery) → `success: false`, message naming the discovery result + fix hint. `ApiCommand` already prints `❌ Failed to generate API bridge: ...` and sets `exitCode = 1` (bug #1139 pattern) — zero command-layer changes needed.
5. **No receipt-layer changes**: `CapabilityInvocationWrapper` gates on `result.success`; failed runs naturally persist nothing. Issue #769 contract intact.

## Key Decisions

- **Verdict at the capability layer, not the command layer** — MCP clients and the `make` orchestrator consume `ExecutionResult`; fixing the verdict there fixes every consumer at once.
- **`skipReason` as a plain string, not an enum class** — matches the house style of `action: 'skipped'` (string-typed), keeps `toJson()` stable, avoids a new public type.
- **Empty-generation honesty keeps the certification gate untouched** (spec 980): compile certification still only gates runs that wrote files.
- **Dry-run is exempt**: preview is explicit user intent; the gate would turn every preview into a lie.

## Risks & Mitigations

- **Over-firing on legitimate zero-artifact flows** (e.g. custom-usecase tests with `--methods` filters): the gate requires at least one `missing-dependency` skip; pure "nothing matched the filter" flows have no such skip → unchanged. Regression test pins the benign path.
- **Receipt schema drift**: none — receipts only ever carried artifact-bearing runs.

## Verification Plan

- Red: new regression tests `issue_1385_test_create_missing_usecase_exit_test.dart` + `issue_1386_api_no_usecases_exit_test.dart` fail on the pre-fix code.
- Green: both pass after the capability/builders changes; all pre-existing tests keep passing (`dart test test/` fast tier + regression files exercised by this feature).
- `dart format .` clean; `dart analyze` clean on touched files.
