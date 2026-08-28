# Cycle Log — bug-532 (build verifyAnalyzeOrFail lib errors)

Baseline (pre-fix): `dart test test/commands/build_command_unit_test.dart` — the
#415 `verifyAnalyzeOrFail` test failed.

## Cycle 1 — A1 / U1 / U2 (red → green)

**RED** (pre-existing failure, observed during `dart test` full run):
```
test/commands/build_command_unit_test.dart: BuildCommand helpers ... verifyAnalyzeOrFail
  (issue #415 — invalid --fatal-infos flag) runs `dart analyze lib` ... and reports no
  errors on the current (warning/info-only) lib [E]
  Expected: true
    Actual: <false>
```
Root cause confirmed via `dart analyze lib`:
```
error - src/api/bridges/product_api_bridge.dart:9:8  - uri_does_not_exist
error - src/api/bridges/product_api_bridge.dart:11:8 - uri_does_not_exist
error - src/api/bridges/product_api_bridge.dart:44:27 - non_type_as_type_argument (GetProductUseCase)
error - src/api/bridges/product_api_bridge.dart:63:43 - undefined_class (Product)
```

**GREEN** (smallest sufficient change):
- Deleted orphaned `lib/src/api/bridges/product_api_bridge.dart` (generated bridge for a
  non-existent `Product` feature; its only references were itself and a stale doc comment).
- Removed the stale `registerProductApiBridge();` example line from the
  `lib/src/core/api_bridge.dart` doc comment (lines 40-44).

**Evidence (post-fix)**:
```
$ dart analyze lib
  ✅ dart analyze: no errors   (12 issues found, all warning/info)
$ dart test test/commands/build_command_unit_test.dart
  00:03 +40: All tests passed!
```
The #415 `verifyAnalyzeOrFail` test now passes; no other test in the file regressed.

**Refactor**: none required (deletion + doc comment cleanup only).

**Commit**: <filled after commit>

**Notes**: The wider lib still emits warnings/infos (unrelated, pre-existing); the test
tolerates them by design (it checks for *errors* only).
