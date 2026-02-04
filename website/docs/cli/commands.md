# CLI Commands Reference

The `zfa` CLI provides powerful code generation capabilities for Zuraffa's Clean Architecture. This reference covers all commands, flags, and options for ZFA.

## Commands Overview

| Command | Description |
|---------|-------------|
| [`zfa generate`](#generate) | Generate Clean Architecture code |
| [`zfa config`](#config) | Manage ZFA configuration |
| [`zfa schema`](#schema) | Output JSON schema for validation |
| [`zfa validate`](#validate) | Validate JSON configuration |
| [`zfa initialize`](#initialize) | Create a sample entity |

---

## config

Manage ZFA configuration for your project. Configuration is stored in `.zfa.json` in your project root.

```bash
zfa config <command> [options]
```

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `init` | Create default configuration file |
| `show` / `get` | Display current configuration |
| `set <key> <value>` | Update a configuration value |
| `help` | Show help message |

### init

Create a `.zfa.json` configuration file with default values:

```bash
zfa config init [directory]
```

Creates a configuration file with the following defaults:

```json
{
  "useZorphyByDefault": true,
  "jsonByDefault": true,
  "compareByDefault": true,
  "defaultEntityOutput": "lib/src/domain/entities"
}
```

### show / get

Display the current configuration:

```bash
zfa config show
```

Example output:

```
📋 ZFA Configuration (/path/to/project/.zfa.json):

Settings:
  • useZorphyByDefault: true
  • jsonByDefault: true
  • compareByDefault: true
  • defaultEntityOutput: lib/src/domain/entities
```

### set

Update a specific configuration value:

```bash
zfa config set <key> <value>
```

#### Configuration Keys

| Key | Type | Description |
|-----|------|-------------|
| `useZorphyByDefault` | boolean | Use Zorphy for entity generation by default |
| `jsonByDefault` | boolean | Enable JSON serialization by default |
| `compareByDefault` | boolean | Enable `compareTo` by default |
| `defaultEntityOutput` | string | Default output directory for entities |

#### Examples

```bash
# Disable Zorphy by default
zfa config set useZorphyByDefault false

# Set custom output directory
zfa config set defaultEntityOutput lib/src/models

# Enable JSON serialization by default
zfa config set jsonByDefault true
```

### Configuration File

The `.zfa.json` file is created in your project root and can be:

- Created with `zfa config init`
- Viewed with `zfa config show`
- Updated with `zfa config set`
- Edited manually in any text editor

#### Example Configuration

```json
{
  "useZorphyByDefault": true,
  "jsonByDefault": true,
  "compareByDefault": true,
  "defaultEntityOutput": "lib/src/domain/entities",
  "notes": [
    "Set useZorphyByDefault to false for manual entity generation",
    "Adjust defaultEntityOutput to change where entities are created"
  ]
}
```

### How Configuration Affects Generation

When you run `zfa generate` or entity commands:

1. **Zorphy Integration**: If `useZorphyByDefault` is `true`, generated code uses Zorphy-style typed patches instead of `Partial<T>`
2. **Entity Output**: Entity commands use `defaultEntityOutput` as the base directory
3. **JSON Serialization**: Entity generation includes JSON serialization when `jsonByDefault` is `true`
4. **Comparison**: Entities get `compareTo` methods when `compareByDefault` is `true`

You can always override these defaults with command-line flags:

```bash
# Even with useZorphyByDefault: false, you can enable it per-command
zfa generate Product --methods=get --zorphy
```

---

## generate

The primary command for generating Clean Architecture boilerplate code.

```bash
zfa generate <Name> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<Name>` | Entity or UseCase name in PascalCase (e.g., `Product`, `ProcessOrder`) |

### Entity-Based Generation Flags

Generate CRUD operations for an entity.

| Flag | Short | Description |
|------|-------|-------------|
| `--methods=<list>` | `-m` | Comma-separated methods to generate |
| `--data` | `-d` | Generate data repository + data source |
| `--datasource` | | Generate data source only |

#### Available Methods

| Method | Generated UseCase | Description |
|--------|-------------------|-------------|
| `get` | `Get{Name}UseCase` | Get single entity by ID |
| `getList` | `Get{Name}ListUseCase` | Get all entities |
| `create` | `Create{Name}UseCase` | Create new entity |
| `update` | `Update{Name}UseCase` | Update existing entity |
| `delete` | `Delete{Name}UseCase` | Delete entity by ID |
| `watch` | `Watch{Name}UseCase` | Watch single entity changes |
| `watchList` | `Watch{Name}ListUseCase` | Watch all entities changes |

#### Entity Customization

| Flag | Default | Description |
|------|---------|-------------|
| `--id-field=<name>` | `id` | ID field name for operations |
| `--id-field-type=<type>` | `String` | ID field type |
| `--query-field=<name>` | `id` | Query field name for get/watch |
| `--query-field-type=<type>` | (same as id) | Query field type |
| `--zorphy` | false | Use Zorphy-style typed patches for updates |
| `--morphy` | false | Alias for --zorphy (backward compatibility) |
| `--init` | false | Generate initialize method for repository/datasource |

### VPC Layer Flags

Generate presentation layer components.

| Flag | Description |
|------|-------------|
| `--vpc` | Generate View + Presenter + Controller |
| `--vpcs` | Generate View + Presenter + Controller + State |
| `--pc` | Generate Presenter + Controller only (preserve custom View) |
| `--pcs` | Generate Presenter + Controller + State (preserve custom View) |
| `--view` | Generate View only |
| `--presenter` | Generate Presenter only |
| `--controller` | Generate Controller only |
| `--state` | Generate State object with granular loading states |
| `--observer` | Generate Observer class |

### Data Layer Flags

| Flag | Description |
|------|-------------|
| `--data` | Generate DataRepository + DataSource |
| `--datasource` | Generate DataSource only |
| `--cache` | Enable caching with dual datasources (remote + local) |
| `--cache-policy=<policy>` | Cache policy: `daily`, `restart`, `ttl` |
| `--cache-storage=<storage>` | Local storage: `hive`, `sqlite`, `shared_preferences` |
| `--ttl=<minutes>` | TTL duration in minutes (default: 1440 = 24 hours) |
| `--mock` | Generate mock data source with sample data |
| `--mock-data-only` | Generate only mock data file |
| `--use-mock` | Use mock datasource in DI instead of remote |

### Custom UseCase Generation

ZFA introduces four distinct patterns for custom UseCases:

#### Single Repository Pattern (Recommended)
Use one UseCase with one repository to enforce Single Responsibility Principle.

| Flag | Description |
|------|-------------|
| `--repo=<name>` | Single repository to inject |
| `--domain=<name>` | **Required** domain folder for organization |
| `--type=<type>` | UseCase type: `usecase`, `stream`, `background`, `completable` |
| `--params=<type>` | Params type (default: `NoParams`) |
| `--returns=<type>` | Return type (default: `void`) |

#### Orchestrator Pattern (NEW)
Compose multiple UseCases into workflows.

| Flag | Description |
|------|-------------|
| `--usecases=<list>` | Comma-separated UseCases to compose |
| `--domain=<name>` | **Required** domain folder for organization |
| `--params=<type>` | Params type (required for orchestrators) |
| `--returns=<type>` | Return type (required for orchestrators) |

#### Polymorphic Pattern (NEW)
Generate abstract base + concrete variants + factory.

| Flag | Description |
|------|-------------|
| `--variants=<list>` | Comma-separated variants for polymorphic pattern |
| `--repo=<name>` | Repository to inject |
| `--domain=<name>` | **Required** domain folder for organization |
| `--params=<type>` | Params type (required for polymorphic) |
| `--returns=<type>` | Return type (required for polymorphic) |

### Dependency Injection Flags

| Flag | Description |
|------|-------------|
| `--di` | Generate dependency injection files (get_it) |

### Testing Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--test` | `-t` | Generate unit tests for UseCases |

### Input/Output Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--from-json=<file>` | `-j` | Read configuration from JSON file |
| `--from-stdin` | | Read configuration from stdin (AI-friendly) |
| `--output=<dir>` | `-o` | Output directory (default: `lib/src`) |
| `--format=<type>` | | Output format: `json`, `text` |
| `--dry-run` | | Preview without writing files |
| `--force` | | Overwrite existing files |
| `--verbose` | `-v` | Verbose output |
| `--quiet` | `-q` | Minimal output (errors only) |
| `--append` | | Append method to existing repository/datasource files |

---

## schema

Output the JSON schema for configuration validation. Useful for AI agents and IDE integrations.

```bash
zfa schema
```

Output the schema to a file:

```bash
zfa schema > zfa-schema.json
```

---

## validate

Validate a JSON configuration file before generation.

```bash
zfa validate config.json
```

Returns exit code 0 if valid, 1 if invalid with error messages.

---

## initialize

Create a sample entity file with common fields to get started quickly.

```bash
zfa initialize [options]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--entity=<name>` | `Product` | Entity name to create |
| `--output=<dir>` | `lib/src` | Output directory |
| `--force` | false | Overwrite existing files |

Creates a complete entity at `lib/src/domain/entities/{entity}/{entity}.dart` with:
- Common fields (id, name, description, price, etc.)
- copyWith method
- Equality operators
- toString
- JSON serialization

---

## ZFA Patterns

### Entity-Based Pattern

Perfect for standard CRUD operations on entities:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete,watch,watchList \
  --data \
  --vpc \
  --state \
  --test \
  --cache \
  --di
```

### Single Repository Pattern

Best for custom business logic with one repository:

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --repo=Checkout \
  --params=CheckoutRequest \
  --returns=OrderConfirmation
```

### Orchestrator Pattern

Compose multiple UseCases into complex workflows:

```bash
# Step 1: Create atomic UseCases
zfa generate ValidateCart --domain=checkout --repo=Cart --params=CartId --returns=bool
zfa generate CreateOrder --domain=checkout --repo=Order --params=OrderData --returns=Order
zfa generate ProcessPayment --domain=checkout --repo=Payment --params=PaymentData --returns=Receipt

# Step 2: Orchestrate them
zfa generate ProcessCheckout \
  --domain=checkout \
  --usecases=ValidateCart,CreateOrder,ProcessPayment \
  --params=CheckoutRequest \
  --returns=Order
```

### Polymorphic Pattern

Generate multiple implementations of the same operation:

```bash
zfa generate SparkSearch \
  --domain=search \
  --repo=Search \
  --variants=Barcode,Url,Text \
  --params=Spark \
  --returns=Listing \
  --type=stream
```

This generates:
- Abstract base class: `SparkSearchUseCase`
- Concrete implementations: `BarcodeSparkSearchUseCase`, `UrlSparkSearchUseCase`, `TextSparkSearchUseCase`
- Factory: `SparkSearchUseCaseFactory`

---

## Examples

### Complete CRUD Stack

Generate everything needed for a full feature:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete,watch,watchList \
  --data \
  --vpc \
  --state \
  --di \
  --test \
  --cache
```

This generates:
- ✅ Domain layer (UseCases + Repository interface)
- ✅ Data layer (DataRepository + DataSource)
- ✅ Presentation layer (View, Presenter, Controller, State)
- ✅ Dependency injection setup
- ✅ Unit tests
- ✅ Caching with dual datasources

### With Caching

Enable dual datasource caching:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --cache \
  --cache-policy=daily \
  --cache-storage=hive
```

### Custom UseCase with Single Repository

Simple business operation:

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --repo=CheckoutRepository \
  --params=CheckoutRequest \
  --returns=OrderConfirmation
```

### Background Processing

CPU-intensive operation on isolate:

```bash
zfa generate ProcessImages \
  --domain=image \
  --repo=ImageProcessor \
  --type=background \
  --params=ImageBatch \
  --returns=ProcessedImages
```

### Stream UseCase

Real-time data:

```bash
zfa generate ListenToNotifications \
  --domain=notification \
  --repo=NotificationRepository \
  --type=stream \
  --params=UserId \
  --returns=Notification
```

### Granular VPC Generation

Regenerate business logic while preserving custom UI:

```bash
# Regenerate Presenter + Controller + State, keep custom View
zfa generate Product --methods=get,create --pc --state --force

# Or shorthand
zfa generate Product --methods=get,create --pcs --force
```

### Mock Data for Development

Generate mock data for testing without backend:

```bash
# Generate mock datasource with sample data
zfa generate Product --methods=get,getList --data --mock

# Use mock in DI for development
zfa generate Product --methods=get,getList --di --use-mock
```

### Singleton Entity

For entities without IDs (app config, user session):

```bash
zfa generate AppConfig \
  --methods=get,watch \
  --data \
  --id-field=null
```

### Append to Existing Files

Add new methods to existing repositories:

```bash
zfa generate WatchProduct \
  --domain=product \
  --repo=Product \
  --params=String \
  --returns=Stream<Product> \
  --type=stream \
  --append
```

This adds the new method to existing Repository, DataRepository, DataSource, and RemoteDataSource files.

### AI-Friendly JSON Output

For AI agent integration:

```bash
# Generate with JSON output
zfa generate Product --methods=get,getList --data --format=json

# Dry run to preview
zfa generate Product --methods=get,getList --dry-run --format=json

# From stdin
echo '{"name":"Product","methods":["get","getList"],"data":true}' | \
  zfa generate Product --from-stdin --format=json
```

---

## JSON Configuration

Instead of command-line flags, use JSON configuration:

```json
{
  "name": "Product",
  "methods": ["get", "getList", "create", "update", "delete"],
  "data": true,
  "vpc": true,
  "state": true,
  "di": true,
  "test": true,
  "cache": true,
  "cache_policy": "daily",
  "mock": true,
  "domain": "product"
}
```

Use it:

```bash
zfa generate Product -j config.json
```

### Full JSON Schema

```json
{
  "name": "string (required)",
  "methods": ["get", "getList", "create", "update", "delete", "watch", "watchList"],
  "data": "boolean",
  "vpc": "boolean",
  "vpcs": "boolean",
  "pc": "boolean",
  "pcs": "boolean",
  "view": "boolean",
  "presenter": "boolean",
  "controller": "boolean",
  "state": "boolean",
  "observer": "boolean",
  "test": "boolean",
  "di": "boolean",
  "datasource": "boolean",
  "init": "boolean",
  "id_field": "string (default: 'id')",
  "id_field_type": "string (default: 'String')",
  "query_field": "string (default: 'id')",
  "query_field_type": "string",
  "zorphy": "boolean",
  "morphy": "boolean (alias for zorphy)",
  "repo": "string",
  "usecases": ["string"],
  "variants": ["string"],
  "domain": "string (required for custom usecases)",
  "type": "usecase | stream | background | completable",
  "params": "string",
  "returns": "string",
  "cache": "boolean",
  "cache_policy": "daily | restart | ttl",
  "cache_storage": "hive | sqlite | shared_preferences",
  "ttl": "number (minutes)",
  "mock": "boolean",
  "mock_data_only": "boolean",
  "use_mock": "boolean",
  "append": "boolean",
  "output": "string",
  "format": "json | text",
  "dry_run": "boolean",
  "force": "boolean",
  "verbose": "boolean",
  "quiet": "boolean"
}
```

---

## Validation Rules

ZFA enforces strict validation rules:

| UseCase Type | `--domain` | `--repo` | `--usecases` | `--variants` |
|--------------|------------|----------|--------------|--------------|
| Entity-based | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden |
| Custom | ✅ Required | ✅ Required | ❌ Forbidden | ⚠️ Optional |
| Orchestrator | ✅ Required | ❌ Forbidden | ✅ Required | ⚠️ Optional |
| Background | ✅ Required | ⚠️ Optional | ❌ Forbidden | ⚠️ Optional |
| Polymorphic | ✅ Required | ✅ Required | ❌ Forbidden | ✅ Defines pattern |

### Error Messages

Common validation errors:

- `--domain is required for custom UseCases`: Add `--domain=<name>`
- `--repo cannot be used with entity-based generation`: Remove `--repo` for entity-based
- `Cannot use both --repo and --usecases`: Choose one or the other
- `--params is required for orchestrator UseCases`: Add `--params=<Type>`
- `--returns is required for orchestrator UseCases`: Add `--returns=<Type>`

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (invalid args, generation failed, validation failed) |

---

## Tips

### Use `--dry-run` First

Preview what will be generated:

```bash
zfa generate Product --methods=get,create --data --dry-run
```

### Combine with `--force`

Regenerate specific parts without affecting others:

```bash
# Add watch methods to existing entity
zfa generate Product --methods=watch,watchList --data --force
```

### Use `--append` for Evolution

Add new methods to existing files without regenerating:

```bash
zfa generate NewFeature --domain=product --repo=Product --append
```

### Organize by Domain

Use domains to organize custom UseCases:

```bash
zfa generate SearchProduct \
  --domain=search \
  --repo=Product \
  --params=Query \
  --returns=List<Product>
```

### Quiet Mode for Scripts

```bash
zfa generate Product --methods=get --quiet || echo "Generation failed"
```

---

## Next Steps

- [UseCase Types](../architecture/usecases) - Explore all UseCase patterns and ZFA patterns
- [VPC Generation](../architecture/usecases) - Presentation layer patterns
- [Caching](../architecture/usecases) - Dual datasource caching setup
- [Testing](../architecture/usecases) - Testing generated code
