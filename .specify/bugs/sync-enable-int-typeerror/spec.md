# Spec: schema-typed capability args arrive as raw Strings — `sync enable` TypeError (Issue #773)

## Context

`zfa sync enable --name Auth` (valid entity name, zero flags — the manifest's own
defaults) exits 1 with a raw `TypeError`:

```
❌ Error: type 'String' is not a subtype of type 'int'
#0  CreateSyncCapability._generateFiles (create_sync_capability.dart:113)
```

Reproduced on master `6921c730` in a scratch package (pre-fix evidence).

## Root cause (verified)

`CapabilityCommand` registers schema-driven options with
`argParser.addOption(flagName, defaultsTo: def?.toString())`, so the `integer`
property `batchSize` (schema default `50`) becomes an option default `'50'` — a
**String**. In `run()`, option values are copied into the capability args
without type coercion; an option with a default is never null, so
`args['batchSize'] == '50'` (String) even when the user passed no flags.
`CreateSyncCapability._generateFiles` then builds
`GeneratorConfig(syncBatchSize: '50')` → `TypeError`.

The same defect class affects every capability that declares `integer`/`number`
properties, whether the value comes from an option default, an explicit CLI
flag (`--batch-size 30` is also a String), or a `--json` payload string.

## Requirements

- **FR-1**: Values supplied through `CapabilityCommand` for properties whose
  JSON-Schema type is `integer` MUST arrive at the capability as `int`
  (`'50'` → `50`), regardless of source (flag, option default, JSON string).
- **FR-2**: `number`-typed properties MUST arrive as `num` (`double` parse).
- **FR-3**: String-typed properties MUST stay `String` (no over-coercion);
  booleans stay `bool`.
- **FR-4**: A value that cannot be parsed for its declared type is passed
  through unchanged (no new validation contract in this fix; capabilities
  keep owning their validation and error UX).
- **FR-5**: After the fix, `zfa sync enable --name Auth` on a scratch package
  must no longer crash with the raw `TypeError` (it may legitimately fail
  later with an actionable message, e.g. entity not found).

## RED criteria (test first, must fail on master)

`test/commands/capability_command_type_coercion_test.dart`:

1. Explicit flag: `run(['cap', 'Auth', '--batch-size', '30'])` → capability
   receives `batchSize` as `int 30`. Currently fails (`'30'`).
2. Schema default (the exact #773 shape): `run(['cap', 'Auth'])` → capability
   receives `batchSize` as `int 50`, `maxRetries` as `int 5`. Currently fails
   (`'50'`/`'5'`).
3. Guard: `direction` (type `string`, default `'push'`) stays `String`.

## GREEN criteria

1–3 pass; real-CLI repro no longer throws `TypeError` (FR-5); surrounding
suites (`test/commands/`, `test/cli/`, `test/plugins/sync/` if present) pass;
`dart analyze` clean on touched files; `dart format` clean.

## Out of scope

- Coercing array element types (`items:` schema) — no known affected path.
- Adding first-class validation/error messaging for unparseable numeric input.
- Replacing the `def?.toString()` option defaults (the normalization pass
  handles them; changing parser wiring risks broader fallout).
