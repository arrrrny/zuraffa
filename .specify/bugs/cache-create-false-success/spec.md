# Spec: `cache create` false-success on nonexistent entity (Issue #772)

## Context

`zfa cache create --name cart` in a project where `cart` does not exist prints
`✅ Success! (No changes required)` and exits 0 — zero files, no warning, no
validation. The sibling `zfa cache adapter` correctly fails with
`Entity 'cart' not found.` + an `Available entities:` list.

## Root cause (code-traced)

`CreateCacheCapability._generateFiles` builds
`GeneratorConfig(enableCache: true, ...)` and calls `plugin.generate(config)`
without ever checking that the named entity exists. The generator finds no
entity file and returns an empty file list; `CapabilityCommand.run()` renders
its empty-files branch as success. `execute()` also has no try/catch, so even
a thrown validation error today would escape as a raw CLI error instead of the
capability-owned failure shape the adapter uses.

## Requirements

- **FR-1**: `cache create --name <X>` where `X` has no entity file MUST NOT
  report success. It MUST fail with a message containing
  `Entity '<X>' not found.` and, when entities exist, an
  `Available entities:` list (same shape as `cache adapter`).
- **FR-2**: The adapter's enum fallback semantics MUST be mirrored: an entity
  name that resolves via the enums directory (index or per-file `enum <Name>`)
  counts as found.
- **FR-3**: An existing entity MUST still generate as before (validation only
  rejects names that resolve to nothing).
- **FR-4**: `CreateCacheAdapterCapability` MUST remain untouched (its
  integration contract is proven; no regression surface).

## RED criteria (test first, must fail on master)

`test/plugins/cache/create_cache_capability_validation_test.dart` (fast unit
tests against a temp workspace; validation fires before any heavy generation):

1. `execute({'name': 'Ghost'})` on an empty workspace → `success == false`
   and message contains `Entity 'Ghost' not found`. Pre-fix: `success == true`
   with zero files (the false success).
2. With a sibling entity `auth` present, the failure message lists `Auth`
   under `Available entities:`. Pre-fix: no failure at all.
3. Guard: with `domain/entities/product/product.dart` present, the capability
   must NOT fail with a not-found error (validation accepts real entities).

## GREEN criteria

1–3 pass; `dart analyze` clean; `dart format` clean; existing cache tests and
the surrounding command/plugin suites pass.

## Out of scope

- Extracting the adapter's resolver into a shared helper (DRY follow-up) —
  deliberately deferred to keep the proven adapter code untouched.
- Validation UX for other capability families (#766/#768/#770 track their own
  silent-no-op root causes).
