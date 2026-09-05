# Implementation Plan: Test Plugin A+ Upgrade (Spec 980)

**Branch**: `spec/980-test-aplus-upgrade` | **Date**: 2026-09-05 | **Spec**: `specs/980-test-aplus-upgrade/spec.md`

## Summary

Upgrade the `test` plugin to A+: after writing each generated test file, run a scoped `dart analyze` on it and emit a machine verdict (`test: entity=<X> tests=<N> compile=pass|fail --> fix: <first error>` plus a `--json` envelope `{entity, tests, compile, errors[], schema:1}`); write a per-method test receipt `.zfa/receipts/test-<entity>.json` that `zfa proof check` re-derives to flag usecase/test drift; consolidate the three scattered test files under `test/plugins/test/` and add a direct `TestPlugin.generate` dispatch suite (orchestrator + polymorphic); replace the `_parseUseCaseFile` regexes with the analyzer package (behavior-neutral, snapshot-tested); fix `openwiki/testing.md` to show the real native-mock output and the #354 flavor detection.

## Technical Context

**Language/Version**: Dart 3.13+ (SDK 3.13.3 used for dev; CI pins 3.13.2). Pure-Dart package — no Flutter dependency.

**Primary Dependencies**: `analyzer` (AST parsing — existing `FileParser`/`AstHelper` pattern), `crypto` (SHA-256 digests), `code_builder`/`dart_style` (unchanged generation), `test` (suite).

**Storage**: `.zfa/receipts/` — test receipts are a new `test.v1` document kind alongside the existing `proof.v1` generation receipts.

**Testing**: `dart test test/plugins/test/` (fast tier — new tests must NOT carry the `slow` tag so the default run executes them). Real-subprocess certification tests spawn `dart analyze` (and one CLI exit-code proof) inside temp workspaces.

**Target Platform**: CLI (`bin/zfa.dart`), Linux/macOS/Windows CI.

## Key Implementation Decisions

1. **Certification placement** — `TestPlugin.generate` itself self-certifies after writing files (every path: direct command, capability subcommand, `zfa make --test`) and exposes `lastCertification`. `TestCommand.execute` (direct grammar) gains `--json` + failure semantics; `CreateTestCapability.execute` gates `ExecutionResult.success` on the compile verdict so the capability grammar exits 1 (existing #767 wiring in `CapabilityCommand`).
2. **Scoped analysis** — one `dart analyze --format=machine <file>` per generated file (dart analyze only honors the last of multiple path arguments — verified empirically). Machine lines parse as `ERROR|type|code|path|line|col|colEnd|message`; exit 3 ≠ parse failure.
3. **Receipts** — `TestReceiptStore` writes/loads `test-<entitySnake>.json` (schema `test.v1`); `ReceiptStore.loadAll` skips the `test-` basename prefix (they are a separate kind, never timestamp-named like proof.v1 documents). `ProofChecker` gains a `stale_usecase` finding kind for usecase/test drift, plus `deleted`/`modified` findings for receipted test files.
4. **Analyzer swap** — `_parseUseCaseFile` walks the parsed `CompilationUnit`: fields typed `XRepository`/`XService`/`XUseCase` (declared `final`) feed repos/services/composed usecases; the target class's `extends` clause decides the flavor (`UseCase`, `StreamUseCase`, `SyncUseCase`, `BackgroundUseCase`, `OsBackgroundTaskUseCase`). Unparseable source degrades to an empty analysis (no regex fallback remains).
5. **Test counting** — `tests=<N>` counts generated `test(...)` blocks, sourced from the same receipt entries, so verdict and receipt agree by construction.

## Tasks / Steps

1. RED: write the new suite under `test/plugins/test/` (self-certify verdict/envelope/exit, receipt + drift, dispatch, analyzer parity snapshot, openwiki doc markers) and move the three scattered files in. Prove RED.
2. GREEN: `test_receipt.dart` + certifier + plugin wiring + command/capability changes + regex→analyzer + openwiki fix.
3. VERIFY: `dart analyze`, `dart test test/plugins/test/`, `dart format .` (zero diff), chunked runner for the surrounding folders.
4. `/speckit.tdd.verify` → `specs/980-test-aplus-upgrade/tdd/verification.md` (REAL run results).
5. Disk housekeeping, commit, push, PR (`Closes #980`).

## Risks & Mitigations

- `dart analyze` subprocess cost in the fast tier → per-file scoped runs only, fake-analyzer unit tests for logic, one real end-to-end proof.
- Proof smoke regression → `loadAll` prefix skip is additive; test-receipt findings only appear when `test-*.json` exists.
- Windows path portability → all receipt paths stored project-relative POSIX.

## Rollout Plan

Single PR to `master`; no breaking CLI changes (new flags/behaviors only additive; failure semantics only activate for non-compiling output that previously masqueraded as success).
