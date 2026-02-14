# Entity Commands Reference

Reference for Zorphy entity generation in Zuraffa v3. Use these commands to create type-safe entities, enums, and JSON-ready models.

## Commands Overview

| Command | Description |
|---------|-------------|
| [`zfa entity create`](#entity-create) | Create a new Zorphy entity with fields |
| [`zfa entity new`](#entity-new) | Quick-create a simple entity |
| [`zfa entity enum`](#entity-enum) | Create a new enum |
| [`zfa entity add-field`](#entity-add-field) | Add field(s) to an existing entity |
| [`zfa entity from-json`](#entity-from-json) | Create entity/ies from JSON file |
| [`zfa entity list`](#entity-list) | List all Zorphy entities |
| [`zfa build`](#build) | Run build_runner for code generation |

---

## entity create

Create a new Zorphy entity with fields, supporting JSON serialization, sealed classes, inheritance, and all Zorphy features.

```bash
zfa entity create [options]
```

### Required Arguments

| Argument | Description |
|----------|-------------|
| `-n, --name=<name>` | Entity name in PascalCase (e.g., `User`, `Product`) |

### Field Definition

| Argument | Description |
|----------|-------------|
| `--field=<definition>` | Add a field in format `"name:type"` or `"name:type?"` for nullable |
| `-f, --fields` | Enable interactive field prompts (default: `true`) |

**Field Type Examples:**
- Basic: `name:String`, `age:int`, `price:double`, `isActive:bool`
- Nullable: `email:String?`, `phone:String?`
- Generic: `items:List<String>`, `data:Map<String,dynamic>`
- Nested: `address:$Address`, `user:$User`
- Enum: `status:UserStatus` (enum must exist)

### Output Options

| Argument | Default | Description |
|----------|---------|-------------|
| `-o, --output=<dir>` | `lib/src/domain/entities` | Output base directory |

### Generation Options

| Argument | Default | Description |
|----------|---------|-------------|
| `--json=<bool>` | `true` | Enable JSON serialization |
| `--sealed` | `false` | Create sealed abstract class (`$$` prefix) |
| `--non-sealed` | `false` | Create non-sealed abstract class |
| `--copywith-fn` | `false` | Enable function-based copyWith |
| `--compare=<bool>` | `true` | Enable compareTo generation |

### Inheritance Options

| Argument | Description |
|----------|-------------|
| `--extends=<interface>` | Interface to extend (e.g., `$Timestamped`) |
| `--subtype=<name>` | Explicit subtypes for polymorphism (can be used multiple times) |

### Examples

**Simple entity:**
```bash
zfa entity create -n User
```

**With fields:**
```bash
zfa entity create -n User \
  --field name:String \
  --field email:String? \
  --field age:int
```

**Sealed class for polymorphism:**
```bash
zfa entity create -n PaymentMethod --sealed
```

**With inheritance:**
```bash
zfa entity create -n Post \
  --field title:String \
  --field content:String \
  --extends=$Timestamped \
  --extends=$Identified
```

**With explicit subtypes:**
```bash
zfa entity create -n Notification \
  --sealed \
  --subtype=$EmailNotification \
  --subtype=$PushNotification \
  --subtype=$SmsNotification
```

---

## entity new

Quick-create a simple entity with basic defaults. Good for prototyping.

```bash
zfa entity new [options]
```

### Required Arguments

| Argument | Description |
|----------|-------------|
| `-n, --name=<name>` | Entity name in PascalCase |

### Options

| Argument | Default | Description |
|----------|---------|-------------|
| `-o, --output=<dir>` | `lib/src/domain/entities` | Output directory |
| `--json=<bool>` | `true` | Enable JSON serialization |

### Example

```bash
zfa entity new -n Product
```

---

## entity enum

Create a new enum in the entities/enums directory with automatic barrel export.

```bash
zfa entity enum [options]
```

### Required Arguments

| Argument | Description |
|----------|-------------|
| `-n, --name=<name>` | Enum name in PascalCase (e.g., `Status`, `UserRole`) |
| `--value=<values>` | Comma-separated enum values (e.g., `active,inactive,pending`) |

### Options

| Argument | Default | Description |
|----------|---------|-------------|
| `-o, --output=<dir>` | `lib/src/domain/entities` | Output base directory |

### Examples

```bash
zfa entity enum -n Status --value active,inactive,pending
zfa entity enum -n UserRole --value admin,user,guest
zfa entity enum -n OrderStatus --value pending,processing,shipped,delivered,cancelled
```

---

## entity add-field

Add field(s) to an existing Zorphy entity. Automatically updates imports if needed.

```bash
zfa entity add-field [options]
```

### Required Arguments

| Argument | Description |
|----------|-------------|
| `-n, --name=<name>` | Entity name (e.g., `User`) |
| `--field=<definition>` | Field to add in format `"name:type"` or `"name:type?"` (can be used multiple times) |

### Options

| Argument | Default | Description |
|----------|---------|-------------|
| `-o, --output=<dir>` | `lib/src/domain/entities` | Output base directory |

### Examples

```bash
zfa entity add-field -n User --field phone:String?
zfa entity add-field -n User --field phone:String? --field address:$Address
```

---

## entity from-json

Create Zorphy entity/ies from a JSON file. Automatically infers types and creates nested entities.

```bash
zfa entity from-json <file.json> [options]
```

### Required Arguments

| Argument | Description |
|----------|-------------|
| `<file.json>` | Path to JSON file |

### Options

| Argument | Default | Description |
|----------|---------|-------------|
| `--name=<name>` | Inferred from filename | Entity name |
| `-o, --output=<dir>` | `lib/src/domain/entities` | Output base directory |
| `--json=<bool>` | `true` | Enable JSON serialization |
| `--prefix-nested=<bool>` | `true` | Prefix nested entities with parent name |

### Example

```bash
zfa entity from-json user.json
zfa entity from-json data.json --name UserProfile
zfa entity from-json config.json --prefix-nested=false
```

---

## entity list

List all Zorphy entities and enums in the project with their properties.

```bash
zfa entity list [options]
```

### Options

| Argument | Default | Description |
|----------|---------|-------------|
| `-o, --output=<dir>` | `lib/src/domain/entities` | Directory to search |

### Example

```bash
zfa entity list
zfa entity list --output=lib/src/domain/entities
```

---

## build

Run build_runner for code generation (applies to both Zuraffa and Zorphy generated code).

```bash
zfa build [options]
```

### Options

| Argument | Short | Description |
|----------|-------|-------------|
| `-w, --watch` | | Watch for changes |
| `-c, --clean` | | Clean before build |

### Examples

```bash
zfa build
zfa build --watch
zfa build --clean
```

---

## Field Types Reference

Complete reference for field type definitions.

### Basic Types

| Type | Description | Example |
|------|-------------|---------|
| `String` | Text | `name:String` |
| `int` | Integer | `age:int` |
| `double` | Decimal number | `price:double` |
| `bool` | Boolean | `isActive:bool` |
| `DateTime` | Date/time | `createdAt:DateTime` |

### Nullable Types

Add `?` to make any field nullable:
```bash
--field email:String?
--field phone:String?
```

### Collection Types

| Type | Description | Example |
|------|-------------|---------|
| `List<T>` | Ordered list | `tags:List<String>` |
| `Set<T>` | Unique values | `permissions:Set<String>` |
| `Map<K,V>` | Key-value pairs | `metadata:Map<String,dynamic>` |

### Nested Entities

Reference other Zorphy entities with `$` prefix:
```bash
--field address:\$Address
--field user:\$User
--field order:\$Order
```

### Enums

First create the enum, then use it:
```bash
zfa entity enum -n Status --value active,inactive
zfa entity create -n Account --field status:Status
zfa entity enum -n OrderStatus --value pending,processing,delivered
zfa entity create -n Order --field status:OrderStatus --field customer:\$Customer
```

### Generic Types

```bash
zfa entity create -n ApiResponse --field data:T?
zfa entity create -n KeyValuePair --field key:K --field value:V
```

### Self-Referencing Types

```bash
zfa entity create -n CategoryNode \
  --field children:List<$CategoryNode>? \
  --field parent:$CategoryNode?
```

---

## Tips

### Use Interactive Mode
```bash
zfa entity create -n User --fields
```

### Create Entities First
```bash
# ✅ Good
zfa entity create -n Address --field street:String
zfa entity create -n User --field address:$Address

# ❌ Bad - Address doesn't exist yet
zfa entity create -n User --field address:$Address
```

### Build After Changes
```bash
zfa entity create -n Product --field name:String
zfa entity enum -n Status --value active,inactive
zfa entity add-field -n Product --field status:Status
zfa build
```

---

## Next Steps

- [Entity Generation](../entities/intro) - Complete entity generation guide
- [Field Types Reference](../entities/field-types) - All supported field types
- [Advanced Patterns](../entities/advanced-patterns) - Sealed classes, inheritance, generics
- [Real-World Examples](../entities/examples) - Production-ready examples
