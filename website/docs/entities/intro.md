# Entity Generation

**Zuraffa** leverages the **Zorphy** engine to provide a robust, AI-friendly entity generation system. In Zuraffa, entities are the single source of truth for your business logic, designed to be immutable, type-safe, and seamlessly integrated with Clean Architecture layers.

---

## 🦄 Why Zorphy Entities?

*   **🤖 AI-Native Modeling**: Zuraffa's entity structures are highly predictable, allowing AI agents to generate entire features (UseCases, Repositories, VPCs) just by looking at your entity definition.
*   **🏗️ Clean Separation**: Your entity definitions stay in pure Dart (`domain/entities`), while complex logic like JSON serialization and immutability is handled by generated "augmentation" files.
*   **🛡️ Strict Immutability**: All entities use `final` fields and provide `copyWith` and `patch` methods for safe state transitions.
*   **🧩 Nested Awareness**: Zuraffa automatically handles imports and serialization for nested entity relationships (e.g., an `Order` containing a `List<Product>`).
*   **⚡ Zero Boilerplate**: Define your fields once via the CLI, and Zuraffa generates the rest.

---

## 🚀 Quick Start

### 1. Create an Entity
Use the `zfa entity create` command to define your model and its fields:

```bash
zfa entity create -n Product \
  --field name:String \
  --field price:double \
  --field stock:int \
  --field description:String?
```

### 2. Finalize with Build
Run the Zuraffa build command to generate the implementation files:

```bash
zfa build
```

---

## 📂 The Entity Stack

When you create a `Product` entity, Zuraffa generates a dedicated folder:

```text
lib/src/domain/entities/product/
├── product.dart           # Your definition (Editable)
├── product.zorphy.dart    # Immutable implementation (Generated)
└── product.g.dart         # JSON Serialization (Generated)
```

### Your Definition File
The `product.dart` file contains the "blueprint" of your entity using an abstract class prefixed with `$`:

```dart
@Zorphy(generateJson: true)
abstract class $Product {
  String get name;
  double get price;
  int get stock;
  String? get description;
}
```

---

## 🏗️ Beyond Simple Models

Zuraffa's entity system is powerful enough to handle complex domain requirements:

### Enums for Fixed States
Always define your enums first so they can be referenced by entities:
```bash
zfa entity enum -n OrderStatus --value pending,shipped,delivered
```

### Nested Relationships
Reference other entities using the `$` prefix in your field definitions:
```bash
zfa entity create -n Order --field status:OrderStatus --field items:List<$Product>
```

### Sealed Classes (Polymorphism)
Model complex hierarchies like payment methods or notification types:
```bash
zfa entity create -n PaymentMethod --sealed
```

---

## 🤖 The AI Workflow

Because Zuraffa entities are the foundation of your feature, you can use them to drive high-level AI generation. Once your entity is defined, you can ask an AI agent:

> "I've defined the **Product** entity. Now use **zfa feature** to generate the full CRUD stack with caching and mock data."

The AI will execute:
```bash
zfa feature Product --methods=get,getList,create,update,delete --data --cache --mock --di --vpcs
```

---

## 📂 Next Steps

*   [**Field Types Reference**](./field-types) - Complete guide to supported types and nullability.
*   [**Advanced Patterns**](./advanced-patterns) - Sealed classes, inheritance, and generics.
*   [**Feature Commands**](../cli/commands) - Learn how to generate architecture around your entities.
