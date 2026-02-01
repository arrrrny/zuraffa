# CLI Commands Reference

The `zfa` CLI provides powerful code generation capabilities for Zuraffa's Clean Architecture. This reference covers all commands, flags, and options.

## Commands Overview

| Command | Description |
|---------|-------------|
| [`zfa generate`](#generate) | Generate Clean Architecture code |
| [`zfa schema`](#schema) | Output JSON schema for validation |
| [`zfa validate`](#validate) | Validate JSON configuration |
| [`zfa initialize`](#initialize) | Create a sample entity |

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
| `--repository` | `-r` | Generate repository interface |
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
| `--morphy` | false | Use Morphy-style typed patches for updates |
| `--init` | false | Generate initialize method for repository/datasource |

### VPC Layer Flags

Generate presentation layer components.

| Flag | Description |
|------|-------------|
| `--vpc` | Generate View + Presenter + Controller |
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
| `--cache-storage=<storage>` | Local storage: `hive` |
| `--mock` | Generate mock data source with sample data |
| `--mock-data-only` | Generate only mock data file |
| `--use-mock` | Use mock datasource in DI instead of remote |

### Custom UseCase Flags

Create standalone UseCases without an entity.

| Flag | Description |
|------|-------------|
| `--repos=<list>` | Comma-separated repositories to inject |
| `--type=<type>` | UseCase type: `usecase`, `stream`, `background`, `completable` |
| `--params=<type>` | Params type (default: `NoParams`) |
| `--returns=<type>` | Return type (default: `void`) |

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
| `--subdirectory=<dir>` | | Subdirectory for organization |
| `--format=<type>` | | Output format: `json`, `text` |
| `--dry-run` | | Preview without writing files |
| `--force` | | Overwrite existing files |
| `--verbose` | `-v` | Verbose output |
| `--quiet` | `-q` | Minimal output (errors only) |

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

Creates a complete entity at `lib/src/domain/entities/{entity}/{entity}.dart` with:
- Common fields (id, name, description, price, etc.)
- copyWith method
- Equality operators
- toString
- JSON serialization

---

## Examples

### Complete CRUD Stack

Generate everything needed for a full feature:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete,watch,watchList \
  --repository \
  --data \
  --vpc \
  --state \
  --di \
  --test
```

This generates:
- ✅ Domain layer (UseCases + Repository interface)
- ✅ Data layer (DataRepository + DataSource)
- ✅ Presentation layer (View, Presenter, Controller, State)
- ✅ Dependency injection setup
- ✅ Unit tests

### Minimal Setup

Just the essentials:

```bash
zfa generate Product --methods=get,getList --repository
```

### With Caching

Enable dual datasource caching:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --repository \
  --data \
  --cache \
  --cache-policy=daily \
  --cache-storage=hive
```

### Custom UseCase

Complex business operation:

```bash
zfa generate ProcessCheckout \
  --repos=CartRepository,OrderRepository,PaymentRepository \
  --params=CheckoutRequest \
  --returns=OrderConfirmation
```

### Background Processing

CPU-intensive operation on isolate:

```bash
zfa generate ProcessImages \
  --type=background \
  --params=ImageBatch \
  --returns=ProcessedImages
```

### Stream UseCase

Real-time data:

```bash
zfa generate ListenToNotifications \
  --type=stream \
  --repos=NotificationRepository \
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
zfa generate Product --methods=get,getList --repository --data --mock

# Use mock in DI for development
zfa generate Product --methods=get,getList --di --use-mock
```

### Singleton Entity

For entities without IDs (app config, user session):

```bash
zfa generate AppConfig \
  --methods=get,watch \
  --repository \
  --id-field=null
```

### AI-Friendly JSON Output

For AI agent integration:

```bash
# Generate with JSON output
zfa generate Product --methods=get,getList --repository --format=json

# Dry run to preview
zfa generate Product --methods=get,getList --dry-run --format=json

# From stdin
echo '{"name":"Product","methods":["get","getList"],"repository":true}' | \
  zfa generate Product --from-stdin --format=json
```

---

## JSON Configuration

Instead of command-line flags, use JSON configuration:

```json
{
  "name": "Product",
  "methods": ["get", "getList", "create", "update", "delete"],
  "repository": true,
  "data": true,
  "vpc": true,
  "state": true,
  "di": true,
  "test": true,
  "cache": true,
  "cache_policy": "daily",
  "mock": true
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
  "repository": "boolean",
  "data": "boolean",
  "vpc": "boolean",
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
  "morphy": "boolean",
  "repos": ["string"],
  "type": "usecase | stream | background | completable",
  "params": "string",
  "returns": "string",
  "cache": "boolean",
  "cache_policy": "daily | restart | ttl",
  "cache_storage": "hive",
  "mock": "boolean",
  "mock_data_only": "boolean",
  "use_mock": "boolean",
  "subdirectory": "string"
}
```

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
zfa generate Product --methods=get,create --repository --dry-run
```

### Combine with `--force`

Regenerate specific parts without affecting others:

```bash
# Add watch methods to existing entity
zfa generate Product --methods=watch,watchList --repository --force
```

### Organize with Subdirectories

```bash
zfa generate Product \
  --methods=get,getList \
  --repository \
  --subdirectory=ecommerce/products
```

### Quiet Mode for Scripts

```bash
zfa generate Product --methods=get --quiet || echo "Generation failed"
```

---

## Next Steps

- [Entity Generation](./entity-generation) - Detailed entity generation guide
- [VPC Generation](./vpc-generation) - Presentation layer patterns
- [Caching](./caching) - Dual datasource caching setup
- [Testing](../guides/testing) - Testing generated code