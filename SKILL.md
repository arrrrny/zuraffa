# Zuraffa CLI (zfa) Skill

**Description:** Use this skill when working with  Flutter projects and needing to generate Clean Architecture boilerplate code. This skill applies whenever code generation is needed for entities, repositories, use cases, data sources, presentation layers (View/Presenter/Controller), dependency injection, tests, or mock data using the Zuraffa framework.

**Triggers:** 
- Requests to generate CRUD code, entities, repositories, use cases, data sources, or presentation layers in a Zuraffa Flutter project
- Commands or requests containing "zfa", "Zuraffa CLI", or "generate" in the context of a Zuraffa project
- Tasks involving Clean Architecture code generation for Flutter/Dart projects using Zuraffa
- Needs to create new features, add methods to existing entities, or scaffold presentation layers
- Requests to generate dependency injection setup, mock data, unit tests, or caching infrastructure

**When NOT to use:**
- General Flutter development without Zuraffa framework
- Pure Dart projects not using Clean Architecture
- Manual code implementation when CLI is unavailable or inappropriate

---

## Quick Start

### Basic CRUD Generation
```bash
# Generate full CRUD stack for an entity
dart run zuraffa:zfa generate Product --methods=get,getList,create,update,delete
```

### Complete Feature with All Layers
```bash
# Generate entity, data layer, presentation layer, caching, DI, and tests
dart run zuraffa:zfa generate Product --methods=get,getList,create,update,delete,watchList --data --vpc --state --cache --di --test
```

### Using JSON Configuration
```bash
# Generate from JSON file
dart run zuraffa:zfa generate Product -j product.json
```

---

## Core Concepts

### Entity Location Convention
Entities MUST be placed at:
```
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example for `Product`:
```
lib/src/domain/entities/product/product.dart
```

### Layer Structure
```
lib/src/
├── domain/                    # Pure Dart business logic
│   ├── entities/              # Business objects
│   ├── repositories/          # Repository interfaces (contracts)
│   └── usecases/              # Business operations
├── data/                      # External dependencies
│   ├── data_sources/          # Data source implementations
│   └── repositories/          # Repository implementations
└── presentation/              # UI layer
    └── pages/{feature}/
        ├── {feature}_view.dart
        ├── {feature}_presenter.dart
        └── {feature}_controller.dart
