# TDD Test List: 1128 — provider A+ upgrade (`--explain` + comprehensive error handling)

Derived from `spec.md` orders 1-4 and `plan.md` seams 1-2. Every
behavior gets a failing test FIRST (red → green), driven through the
public seams (`ProviderVerifyCommand.run`, `CreateProviderCapability.
execute`). Behaviors are scoped to the two A+ features only; the
existing B+ behaviors (stub gate, conformance gate, `--json` envelope,
receipt, provenance header) are regression-guards, not new red.

| # | Behavior | Test file | Red evidence (pre-impl) | AC |
|---|----------|-----------|-------------------------|----|
| B1 | `zfa provider verify <Entity> --explain` prints a human-readable block naming the entity, the resolved interface, the provider file, the registered methods, the verdict, and `--> fix:` hints on a FAILING provider | `test/plugins/provider/provider_verify_test.dart` | `--explain` flag not registered → `CommandRunner` raises `UnrecognizedFlagException`/`ArgParser`-equivalent before any output is printed | AC-1 |
| B2 | `zfa provider verify <Entity> --explain` on a CLEAN provider (no stubs, no missing methods) prints the same block but with a `✅ verified` line and no `--> fix:` hints | `test/plugins/provider/provider_verify_test.dart` | same as B1 (flag absent) | AC-1 |
| B3 | `zfa provider verify <Entity> --explain --json` is dominated by `--json` — single machine envelope on stdout, no explain prose lines | `test/plugins/provider/provider_verify_test.dart` | same as B1 (flag absent) + once `--explain` exists, the test asserts the stdout is exactly ONE JSON object (no header line, no registered-methods block, no `--> fix:` prose outside the JSON `findings[].fix` field) | AC-2, AC-3 |
| B4 | `CreateProviderCapability.execute` with a missing service interface (the #768 malformed-entity path) returns `ExecutionResult(success: false, message: ...)` containing `CartService` + `domain/services/cart_service.dart` + `zfa service create --name Cart`, with `files: isEmpty` — DOES NOT throw | `test/plugins/provider/create_provider_capability_test.dart` | currently the path throws `StateError`; the test asserts `result.success, isFalse` so it FAILS red before the impl wrap | AC-4 |
| B5 | `CreateProviderCapability.execute` happy path (service exists) still returns `ExecutionResult(success: true, files: isNotEmpty)` — no false-negative regression from the wrap | `test/plugins/provider/create_provider_capability_test.dart` | already green (test exists, asserts `result.success, isTrue`); re-run as a regression guard after T4 | AC-4 (negative case) |
| B6 (regression) | `zfa provider verify <Entity> --json` envelope shape unchanged — `{schema:1, ok, entity, providerFile, interface, methods, stubCount, findings}` | `test/plugins/provider/provider_verify_test.dart` | already green; MUST stay green after T3 | AC-2, AC-5 |
| B7 (regression) | Stub gate positive/negative + conformance gate positive/negative + missing-provider-file path — all green | `test/plugins/provider/provider_verify_test.dart` | already green; MUST stay green after T3 | AC-5 |
| B8 (non-behavioral) | `dart analyze` clean on changed `lib/` files; `dart format .` zero diffs | n/a (gate) | n/a | AC-6 |

## Coverage matrix

- AC-1 (explain block, failing case) ← B1
- AC-1 (explain block, clean case) ← B2
- AC-2 (--json envelope unchanged) ← B3, B6
- AC-3 (--explain --json dominance) ← B3
- AC-4 (malformed entity graceful failure) ← B4, B5
- AC-5 (no regression in verifier semantics) ← B6, B7
- AC-6 (format + analyze gate) ← B8

Every acceptance criterion has at least one behavior. Every behavior
maps to at least one test. The cycle (`tdd/cycle-log.md`) records the
red evidence per behavior before its green.
