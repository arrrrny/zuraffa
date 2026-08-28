---
feature: bug-532-build-verifyanalyze
planned_at: "625c669e"
suite_baseline: red
verification: specs/bug-532-build-verifyanalyze/tdd/verification.md
---

# TDD Test List — bug-532 (build verifyAnalyzeOrFail lib errors)

Behaviors derived from the bug assessment, not from the existing code. One behavior
per acceptance criterion; the observable result is checked through the real entry
point (the `dart analyze lib` run that `verifyAnalyzeOrFail` performs).

## Outer loop (acceptance behaviors)

| id | behavior | traces | kind | runner |
| --- | --- | --- | --- | --- |
| A1 | `dart analyze lib` on the current repo reports **no errors** (only warnings/infos), so `BuildCommand.verifyAnalyzeOrFail` returns true | AC1 | example | `dart test test/commands/build_command_unit_test.dart` |

## Inner loop (unit behaviors)

| id | component | behavior | traces | kind | test |
| --- | --- | --- | --- | --- | --- |
| U1 | `lib/src/api/bridges/product_api_bridge.dart` | Orphaned generated bridge referencing non-existent `Product`/`GetProductUseCase` is removed so it no longer contributes analyzer errors | AC1 | characterization | `dart analyze lib` (no `error` lines for this file) |
| U2 | `lib/src/core/api_bridge.dart` doc comment | Stale `registerProductApiBridge()` example removed (function/file no longer exists) | AC1 | example | doc-only; covered by analyze |

## Unplaced / edge cases

- None.

## Out of scope

- Regenerating a real Product bridge; silencing remaining warnings/infos.

## Verification commands (from tdd-profile)

- Single test: `dart test test/commands/build_command_unit_test.dart`
- Suite: `dart test`
- Analyzer: `dart analyze lib` (expect: no `error` lines)
