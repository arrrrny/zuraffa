# Bug Fix: zfa entity create: primitive types (bool/int/double) rejected — must scaffold an enum dir first

- **Slug**: entity-create-primitive-types-rejected (GitHub issue #1270)
- **Fixed**: 2026-09-07
- **Assessment**: ./assessment.md
- **Verification**: ./tdd/verification.md
- **Status**: applied

## Summary

The entity-create type-resolution path had no built-in primitive recognition
for user-written type aliases: `Boolean` — the natural spelling for Dart's
`bool` used in the issue repro — is uppercase-first and absent from the
`EntityUtils.extractEntityTypes` exclusion list, so it was classified as a
custom entity reference and `EntityTypeValidator` demanded an entity
directory / enum file that no Dart built-in will ever have. `entity create`
aborted with `Unknown type "Boolean" … no matching entity directory or enum
file found` and wrote nothing.

Fix (inline-primitive remediation): the parsed field type is normalized at
the shared resolution point before validation and emission. The `boolean`
token (case-insensitive, word-bounded) is rewritten to the built-in `bool`,
so the alias is recognized as a primitive and the generated entity declares
the built-in directly (`bool get isLoading;`). `bool`/`int`/`double`/
`String`/`num` spellings already resolved and emitted directly — they are
pinned by tests and are identity mappings. Non-primitive resolution
(entity dir / enum file lookup, self-reference, external `!` types, forward
refs) is untouched.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/utils/entity_utils.dart` | added | `EntityUtils.normalizePrimitiveTypeAliases(String type)` — rewrites the `boolean` token case-insensitively at word boundaries to `bool` inside a field type expression; custom types whose name merely contains the alias (`BooleanFilter`) and all other tokens are untouched. |
| `lib/src/commands/entity_command.dart` | modified | `_parseFields` (shared by `entity create` and `entity add-field`) now applies the normalizer to the parsed field TYPE via `parsed.copyWith(type: ...)` before validation/emission. Field names and JSON wire names are never rewritten. |
| `test/commands/entity_create_primitive_types_test.dart` | added | 8 tests: the exact issue repro (exit 0 + inline `bool` getters), all five core primitives inline, alias forms in generics/nullability, add-field parity, custom-type rejection unchanged, and the normalizer's unit contract (case variants, word boundaries, built-ins/custom types untouched). |

## Constraints honored

- Only the entity create type resolution changed (one pure function + one
  call site); the entity model and existing non-primitive resolution logic
  are untouched.
- Existing entity creation for custom types is regression-pinned by the new
  B5 test and the untouched validator suite.
- One PR per bug.
