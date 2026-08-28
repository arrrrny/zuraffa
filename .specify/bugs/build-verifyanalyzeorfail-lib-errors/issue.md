# GitHub Issue — build-verifyanalyzeorfail-lib-errors

- **URL**: https://github.com/arrrrny/zuraffa/issues/532
- **Repo**: arrrrny/zuraffa
- **Created**: 2026-08-28
- **Labels**: bug
- **Filed via**: `gh issue create` (auto_create_issue: true in .specify/extensions/bug/bug-config.yml)
- **Linked assessment**: .specify/bugs/build-verifyanalyzeorfail-lib-errors/assessment.md

## Title

Test build_command_unit_test.dart:589 (verifyAnalyzeOrFail) fails — orphaned generated product_api_bridge.dart breaks dart analyze lib

## Summary

The regression test `verifyAnalyzeOrFail` (issue #415) at `test/commands/build_command_unit_test.dart:589`
fails on both Linux and macOS because `lib` genuinely has 2 analysis errors from an orphaned generated
`product_api_bridge.dart` whose imported `Product` entity/usecase files do not exist.

## Root cause

`lib/src/api/bridges/product_api_bridge.dart` imports
`../../domain/usecases/product/get_product_usecase.dart` and
`../../domain/entities/product/product.dart`, neither of which exists (no
`lib/src/domain/entities/` or `lib/src/domain/usecases/` directory in the repo).
The analyzer reports `uri_does_not_exist` plus `non_type_as_type_argument`/`undefined_class`
for `GetProductUseCase`/`Product`. `BuildCommand.verifyAnalyzeOrFail` is correct; the test
correctly surfaces a real broken `lib/`.

## Proposed remediation

- Preferred (if Product is not intended): delete `lib/src/api/bridges/product_api_bridge.dart`
  and clean up the stale doc comment at `lib/src/core/api_bridge.dart:43`.
- Alternative (if Product is intended): regenerate via `zfa entity create Product` →
  `zfa make Product --preset=crud` → `zfa api Product` → `zfa build`.
- Do not weaken the test.
