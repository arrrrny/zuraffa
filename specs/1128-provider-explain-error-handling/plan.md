# Plan: 1128 — provider A+ upgrade (`--explain` + comprehensive error handling)

## Approach

Two surgical code seams, both red-first, both scoped to the provider
plugin surface (no cross-plugin contract changes, no schema migrations):

1. **`--explain` presentation layer** — `ProviderVerifyCommand` already
   builds a `ProviderVerifyReport` via `ProviderVerifier.verify`. The
   `--explain` flag adds ONE new code path: when `argResults?['explain']
   == true && argResults?['json'] != true`, print a multi-line
   human-readable block describing the registered methods, resolved
   types, and the verdict with `--> fix:` hints. The block is computed
   entirely from the existing `ProviderVerifyReport` fields — no new
   verifier API, no new AST traversal, no schema change. The `--json`
   contract is unchanged because `--json` wins when both are passed.
   This mirrors how the di plugin's `verify --explain` sibling exposes
   its scan in human form (`lib/src/plugins/di/capabilities/verify_capability.dart`).

2. **`execute()` try/catch (di/repository parity)** — wrap the body of
   `CreateProviderCapability.execute` in `try/catch` so any exception
   from `_generateFiles` returns
   `ExecutionResult(success: false, message: 'provider create failed
   for $name: $e', data: {'generatedFiles': const <GeneratedFile>[]})`
   instead of propagating. The `_emitReceipt` helper is already
   best-effort (its own try/catch with a `print('⚠️ ...')`), so the
   outer wrap is the single remaining gap. This is byte-for-byte the
   `CreateDiCapability.execute` pattern (spec 0974, issue #974 order 4).

   **Test contract migration**: the existing test
   `'minimal invocation without a service interface fails with an
   actionable message'` (in
   `test/plugins/provider/create_provider_capability_test.dart`, lines
   91-110) currently asserts `throwsA(isA<StateError>())`. After this
   change the test asserts `result.success, isFalse` plus the same
   diagnostic substrings (`CartService`,
   `domain/services/cart_service.dart`,
   `zfa service create --name Cart`). The diagnostic message that lived
   in the `StateError` body now lives in `ExecutionResult.message` —
   same content, different carrier. This is a deliberate, in-scope test
   contract migration, NOT a regression: the spec order explicitly
   demands `ExecutionResult(success:false)` instead of an unhandled
   crash, and the existing test was *encoding the B+ smell being fixed*.

## Technical Context

- **Provider plugin verify/explain**: `ProviderVerifyCommand.run()` is
  the entrypoint. It builds the `ProviderVerifyReport` via
  `const ProviderVerifier().verify(...)`, then either
  `print(jsonEncode(report.toJson()))` (when `--json`) or
  `_printText(report)` (default). `--explain` adds a third path:
  `_printExplain(report)` between the `--json` branch and the
  `_printText` fallback, gated by `--explain == true && --json != true`.
- **AST verifier**: `ProviderVerifier.scanSource` returns
  `ProviderClassScan { className, methods, stubs }`. `ProviderVerifier.
  verify` already exposes `report.methods` (the interface method set)
  and `report.findings` (with `kind`/`file`/`method`/`detail`/`fix`).
  `--explain` reads these directly — no AST re-traversal.
- **`ExecutionResult` pattern**: defined in
  `lib/src/core/plugin_system/capability.dart`. Constructor signature
  matches what `CreateDiCapability.execute` returns on failure:
  `ExecutionResult(success: false, message: ..., files: const [], data:
  {'generatedFiles': const <GeneratedFile>[]})`.
- **`di/repository` try/catch pattern**: `CreateDiCapability.execute`
  (lines 125-142 of `create_di_capability.dart`) is the reference
  implementation; the provider capability will mirror it byte-for-byte
  (only the message prefix changes: `'di create failed for $target'`
  → `'provider create failed for $name'`).
- **`ProviderVerifyReport` shape preservation**: the `--json` envelope
  `toJson` returns `{schema, ok, entity, providerFile, interface,
  methods, stubCount, findings}` — UNCHANGED. `--explain` does not add
  fields to the report; it is pure presentation.

## Files touched (code)

- `lib/src/commands/provider_verify_command.dart` — add `--explain`
  flag, add `_printExplain(ProviderVerifyReport)` method, branch in
  `run()`.
- `lib/src/plugins/provider/capabilities/create_provider_capability.dart`
  — wrap `execute()` body in `try/catch` returning
  `ExecutionResult(success:false, ...)` on exception (mirroring di).

## Files touched (tests)

- `test/plugins/provider/provider_verify_test.dart` — add 3 tests:
  `--explain` failing case, `--explain` clean case, `--explain --json`
  dominance case.
- `test/plugins/provider/create_provider_capability_test.dart` — update
  existing `throwsA(isA<StateError>())` test to assert
  `result.success, isFalse` + message content; add a NEW test
  simulating a malformed entity (missing service interface) and
  asserting graceful failure (the same #768 path but with the new
  contract — keeps the test file robust against both shapes if a future
  change re-introduces a throwing path).

## Files touched (spec-kit artifacts)

- `specs/1128-provider-explain-error-handling/spec.md` (this plan's
  parent — already authored).
- `specs/1128-provider-explain-error-handling/plan.md` (this file).
- `specs/1128-provider-explain-error-handling/tasks.md`.
- `specs/1128-provider-explain-error-handling/tdd/test-list.md`.
- `specs/1128-provider-explain-error-handling/tdd/cycle-log.md`
  (red-green-refactor evidence).
- `specs/1128-provider-explain-error-handling/tdd/verification.md`.

## Risk register

- **R1 — `--explain` output drift from `--json` envelope**: mitigated
  by deriving the explain block from the SAME `ProviderVerifyReport`
  instance (no parallel data path). The `--json` test stays as a
  regression guard.
- **R2 — Existing `throwsA(isA<StateError>())` test migration**: the
  spec order is explicit that the B+ smell being fixed is exactly this
  test encoding an unhandled crash. The migration is in scope.
- **R3 — `--explain --json` ambiguity**: contract is `--json` wins on
  stdout (machine-readable consumers must not see explain prose). A
  dedicated test pins this.
- **R4 — `dart format` gate**: pre-commit formatter must produce zero
  diffs. Verified in §5 of the verification step.

## Out of scope (deliberately)

- Changes to `ProviderVerifier` AST semantics.
- Changes to receipt writer or proof.v1 digests.
- Changes to the create capability's `inputSchema` (no new flags).
- Changes to the make post-pass hook (already has its own error path).
- Changes to `ProviderCommand` (parent plugin command).
