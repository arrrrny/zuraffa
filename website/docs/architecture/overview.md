# Architecture Overview

**Zuraffa** enforces a strict separation of concerns through a feature-first, Clean Architecture layout. This structure ensures your business logic remains pure, your data sources stay interchangeable, and your UI remains a reflection of immutable state.

---

## 🏗️ The Zuraffa Stack

Zuraffa organizes code into three primary layers, orchestrated by automated Dependency Injection.

### 1. Domain Layer (Pure Dart)
The "Brain" of your application. No dependencies on Flutter or external packages.
- **Entities**: Immutable, type-safe data models (powered by **Zorphy**).
- **Repositories (Interfaces)**: Contracts defining how data should be fetched or manipulated.
- **UseCases**: Single-responsibility units of business logic (e.g., `GetProductListUseCase`).

### 2. Data Layer
The "Muscle" of your application. Handles all side effects and external communication.
- **DataSources**: Remote (REST/GraphQL) and Local (Hive/SQLite) implementations.
- **Repositories (Implementations)**: Orchestrates DataSources to fulfill Domain contracts.

### 3. Presentation Layer (VPC Pattern)
Zuraffa uses the **VPC (View-Presenter-Controller)** pattern for a clean, reactive UI:
- **View**: Pure Flutter UI (Stateless or Stateful).
- **Presenter**: Prepares data from UseCases for the View.
- **Controller**: Handles user interactions and manages the feature's lifecycle.
- **State**: A single, immutable source of truth for the View.

---

## 📂 Feature-First Structure

When you generate a feature for `Product`, Zuraffa creates a consistent slice:

```text
lib/src/
├── domain/
│   ├── entities/product/           # Product entity
│   ├── repositories/               # ProductRepository interface
│   └── usecases/product/           # CRUD UseCases (Get, Create, etc.)
├── data/
│   ├── datasources/product/        # Remote & Local DataSources
│   └── repositories/               # DataProductRepository implementation
└── presentation/
    └── views/product/              # View, Presenter, Controller, State
```

---

## 🛡️ The Result Pattern

One of Zuraffa's core strengths is its type-safe error handling. Instead of using `try-catch` blocks, all operations return a `Result<T, AppFailure>`:

```dart
final result = await getProductUseCase(id);

result.fold(
  (product) => print('Success: ${product.name}'),
  (failure) => print('Error: ${failure.message}'),
);
```

This pattern ensures that every potential failure is handled explicitly at compile-time, leading to more robust and predictable applications.

---

## 🚀 Why This Works

1.  **AI-Native Alignment**: The consistent structure allows AI agents to navigate and modify your project with high confidence.
2.  **Testability**: Every layer is decoupled, making unit and integration testing straightforward.
3.  **Scalability**: New features are added as independent slices, preventing the codebase from becoming a "monolith of spaghetti."

---

Next: [**UseCase Types**](./usecases)
