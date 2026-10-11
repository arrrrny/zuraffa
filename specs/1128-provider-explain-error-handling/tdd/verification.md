# TDD Verification: 1128 — provider A+ upgrade (`--explain` + comprehensive error handling)

**Verdict: GREEN — both orders implemented and tested (red → green),
all six acceptance criteria PROVED by executed runs.**

Method: every behavior got a failing test FIRST (see `cycle-log.md`
for the red evidence — `--explain` flag rejection by argparse and the
`Bad state: No service interface found for ...` StateError propagation
through `execute()`), then the implementation, then the verification
runs below. No step below was claimed without being run in this session.

## 1. Orders → implementation

| Order | Implementation | Proved by |
|---|---|---|
| 1 — `--explain` flag on `ProviderVerifyCommand` | Registered via `argParser.addFlag('explain', negatable: false, ...)`; added `_printExplain(ProviderVerifyReport)` that emits the entity, the resolved Service interface, the provider file, the registered methods (with `[STUB]` markers on surviving stubs), the verdict (`✅ verified` / `❌ not verified`), and every `--> fix:` hint; in `run()` branched `if (--json) → jsonEncode; else if (--explain) → _printExplain; else → _printText`. `--json` wins on stdout when both are passed (no explain prose leaks into the machine envelope). Verifier semantics unchanged — block derived entirely from `ProviderVerifyReport` fields. | B1, B2, B3 tests (3 new), real-CLI demo §3.1 |
| 2 — `execute()` try/catch wrap | `CreateProviderCapability.execute` now wraps `_generateFiles` in `try/catch` returning `ExecutionResult(success: false, message: 'provider create failed for $name: $e', data: {'generatedFiles': const <GeneratedFile>[]})` on exception (byte-for-byte the `CreateDiCapability.execute` pattern from spec 0974, issue #974 order 4). `_emitReceipt` is already best-effort (its own try/catch with `print('⚠️ ...')`), so the outer wrap is the single remaining gap. | B4, B4b tests (2 new), error-handling proof §3.2 |
| 3 — `--explain` test in `provider_verify_test.dart` | 3 new tests added under a dedicated `group('zfa provider verify --explain (spec 1128 order 1)')`: failing case (entity/interface/file/methods/verdict/`--> fix:`), clean case (`✅ verified`, no `--> fix:`), `--explain --json` dominance case (single JSON object, no explain prose). | run below §2.1 |
| 4 — error-handling test in `create_provider_capability_test.dart` | Migrated the existing `throwsA(isA<StateError>())` test to assert `result.success, isFalse` + the same diagnostic substrings (`CartService`, `domain/services/cart_service.dart`, `zfa service create --name Cart`) carried in `ExecutionResult.message` instead of the StateError body. Added a second test for the broader malformed-entity contract (`MissingThing` entity). | run below §2.2 |

## 2. Test runs (ACTUAL counts)

### 2.1 `provider_verify_test.dart`

```
$ dart test test/plugins/provider/provider_verify_test.dart
00:00 +9: All tests passed!
```

- 9 tests, **9 PASS / 0 FAIL / 0 SKIP**.
- 6 pre-existing tests (stub gate pos/neg, conformance pos/neg,
  missing-provider-file, `--json` envelope) — all green (NO regression
  in verifier semantics).
- 3 NEW spec-1128 tests (`--explain` failing case, `--explain` clean
  case, `--explain --json` dominance) — all green.

### 2.2 `create_provider_capability_test.dart`

```
$ dart test test/plugins/provider/create_provider_capability_test.dart
00:00 +5: All tests passed!
```

- 5 tests, **5 PASS / 0 FAIL / 0 SKIP**.
- 1 migrated error-handling test (was `throwsA(isA<StateError>())`,
  now `result.success, isFalse` + message-content asserts) — green.
- 1 NEW spec-1128 error-handling test (`MissingThing` malformed-entity
  path) — green.
- 3 pre-existing happy-path tests (schema default, happy generation,
  `--no-data` opt-out) — all green.

### 2.3 `dart analyze` (changed files only)

```
$ dart analyze lib/src/commands/provider_verify_command.dart \
               lib/src/plugins/provider/capabilities/create_provider_capability.dart \
               test/plugins/provider/create_provider_capability_test.dart \
               test/plugins/provider/provider_verify_test.dart
Analyzing provider_verify_command.dart, create_provider_capability.dart,
create_provider_capability_test.dart, provider_verify_test.dart...
No issues found!
```

### 2.4 `dart format` gate (CI format gate)

```
$ dart format --output=none --set-exit-if-changed \
    lib/src/commands/provider_verify_command.dart \
    lib/src/plugins/provider/capabilities/create_provider_capability.dart \
    test/plugins/provider/create_provider_capability_test.dart \
    test/plugins/provider/provider_verify_test.dart
Formatted 4 files (0 changed) in 0.02 seconds.
# exit code 0 = zero formatting diffs
```

## 3. Acceptance-criteria → evidence

### AC-1: `zfa provider verify <Entity> --explain` emits the explanation block — PROVED

#### 3.1 Explain-output demo (real in-process run against a temp project)

```
$ zfa provider verify Product --explain   (in-process; failing provider:
                                           ProductProvider has `execute`
                                           stubbed + `rollback` missing)

Provider Verify — Explain — Product
  entity        : Product
  interface     : ProductService
  provider file : <temp>/lib/src/data/providers/product_provider.dart
  methods       : 2 registered
    - execute [STUB]
    - rollback
  stub count    : 1
  verdict       : ❌ not verified — 2 finding(s).

  hints:
    [stub] execute: ProductProvider.execute still throws
                    UnimplementedError — the stub body shipped with
                    generation was never filled
      file: <temp>/lib/src/data/providers/product_provider.dart
      --> fix: implement execute in <temp>/lib/src/data/providers/product_provider.dart
               (the TDD flow fills generated stubs), or regenerate with
               `zfa provider create --name Product --force`.
    [missing_method] rollback: ProductProvider does not implement
                               ProductService.rollback — the provider is
                               missing an interface member (the #921 guard,
                               provider analog)
      file: <temp>/lib/src/data/providers/product_provider.dart
      --> fix: implement rollback on ProductProvider — `zfa provider create
               --name Product --force` regenerates the mirror, or add the
               member by hand.
```

Block contains: entity ✓, interface ✓, provider file ✓, registered
methods (with `[STUB]` markers) ✓, verdict ✓, `--> fix:` hints ✓.
Test `--explain on a failing provider prints a human-readable block
naming entity, interface, provider file, registered methods, verdict,
and --> fix: hints` is green.

### AC-2: `zfa provider verify <Entity> --json` envelope shape unchanged — PROVED

The existing `--json emits a single machine verdict object with
schema/ok/findings` test (originally added in spec 979) is **still green**
with zero modifications. The envelope emitted is exactly:

```json
{"schema":1,"ok":false,"entity":"Product","providerFile":"...","interface":"ProductService","methods":["execute","rollback"],"stubCount":1,"findings":[...]}
```

No new fields, no renamed fields, no removed fields. `ProviderVerifyReport.
toJson` is byte-for-byte unchanged (no diff in this PR touches it).

### AC-3: `--explain --json` together → `--json` dominates — PROVED

Real run (in-process; same failing provider):

```
$ zfa provider verify Product --explain --json
{"schema":1,"ok":false,"entity":"Product","providerFile":"...","interface":"ProductService","methods":["execute","rollback"],"stubCount":1,"findings":[...]}
# exit 1
```

Stdout contains exactly ONE JSON object. The explain prose block
(`Provider Verify — Explain — Product`, the `entity:`/`interface:`/...
lines, the `hints:` section) is **NOT** present — `--json` wins on
stdout. Test `--explain --json together: --json dominates — single
machine envelope on stdout, no explain prose` is green.

### AC-4: Malformed entity does not crash with uncaught exception — PROVED

#### 3.2 Error-handling proof (real test run)

```
$ dart test test/plugins/provider/create_provider_capability_test.dart \
    --name "missing service interface|missing provider file|malformed entity"
00:00 +2: All tests passed!
# 2/2 PASS — the migrated test (Cart) and the new test (MissingThing)
```

The Cart test asserts:
- `result.success, isFalse` — the contract: graceful failure, no throw.
- `result.files, isEmpty` — no files reported.
- `result.message` contains `provider create failed`, `CartService`,
  `domain/services/cart_service.dart`, `zfa service create --name Cart`
  — same actionable diagnostics the B+ `StateError` body carried, now
  in `ExecutionResult.message`.

The MissingThing test asserts the broader malformed-entity contract:
`result.success, isFalse` + actionable `result.message` + `result.files,
isEmpty`.

Pre-impl red (recorded in `cycle-log.md`): both tests failed with
`Bad state: No service interface found for ...` propagating as an
uncaught StateError through `execute()`. Post-impl: both tests green
with the try/catch wrap returning `ExecutionResult(success:false)`.

### AC-5: No regression in verifier semantics — PROVED

The pre-existing tests in `provider_verify_test.dart` (stub gate
positive/negative, conformance positive/negative, missing-provider-file
path, `--json` envelope) all remain green in §2.1's run (6/6 passed,
zero modifications). The `ProviderVerifier.scanSource` and
`ProviderVerifier.verify` methods are byte-for-byte unchanged (no diff
in this PR touches `provider_verifier.dart`).

