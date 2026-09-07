# Assessment — issue #1270: entity create rejects primitive types

## Summary

`zfa entity create` only resolves field types from existing entity directories
or enum files under `lib/src/domain/entities/`. Field types written as
primitives — `Boolean` in the issue repro, and the primitive family generally
(`bool`, `int`, `double`, `String`, `num`) — are rejected with
`Unknown type … no matching entity directory or enum file found`, forcing
users to scaffold an enum/entity directory for Dart built-ins or fall back to
computed getters.

## Root cause

The type-resolution entry point for `entity create` field strings is
`EntityCommand._parseFields` → `FieldDefinition.parse`, followed by
`EntityTypeValidator.validate`:

- `EntityTypeValidator` resolves a type against (a) the primitive exclusion
  list in `EntityUtils.extractEntityTypes`, (b) an existing entity directory
  `<outputDir>/<snake(type)>/<snake(type)>.dart`, or (c) an existing enum file
  `<outputDir>/enums/<snake(type)>.dart`.
- There is no built-in primitive recognition step for user-written type
  aliases: `Boolean` (the natural spelling many users — and other ecosystems —
  use for Dart's `bool`) is not in the exclusion list, is uppercase-first, so
  `extractEntityTypes` classifies it as a CUSTOM entity reference and the
  validator demands a directory/enum that no built-in will ever have.

Empirically (verified on this branch): `bool`, `int`, `double`, `num`,
`String` already resolve and are emitted directly as Dart built-ins; the
broken surface is the `Boolean` alias (and it fails in both `entity create`
and `entity add-field`, which share `_parseFields`).

## Remediation (preferred: inline primitives)

Add support for primitive types directly — inline approach preferred:
primitives are Dart built-ins and must not require directory scaffolding.

1. **Recognize** `bool`/`Boolean`, `int`, `double`, `String`, `num` as
   built-in primitive types in the entity create type-resolution path.
2. **Emit** `bool`/`int`/`double`/`String`/`num` directly in the generated
   entity (`bool get isLoading;`) — never as a directory reference and never
   as an unresolvable alias token. `bool`/`Boolean` → `bool`; the rest are
   identity mappings (already emitted directly).
3. **Not break** existing entity creation for custom types: non-primitive
   type resolution (entity directory / enum file lookup, self-reference,
   external `!` types, forward refs) is unchanged.

## Hard constraints

- Fix ONLY the type resolution in entity create.
- Do NOT restructure the entity model.
- Do NOT change existing type resolution logic for non-primitives.
- One PR per bug.
