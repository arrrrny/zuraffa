# Field Types Reference

Zuraffa's entity generation supports all standard Dart types, nested entities, and complex collections. Every field you define is automatically handled for **immutability**, **JSON serialization**, and **Clean Architecture** integration.

---

## 🦄 Basic Types

| Type | Description | CLI Example |
| :--- | :--- | :--- |
| `String` | Textual data. | `--field name:String` |
| `int` | Integer numbers. | `--field age:int` |
| `double` | Decimal numbers. | `--field price:double` |
| `bool` | True/False values. | `--field isActive:bool` |
| `DateTime` | Dates and timestamps. | `--field createdAt:DateTime` |

---

## 🛡️ Nullable Types

Any type can be made nullable by adding a `?` suffix. Zuraffa will generate appropriate `copyWith` and `patch` logic to handle `null` values safely.

```bash
zfa entity create -n Profile \
  --field nickname:String \
  --field bio:String? \
  --field age:int?
```

---

## 🧩 Collection Types

Zuraffa supports standard Dart collections. These are automatically serialized to and from JSON arrays and maps.

### Lists
```bash
# List of primitives
--field tags:List<String>

# List of nested entities
--field items:List<$OrderItem>
```

### Maps
```bash
# JSON-like metadata
--field metadata:Map<String,dynamic>

# Typed configuration
--field settings:Map<String,bool>
```

---

## 🏗️ Nested Entities

One of Zuraffa's strongest features is its awareness of entity relationships. Reference other entities using the `$` prefix.

```bash
# 1. Create the child entity
zfa entity create -n Address --field street:String --field city:String

# 2. Reference it in the parent
zfa entity create -n User --field name:String --field address:$Address
```

**Why the `$`?** It tells Zuraffa to look for a Zorphy entity named `Address`. The generator will automatically add the necessary imports and handle recursive JSON serialization.

---

## 🔢 Enums

Enums are the best way to handle fixed states like `OrderStatus` or `UserRole`.

```bash
# 1. Create the enum
zfa entity enum -n Status --value active,inactive,pending

# 2. Use it in an entity
zfa entity create -n Account --field status:Status
```

---

## 🧠 Advanced Types

### Generics
Create reusable data structures:
```bash
zfa entity create -n ApiResponse --field data:T? --field success:bool
```

### Self-Referencing (Trees)
Perfect for categories or organizational charts:
```bash
zfa entity create -n Category --field name:String --field children:List<$Category>?
```

---

## 🤖 Type Conversions (JSON)

Zuraffa handles the "boring" parts of data conversion automatically:

*   **DateTime**: Serialized to ISO 8601 strings (`2026-03-13T...`).
*   **Enums**: Serialized to their string names (e.g., `"active"`).
*   **Nested Entities**: Recursively calls `toJson()` and `fromJson()`.
*   **Complex Collections**: Deeply traverses lists and maps for serialization.

---

## 📂 Next Steps

*   [**Advanced Patterns**](./advanced-patterns) - Sealed classes and inheritance.
*   [**Feature Commands**](../cli/commands) - Generate architecture around these types.
*   [**Result Type**](../architecture/result-type) - How failures are handled across these types.