### AC-6: `dart analyze` clean + `dart format` zero diffs — PROVED

§2.3 (analyze: `No issues found!`) and §2.4 (format: exit 0, zero
changed files) cover this on the 4 changed `.dart` files.

## 4. Mutation evidence (test-strength sanity check)

The two new behaviors have test assertions that are specific enough to
fail under any of the following mutations — i.e. the tests are not
vacuous:

- **M1**: Drop the `--explain` branch in `run()` (fall through to
  `_printText`). → B1/B2 fail: stdout no longer contains
  `Provider Verify — Explain` (the explain-specific header). → B3 still
  passes (because `--json` still wins).
- **M2**: Make `--explain` print the JSON envelope instead of the
  human block. → B1/B2 fail: stdout no longer contains
  `Provider Verify — Explain` or `--> fix:` prose outside findings.
- **M3**: In `_printExplain`, drop the `--> fix:` hints section.
  → B1 fails: `result.output, contains('--> fix:')` is asserted.
- **M4**: Make `--explain` win over `--json` (swap the if/else). → B3
  fails: `result.output, isNot(contains('Provider Verify — Explain'))`
  is asserted.
- **M5**: Drop the try/catch in `execute()`. → B4/B4b fail: the
  StateError propagates again, `result.success` is unreachable.
