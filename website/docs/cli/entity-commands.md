# Entity Commands Reference

Zuraffa uses **Zorphy** to generate immutable, type-safe, and AI-friendly entities. The `zfa entity` command suite is your primary tool for managing your domain models.

---

## 🦄 Commands Overview

| Command | Description |
| :--- | :--- |
| [`zfa entity create`](#create) | Create a new Zorphy entity with fields. |
| [`zfa entity add-field`](#add-field) | Add new fields to an existing entity. |
| [`zfa entity enum`](#enum) | Create a new type-safe enum. |
| [`zfa entity from-json`](#from-json) | Infer and create entities from a JSON snippet. |
| [`zfa build`](#build) | Run the code generator to finalize entities. |

---

## 🚀 create

Create a new Zorphy entity. This generates a Dart file with an abstract class prefixed with `$` which Zorphy uses to generate the final immutable class.

```bash
zfa entity create -n <Name> [options]
```

### Field Definitions
Use the `--field` flag to define your model. Format: `name:type`.

*   **Basic**: `name:String`, `age:int`, `price:double`, `isActive:bool`.
*   **Nullable**: `email:String?`, `description:String?`.
*   **Collections**: `tags:List<String>`, `metadata:Map<String,dynamic>`.
*   **Nested**: `address:$Address`, `user:$User` (Note the `$` prefix for other entities).

### Examples

**Standard Entity:**
```bash
zfa entity create -n Product \
  --field name:String \
  --field price:double \
  --field category:String?
```

**Sealed Class (Polymorphism):**
```bash
zfa entity create -n PaymentMethod --sealed
```

---

## 🛠️ add-field

Safely add new fields to an existing entity without manual editing.

```bash
zfa entity add-field -n Product --field stock:int --field sku:String
```

---

## 🔢 enum

Create an enum in the `domain/entities/enums` directory.

```bash
zfa entity enum -n OrderStatus --value pending,processing,shipped,delivered
```

---

## 🤖 from-json

The fastest way to model an API response. Zuraffa will infer types and even create nested entities automatically.

```bash
zfa entity from-json product_api_response.json --name Product
```

---

## 🏗️ build

Zuraffa uses `build_runner` under the hood to generate the final immutable code, JSON serialization, and `copyWith` methods.

```bash
zfa build
```

**Options:**
*   `--watch`: Automatically rebuild when you save a file.
*   `--clean`: Clear the build cache before starting.

---

## 📂 Next Steps

*   [**Feature Commands**](./commands) - Generate UseCases and UI for your entities.
*   [**Architecture Overview**](../architecture/overview) - How entities fit into the Domain layer.
*   [**MCP Server**](../features/mcp-server) - How to manage entities using AI.
