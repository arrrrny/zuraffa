# Params System Design

## Overview

The params system provides type-safe wrappers for different CRUD operations. The design balances type safety with practical usability.

## Design Decisions

### QueryParams - Uses Filter<T> ✅

**Purpose:** Find entities based on criteria

```dart
QueryParams<Product>(filter: Eq(ProductFields.id, '123'))
```

**Why Filter?**
- Queries are about **finding** entities
- May need complex conditions (And, Or, Gt, Lt, etc.)
- Type-safe field references when using Zorphy
- Flexible - can query by any field, not just ID

**Used by:** `get`, `watch` methods

---

### UpdateParams - Uses `id` + `data` ✅

**Purpose:** Update a specific entity

```dart
UpdateParams<Product, ProductPatch>(
  id: '123',
  data: ProductPatch(name: 'New Name'),
)
```

**Why NOT Filter?**
- Updates target a **specific entity** by ID
- No ambiguity - exactly one entity
- Simpler API for common case
- Matches REST conventions (PUT /products/:id)

**Signature:**
```dart
class UpdateParams<T, P> {
  final dynamic id;      // The entity ID
  final P data;          // Patch data (Zorphy Patch or Map)
  final Params? params;  // Optional extra params
}
```

**Used by:** `update` method

---

### DeleteParams - Uses `id` ✅

**Purpose:** Delete a specific entity

```dart
DeleteParams<Product>(id: '123')
```

**Why NOT Filter?**
- Deletes target a **specific entity** by ID
- Safety - no accidental bulk deletes
- Simpler API
- Matches REST conventions (DELETE /products/:id)

**Signature:**
```dart
class DeleteParams<T> {
  final dynamic id;      // The entity ID
  final Params? params;  // Optional extra params (e.g., soft delete flag)
}
```

**Used by:** `delete` method

---

### ListQueryParams - Uses Filter<T> + Sort<T> ✅

**Purpose:** Query lists with filtering, sorting, pagination

```dart
ListQueryParams<Product>(
  filter: And([
    Eq(ProductFields.category, 'electronics'),
    Gt(ProductFields.price, 100),
  ]),
  sort: Sort.desc(ProductFields.createdAt),
  limit: 20,
  offset: 0,
)
```

**Why Filter + Sort?**
- List queries need complex filtering
- Type-safe sorting by any field
- Pagination support
- Search support

**Used by:** `getList`, `watchList` methods

---

## Respecting --id-field and --query-field

The generator respects these flags throughout the generated code:

```bash
zfa generate Todo --methods=get,update,delete --id-field=title --id-field-type=String
```

**Generated code uses the specified ID field:**

```dart
// Mock DataSource
final existing = TodoMockData.todos.firstWhere(
  (item) => item.title == params.id,  // ✅ Uses title field
  orElse: () => throw NotFoundFailure('Todo not found'),
);

// Local DataSource (Hive)
final existing = _box.values.firstWhere(
  (item) => item.title == params.id,  // ✅ Uses title field
  orElse: () => throw NotFoundFailure('Todo not found in cache'),
);
await _box.put(existing.title, updated);  // ✅ Uses title as box key
```

**With default id field:**

```bash
zfa generate Product --methods=update,delete
```

```dart
// Uses default 'id' field
final existing = _box.values.firstWhere(
  (item) => item.id == params.id,  // ✅ Uses id field
  orElse: () => throw NotFoundFailure('Product not found in cache'),
);
```

The `--query-field` is used for QueryParams when you want to query by a different field:

```bash
zfa generate Product --methods=get --query-field=sku --query-field-type=String
```

---

## Summary

| Params Type | Uses | Why |
|-------------|------|-----|
| `QueryParams<T>` | `Filter<T>?` | Finding entities with flexible criteria |
| `UpdateParams<T, P>` | `id` + `data` | Updating a specific entity |
| `DeleteParams<T>` | `id` | Deleting a specific entity |
| `ListQueryParams<T>` | `Filter<T>?` + `Sort<T>?` | Querying lists with filtering/sorting |

**Key Principle:** Use Filter for queries (finding), use ID for mutations (updating/deleting specific entities).
