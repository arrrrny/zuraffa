# Bug Fix: 1720-vpc-usecase-casing-dry-run

- **Slug**: 1720-vpc-usecase-casing-dry-run
- **Fixed**: 2026-09-18
- **Branch**: fix/1720-vpc-usecase-casing-dry-run
- **Issue**: ./issue.md
- **Assessment**: ./assessment.md
- **Verification**: ./tdd/verification.md

---

## Summary

`--usecases` tokens are now normalized to the canonical PascalCase class name
(`LoginUseCase`, `SignInWithGoogleUseCase`) at every emission site, so the
generated presenter/controller/DI/orchestrator code references the real
classes its own imports declare, and the test builder's class-declaration
check finds existing usecases — eliminating the permanent "Generating
placeholder Fake…UseCase … interface not declared" reports (dry-run and real
runs alike).

## Root Cause (see assessment.md for detail)

1. Token casing flowed into class references as-is: `login` → `loginUseCase`.
2. The `UseCase` suffix was appended unconditionally in the test builder →
   `LoginUseCase` → `LoginUseCaseUseCase`, so the AST class lookup never
   matched a real declaration.

## Remediation

One canonical normalizer, applied at all four (previously duplicated) sites:

- **`lib/src/utils/string_utils.dart`** — new
  `StringUtils.normalizeUseCaseClassName(token)`: strip one trailing
  `UseCase`, `convertToPascalCase` the base (snake_case/camelCase → PascalCase),
  append exactly one `UseCase`.
- **`lib/src/core/builder/patterns/common_patterns.dart`**
  (`CommonPatterns.parseUseCaseInfo`) — `className` normalized;
  `fieldName`/`usecaseSnake` keep the historical raw-token derivation so field
  names and import paths are byte-identical to before.
- **`lib/src/plugins/test/builders/test_builder_orchestrator.dart`** — fake
  class/interface/variable identifiers derived from the normalized name
  (fixes suffix doubling AND the always-failing class-declaration check).
- **`lib/src/plugins/di/di_plugin.dart`** (`_generateOrchestratorUseCaseDI`) —
  registration type refs normalized.
- **`lib/src/plugins/usecase/generators/custom_usecase_generator_orchestrator.dart`** —
  orchestrator field/param types normalized.

## Constraints Honored

- Only usecase reference casing + dry-run detection changed; presenter/
  controller structure untouched.
- `--usecases` token parsing input contract untouched (all previously
  accepted token forms remain accepted; comma/multi-option splitting
  unchanged).
- No suffix doubling when the full class name is provided.
- Generated code compiles with `dart analyze` (proved on a fully-resolvable
  project — see tdd/verification.md).

## Behavior Change Matrix

| `--usecases` token | Before (presenter type ref) | After |
|--------------------|------------------------------|-------|
| `login`            | `loginUseCase` ✗            | `LoginUseCase` ✓ |
| `sign_in_with_google` | `sign_in_with_googleUseCase` ✗ | `SignInWithGoogleUseCase` ✓ |
| `LoginUseCase`     | `LoginUseCase` ✓ (presenter) / `LoginUseCaseUseCase` ✗ (test fakes) | `LoginUseCase` ✓ everywhere |
| `loginUseCase`     | `loginUseCaseUseCase` ✗     | `LoginUseCase` ✓ |

Dry-run/test-generation detection:

| State | Before | After |
|---|---|---|
| usecase file exists, declares class | `⚠️ Generating placeholder … interface not declared` (always) | real fake emitted, no warning |
| usecase file missing | `⚠️ … source file not found on disk` (graceful placeholder) | unchanged (correct graceful path) |
