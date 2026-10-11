# TDD Cycle Log: 1128 — provider A+ upgrade (`--explain` + comprehensive error handling)

Method: every behavior on `tdd/test-list.md` got a failing test FIRST,
then the implementation, then a green re-run. No step below was claimed
without being run in this session. Times are wall-clock; commands are
the literal invocation.

## Phase 1 — RED (pre-impl)

```
$ dart test test/plugins/provider/provider_verify_test.dart --name "explain"
```

Result: **3 failed / 0 passed**.

Failing tests:

| # | Behavior (test-list.md) | Red evidence |
|---|-------------------------|-------------|
| B1 | `--explain` on a failing provider prints block | `Could not find an option named "--explain".` (argparse rejects the unregistered flag before any output is printed) |
| B2 | `--explain` on a clean provider prints block w/ `✅` | same — `--explain` flag absent |
| B3 | `--explain --json` together → `--json` dominates | same — `--explain` flag absent |

```
$ dart test test/plugins/provider/create_provider_capability_test.dart
```

Result: **2 failed / 3 passed** (the 3 pre-existing happy-path tests
were green; only the new error-handling tests failed).

Failing tests:

| # | Behavior (test-list.md) | Red evidence |
|---|-------------------------|-------------|
| B4 | missing-service-interface (the #768 path) returns `ExecutionResult(success:false)` | `Bad state: No service interface found for CartService. ... zfa service create --name Cart` — the StateError propagates uncaught through `execute()`; the `result.success, isFalse` assertion is unreachable |
| B4b | malformed entity (`MissingThing`) does not crash | `Bad state: No service interface found for MissingThingService. ... zfa service create --name MissingThing` — same propagation |

## Phase 2 — GREEN (post-impl)

Implementation diff (2 files):

- `lib/src/commands/provider_verify_command.dart` — registered
  `--explain` flag; added `_printExplain(ProviderVerifyReport)`; in
  `run()` branched `if (--json) → jsonEncode; else if (--explain) →
  _printExplain; else → _printText`. Exit code unchanged
  (`report.ok ? 0 : 1`). No new verifier calls — the block is derived
  entirely from the existing `ProviderVerifyReport` fields (`entity`,
  `interface`, `providerFile`, `methods`, `stubFindings`, `stubCount`,
  `ok`, `findings`).
- `lib/src/plugins/provider/capabilities/create_provider_capability.dart`
  — wrapped the `_generateFiles` call in `try/catch`, returning
  `ExecutionResult(success: false, message: 'provider create failed
  for $name: $e', data: {'generatedFiles': const <GeneratedFile>[]})`
  on exception (byte-for-byte the `CreateDiCapability.execute` pattern
  from spec 0974, issue #974 order 4). `_emitReceipt` is already
  best-effort; no other change needed.

Test re-runs:

```
$ dart test test/plugins/provider/provider_verify_test.dart
```
Result: **9/9 passed** (6 pre-existing + 3 new explain).

```
$ dart test test/plugins/provider/create_provider_capability_test.dart
```
Result: **5/5 passed** (1 migrated error-handling test + 1 new
error-handling test + 3 pre-existing happy-path tests).

## Phase 3 — REFACTOR

Reviewed the diff for duplication and dead branches:

- `_printExplain` and `_printText` share the finding-loop pattern but
  differ enough (the explain block lists entity/interface/file/methods
  /verdict first; the text path lists only findings) that factoring
  a shared helper would obscure both. Left as-is.
- The try/catch wrap is the minimal di/repository parity — no
  short-circuit, no extra logging, no behavior change on the happy
  path. `_emitReceipt` stays best-effort (already has its own try/catch
  with a `print('⚠️ ...')` fallback).
- `dart analyze` on the 4 changed `.dart` files → `No issues found!`.
- `dart format --output=none --set-exit-if-changed` on the 4 files →
  exit 0 (zero formatting diffs).

## Phase 4 — REGRESSION GUARD

- The existing `--json` envelope test (B6 in test-list.md) — still green.
  Verified `dart test test/plugins/provider/provider_verify_test.dart
  --name "single machine verdict"` → 1/1 passed.
- The existing stub/conformance positive/negative tests (B7) — still
  green. Verified in the full-file re-run above (tests #1-#5).
- The `explicit opt-out (--no-data) is still honored` happy-path test
  (B5) — still green.

## Phase 5 — CROSS-ARTIFACT CONSISTENCY

- `tdd/test-list.md` lists 8 behaviors (B1-B8). B1-B4 are the new
  red→green transitions; B5-B7 are regression guards; B8 is the
  format/analyze gate.
- `tasks.md` T1-T8 each map to a behavior in `test-list.md`.
- `plan.md` Files-touched (code) and Files-touched (tests) match the
  actual diff exactly (2 lib files + 2 test files).
- `spec.md` AC-1 through AC-6 each have at least one behavior proving
  them. Coverage matrix at the bottom of `test-list.md` is consistent.