```

---

## Available Methods

| Method | UseCase Type | Description |
|--------|--------------|-------------|
| `get` | `UseCase` | Get single entity by ID |
| `getList` | `UseCase` | Get all entities |
| `create` | `UseCase` | Create new entity |
| `update` | `UseCase` | Update existing entity |
| `delete` | `CompletableUseCase` | Delete entity by ID |
| `watch` | `StreamUseCase` | Watch single entity changes |
| `watchList` | `StreamUseCase` | Watch all entities changes |

---

## Command Flags Reference

### Entity-Based Generation

| Flag | Short | Description |
|------|-------|-------------|
| `--methods=<list>` | `-m` | Comma-separated methods to generate |
| `--data` | `-d` | Generate data repository + data source |
| `--datasource` | | Generate data source only |
| `--id-field=<name>` | | ID field name (default: `id`) |
| `--id-field-type=<type>` | | ID field type (default: `String`) |
| `--query-field=<name>` | | Query field name for `get`/`watch` (default: `id`) |
| `--query-field-type=<type>` | | Query field type (default: matches id-type) |
| `--morphy` | | Use Morphy-style typed patches |

### VPC Layer Generation

| Flag | Description |
|------|-------------|
| `--vpc` | Generate View + Presenter + Controller |
| `--vpcs` | Generate View, Presenter, Controller, and State |
| `--pc` | Generate Presenter + Controller only (preserve View) |
| `--pcs` | Generate Presenter, Controller, and State (preserve View) |
| `--state` | Generate State object with granular loading states |

### Caching

| Flag | Description |
|------|-------------|
| `--cache` | Enable caching with dual datasources (remote + local) |
| `--cache-policy` | Cache expiration: daily, restart, ttl (default: daily) |
| `--cache-storage` | Local storage hint: hive, sqlite, shared_preferences (default: hive) |
| `--ttl` | TTL duration in minutes (default: 1440 = 24 hours) |

### Mock Data

| Flag | Description |
|------|-------------|
| `--mock` | Generate mock data files alongside other layers |
| `--mock-data-only` | Generate only mock data files |

### Dependency Injection

| Flag | Description |
|------|-------------|
| `--di` | Generate dependency injection files (get_it) |
| `--use-mock` | Use mock datasource in DI |

### Additional Features

| Flag | Description |
|------|-------------|
| `--init` | Add initialize method & isInitialized stream to repos |
| `--test` | Generate unit tests for each UseCase |
| `--subfolder` | Organize under a subfolder |
| `--force` | Overwrite existing files |
| `--dry-run` | Preview without writing files |
| `--format=<type>` | Output format: `json` or `text` |

---

## Use Case Types

| Type | Description | Use When |
|------|-------------|----------|
| `usecase` | Single request-response operations | CRUD, API calls |
| `stream` | Real-time data streams | WebSocket, Firebase listeners |
| `background` | CPU-intensive work | Image processing, crypto on isolates |
| `completable` | No return value | Delete, logout, clear cache |

---

## Common Workflows

### Workflow 1: Adding a New Entity

1. **Create Entity File** (manual or preferred generator):
   ```
   lib/src/domain/entities/product/product.dart
   ```

2. **Generate Domain + Data Layer:**
   ```bash
   zfa generate Product --methods=get,getList,create,update,delete --data
   ```

3. **Generate Presentation Layer:**
   ```bash
   zfa generate Product --methods=get,getList,create --vpc --state --force
   ```

4. **Implement DataSource** (create concrete implementation in data layer)

5. **Register with DI**

6. **Customize View UI**

### Workflow 2: Complete Feature Generation

```bash
# All-in-one command for a complete feature
zfa generate Product \
  --methods=get,getList,create,update,delete,watchList \
  --data \
  --vpc \
  --state \
  --cache \
  --di \
  --test
```

### Workflow 3: Adding Methods to Existing Entity

```bash
# Add watch methods to existing entity
zfa generate Product --methods=watch,watchList --force
```

### Workflow 4: Custom UseCase Generation

```bash
# Create custom use case without entity
zfa generate ProcessOrder \
  --domain=checkout \
  --repo=OrderRepository \
  --params=OrderRequest \
  --returns=OrderResult
```

---

## Cache Policies

| Policy | Description | Use Case |
|--------|-------------|----------|
| `DailyCachePolicy` | Cache expires after 24 hours | Data that updates daily |
| `AppRestartCachePolicy` | Cache valid only during app session | Config data, user preferences |
| `TtlCachePolicy` | Custom expiration duration | Fine-grained cache control |

---

## File Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Entity | `{entity_snake}.dart` | `product.dart` |
| Repository | `{entity_snake}_repository.dart` | `product_repository.dart` |
| UseCase | `{action}_{entity_snake}_usecase.dart` | `get_product_usecase.dart` |
| DataSource | `{entity_snake}_data_source.dart` | `product_data_source.dart` |
| View | `{entity_snake}_view.dart` | `product_view.dart` |
| Presenter | `{entity_snake}_presenter.dart` | `product_presenter.dart` |
| Controller | `{entity_snake}_controller.dart` | `product_controller.dart` |
| State | `{entity_snake}_state.dart` | `product_state.dart` |

---

## JSON Configuration Example

### Entity-Based Configuration
```json
{
  "name": "Product",
  "methods": ["get", "getList", "create", "update", "delete", "watchList"],
  "repository": true,
  "vpc": true,
  "data": true,
  "id_type": "String",
  "cache": true,
  "cache_policy": "daily",
  "di": true,
  "test": true
}
```

## Troubleshooting

### Entity Not Found Errors
Ensure entity exists at expected path:
```
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

### Overwriting Files
Use `--force` flag to overwrite existing files:
```bash
zfa generate Product --methods=get,getList --force
```

### Dry Run Preview
```bash
zfa generate Product --methods=get --dry-run --format=json
```

---