- **M6**: Catch but swallow the exception (return
  `ExecutionResult(success: true, ...)`). → B4/B4b fail:
  `result.success, isFalse` is asserted.
- **M7**: Catch and return `ExecutionResult(success: false)` but with
  an empty message. → B4 fails: `result.message` must contain
  `CartService` + `domain/services/cart_service.dart` +
  `zfa service create --name Cart`.

All seven mutations would flip at least one green test red — the
behaviors are honestly pinned by the tests, not by incidental
assertions.

## 5. Files changed in this PR

```
lib/src/commands/provider_verify_command.dart                                | +67
lib/src/plugins/provider/capabilities/create_provider_capability.dart         | +25/-2
test/plugins/provider/create_provider_capability_test.dart                     | +87/-13
test/plugins/provider/provider_verify_test.dart                                | +126
specs/1128-provider-explain-error-handling/spec.md                            | new
specs/1128-provider-explain-error-handling/plan.md                            | new
specs/1128-provider-explain-error-handling/tasks.md                           | new
specs/1128-provider-explain-error-handling/tdd/test-list.md                   | new
specs/1128-provider-explain-error-handling/tdd/cycle-log.md                    | new
specs/1128-provider-explain-error-handling/tdd/verification.md                 | new
```

## 6. Pre-existing failures flagged

Cloud-agent discipline: only the files this PR touched were analyzed
and tested (per spec §5). No pre-existing failures were observed in
the four changed files. The full test suite was NOT run (the spec
explicitly forbids it: "Cloud agents MUST only run tests for files
they modified — never the full suite. The full suite compiles a
~6.5 GB kernel cache that overflows small disks and takes too long on
low-resource machines").
