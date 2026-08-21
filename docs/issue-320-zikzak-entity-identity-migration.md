# Issue #320 — zik_zak entity-identity migration guide

> Framework gaps filled: **auto-generated uuid id** (`@Zorphy(autoId: true)`),
> **ValueObject third kind** (`@ZValueObject`), and a **loud no-id error** that
> kills the silent first-field id fallback (the #307 root cause). This guide
> classifies zik_zak's 88 id-less entities and gives the migration recipe.

## Status

The framework work landed across two coordinated PRs and the zorphy repo:

| Layer | Where | Commit / PR | What it adds |
|-------|-------|-------------|--------------|
| Annotation | `zorphy_annotation` (`development` branch) | `63510ea` | `ZorphyKind { entity, valueObject }`, `@Zorphy(autoId: true)`, `@ZValueObject` const alias |
| Builder | `zorphy` (`fix/310-determine-prefix-comment-safe` branch) | `727a8c6` | `autoId` → constructor `id ??= const Uuid().v4()`; uuid import; `kind` read from annotation |
| zfa CLI | zuraffa PR #322 → `87fc008` | merged 2026-08-14 | `--auto-id`, `--kind=value_object`, `EntityIdResolution`, loud no-id error in `zfa make` |
| Enum imports | zuraffa PR #324 → `2c037f6` | merged 2026-08-14 | enum barrel imports for signature types (the #321 half) |

zik_zak is **unaffected** until you run the migration below — no entity changes ship
unless you re-model them. The `zfa make` loud error will fire on the first id-less
entity you rebuild, which is the intended forcing function.

## The three identity kinds

Every `@Zorphy()`-annotated class now resolves to exactly one identity kind. The
kind controls whether `zfa make` generates a persistence surface (repository /
datasource / usecase / controller / presenter / view / route / state / provider /
observer / cache) and how the id is sourced.

### 1. Entity with a real id (the default)

An entity that declares a literal `id` field, or any field whose name ends in
`Id` (e.g. `depotId`), resolves with that field as its identity. The field's type
flows into the generated `UpdateParams`, `ToggleParams`, query, and repository
signatures. This is the clean path — `Authentication` (with `id: String`) is the
control case that already compiled clean. No annotation change is needed for
entities in this category; the resolver finds the id automatically.

```
@Zorphy(generateJson: true, generateCompareTo: true)
abstract class $Authentication {
  String get id;          // ← literal id → resolved as the identity
  String get userId;
  String get token;
}
```

### 2. Entity with an auto-generated uuid id (`autoId: true`)

Aggregate roots and event records that have no natural id field but still need
real client-side identity use `@Zorphy(autoId: true)`. The generator emits the
`id` constructor parameter as an optional `String?` that defaults to
`const Uuid().v4()` at construction time, and the `id` import
(`package:uuid/uuid.dart`) is always emitted. The resolver treats a uuid-backed
id as **the** id: no first-field fallback, and query / update / toggle
signatures use `String id` (never an enum-typed id). This is the fix for the
`ChatMessage` / `TelemetryEvent` shapes that produced 48 analyze errors in #307.

```
@Zorphy(generateJson: true, generateCompareTo: true, autoId: true)
abstract class $ChatMessage {
  String get id;                 // ← declared; builder defaults it to Uuid().v4()
  ChatMessageRole get role;
  String get content;
  DateTime get timestamp;
}
```

### 3. Value object (`@ZValueObject`)

Immutable composition types that have no identity of their own — they exist only
as fields inside entities. A value object generates **no** repository, usecase,
controller, presenter, view, route, state, provider, observer, or cache. It still
gets equality, `hashCode`, `toString`, `copyWith`, and JSON serialization exactly
like an entity (so it serializes cleanly when embedded). This is the third kind
the framework was missing: the 88 id-less entities in zik_zak are mostly value
objects that were forced into the entity kind and then broke the id resolver.

```
@ZValueObject
abstract class $ParserConfig {
  String get separator;
  bool get trimWhitespace;
}
```

`@ZValueObject` is a const alias for `@Zorphy(kind: ZorphyKind.valueObject)` —
use whichever reads better at the call site.

## The loud no-id error

If an entity (not a value object) has **no** id field, **no** `*Id` field, and
**no** `autoId: true`, `zfa make` now fails loudly instead of silently picking
the first field:

```
❌ Entity "ChatMessage" has no id field.

   A non-value-object entity needs an identity. One of:
     1. add a literal `String get id;` field,
     2. re-create with `zfa entity create -n ChatMessage --auto-id`,
     3. or model it as a value object: `zfa entity create -n ChatMessage --kind=value_object`.

   (The previous silent first-field fallback produced enum-typed ids and
    missing enum imports — issue #307.)
```

This is the forcing function that surfaces the 88 id-less entities during the
migration. It throws `MakeCommandException` (exit 1) so it is visible in CI and
`runCapturing` tests without killing the test isolate.

## How to classify a zik_zak entity

Apply this decision tree to each of the 88 id-less entities:

1. **Is it persisted/retrieved by its own identity?** Do you store it in a
   repository, query it by id, update it, or toggle a field on it? If yes → it
   is an **entity**. Go to step 2.
   - If no → it is a **value object**. Migrate with `--kind=value_object`.

2. **Does it have a natural id field** (a literal `id`, or a `*Id` like
   `userId`, `depotId`)? If yes → keep it as a **plain entity** (no annotation
   change; the resolver finds the id). You are done.

3. **It is an aggregate / event root with no natural id** (e.g. a chat message,
   a telemetry event, a log entry, a session) → give it an **auto-generated uuid
   id**. Migrate with `--auto-id`.

The heuristic: names ending in `_config`, `_options`, `_mapping`, `_result`,
`_params`, `_entry`, `_record` (when the record is embedded) lean value object;
names that read as standalone documents or events (`chat_message`,
`telemetry_event`, `session`, `log_entry`) lean autoId entity.

## Named-entity mapping (from the #320 spec)

The spec names 11 of the 88 entities. Their classification:

| Entity | Kind | Why |
|--------|------|-----|
| `ChatMessage` | entity + `autoId` | aggregate root (a chat message is a standalone document) |
| `TelemetryEvent` | entity + `autoId` | event root (events need client-side identity for dedup/ordering) |
| `value_mapping` | value object | pure lookup/config composition |
| `parser_config` | value object | configuration composition (separator, trim flags) |
| `string_between_parser_options` | value object | parser options bag |
| `barcode_lookup_result` | value object | a lookup result returned inside another entity |
| `store_price` | value object | a price snapshot embedded in a product |
| `regex_transformation_options` | value object | transformation options bag |
| `filter_value_mapping` | value object | filter config composition |
| `map_transformation_options` | value object | transformation options bag |

The remaining ~77 entities follow the same heuristic. Run `zfa make` on each
after re-modeling — the loud no-id error will catch any entity you
mis-classified as a plain entity (it will tell you to add an id, use `--auto-id`,
or switch to `--kind=value_object`).

## Migration recipe (per entity)

The migration is **not** part of this task — it is the follow-up. When you run
it, the recipe per entity is:

```bash
# 1. Re-model a value object (no id, no persistence surface):
zfa entity create -n ParserConfig --kind=value_object \
  --field separator:String --field trimWhitespace:bool

# 2. Re-model an autoId entity (aggregate/event root):
zfa entity create -n ChatMessage --auto-id \
  --field role:ChatMessageRole --field content:String --field timestamp:DateTime

# 3. Then rebuild + re-make:
zfa build
zfa make ChatMessage --preset=crud --with=vpc,state,di,test,mock
```

For entities that already have a real `id: String` (like `Authentication`), no
change is needed — they already compile clean.

### zik_zak pubspec note

zik_zak already depends on `uuid: ^4.6.0` (several entities hand-roll uuid ids
today: `text_spark`, `url_spark`, `zik`, `barcode_spark`). The framework now owns
this — once an entity is migrated to `autoId: true`, delete the hand-rolled
`import 'package:uuid/uuid.dart';` and the manual `id: Uuid().v4()` constructor
default from that entity; the generated `.zorphy.dart` file provides both.

## Verification (after migration)

- `dart analyze` on the zik_zak app: zero `Undefined class` errors for
  enum-typed ids (the #307 symptom).
- `zfa make <entity>` on every migrated entity: exit 0 (autoId entities and
  value objects) — never the loud no-id error (that only fires on un-migrated
  id-less entities).
- Value objects: no `domain/repositories/`, `domain/usecases/`,
  `presentation/controllers/`, or `presentation/presenter/` directories
  generated for them.
- autoId entities: generated `update` / `toggle` / `query` signatures use
  `String id` (not `ChatMessageRole` / `TelemetryEventType`).

## Related issues

- #307 — CLOSED (the id-fallback + enum-import bug; fixed by PR #322 + #324).
- #321 — the minimal #307 fix track (no first-field fallback + enum imports);
  its acceptance is met by PR #324.
- #320 — this framework spec (autoId + ValueObject + loud no-id error).
- #323 — `zfa make --revert` now deep-cleans orphan architecture after a VO
  re-model (so the migration is reversible if you mis-classify an entity).
