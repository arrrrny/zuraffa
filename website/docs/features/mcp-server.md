# MCP Server

**Zuraffa** is the first Flutter framework with a built-in **Model Context Protocol (MCP)** server, enabling a deep, AI-native development experience.

---

## 🦄 What is MCP?

The **Model Context Protocol** is an open standard that allows AI assistants (like Trae, Cursor, and Windsurf) to securely access local tools and project resources. By enabling Zuraffa's MCP server, your AI agent can now:

*   **Contextual Generation**: Generate features based on existing entities and domain logic.
*   **Architectural Awareness**: Navigate and refactor your Clean Architecture layers with high precision.
*   **Real-time Diagnostics**: Run `zfa doctor` and fix violations automatically.
*   **Supercharged Entities**: Create, modify, and extend **Zorphy** entities via natural language.

---

## 📦 Installation

Zuraffa version **3.19.0** provides three ways to set up the MCP server.

### 1. Automatic via pub.dev (Recommended)

```bash
dart pub global activate zuraffa
zuraffa_mcp_server
```

**Benefits:** Fast setup, automatic updates, and binary caching.

### 2. Pre-compiled Binaries (Fastest Startup)

Download optimized binaries from our [GitHub Releases](https://github.com/arrrrny/zuraffa/releases):
- **macOS ARM64 / x64**
- **Linux x64**
- **Windows x64**

```bash
# macOS example
curl -L https://github.com/arrrrny/zuraffa/releases/latest/download/zuraffa_mcp_server-macos-arm64 -o zuraffa_mcp_server
chmod +x zuraffa_mcp_server
sudo mv zuraffa_mcp_server /usr/local/bin/
```

### 3. Build from Source
```bash
dart compile exe bin/zuraffa_mcp_server.dart -o zuraffa_mcp_server
```

## Configuration

### Claude Desktop

Configure MCP server in Claude Desktop by adding to your configuration file:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
**Linux:** `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "zuraffa": {
      "command": "/usr/local/bin/zuraffa_mcp_server",
      "args": [],
      "cwd": "/path/to/your/flutter/project"
    }
  }
}
```

:::tip
Use the full path to the binary for reliability. Find it with `which zuraffa_mcp_server`.
:::

### Cursor / VS Code

Add to your workspace settings (`.vscode/settings.json`) or MCP configuration:

```json
{
  "mcp.servers": {
    "zuraffa": {
      "command": "zuraffa_mcp_server",
      "args": [],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

### Zed Editor

Configure in Zed settings:

```json
{
  "lsp": {
    "mcp_servers": {
      "zuraffa": {
        "command": "/usr/local/bin/zuraffa_mcp_server",
        "args": [],
        "env": {}
      }
    }
  }
}
```

## Available Tools

The MCP server exposes Zuraffa CLI functionality as MCP tools:

### Clean Architecture Tools

### zuraffa_generate

The primary tool for generating Clean Architecture code. In Zuraffa v3, this tool intelligently maps to `zfa feature` for vertical slices or `zfa make` for granular plugin generation.

**USE THIS TOOL WHEN:**
*   **Creating new features** for existing entities.
*   **Building CRUD operations** (get, list, create, update, delete).
*   **Scaffolding UI** using the VPC (View-Presenter-Controller) pattern.
*   **Adding cross-cutting concerns** like caching, DI, or mock data.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Entity or feature name in PascalCase (e.g., "Product") |
| `methods` | array | No | CRUD methods: get, getList, create, update, delete, watch, watchList |
| `vpcs` | boolean | No | Generate full VPC stack (View, Presenter, Controller, State) |
| `pc` | boolean | No | Generate Presenter + Controller only (preserve custom View) |
| `pcs` | boolean | No | Generate Presenter, Controller, and State (preserve custom View) |
| `state` | boolean | No | Generate State class with granular loading flags |
| `data` | boolean | No | Generate data layer (Repository + DataSource) |
| `datasource` | boolean | No | Generate DataSource implementation only |
| `cache` | boolean | No | Enable dual-datasource caching (Remote + Local) |
| `mock` | boolean | No | Generate static mock data and mock data sources |
| `di` | boolean | No | Generate GetIt dependency injection registrations |
| `test` | boolean | No | Generate unit tests for UseCases and logic |
| `repo` | string | No | Specific repository to inject (SRP enforcement) |
| `domain` | string | No | Domain folder for custom UseCases (e.g., "search") |
| `type` | string | No | UseCase type: usecase, stream, background, sync, completable |
| `zorphy` | boolean | No | Use Zorphy-style typed patches (default: true) |

**Example Usage (Full Feature):**
```json
{
  "name": "zuraffa_generate",
  "arguments": {
    "name": "Product",
    "methods": ["get", "getList", "create"],
    "vpcs": true,
    "data": true,
    "di": true,
    "test": true
  }
}
```

**Example Usage (Granular Plugin):**
```json
{
  "name": "zuraffa_generate",
  "arguments": {
    "name": "Search",
    "domain": "search",
    "params": "SearchRequest",
    "returns": "Listing",
    "type": "usecase",
    "di": true
  }
}
```

### zuraffa_initialize

Initialize a test entity to quickly try out Zuraffa.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `entity` | string | No | Entity name to generate (default: Product) |
| `output` | string | No | Output directory (default: lib/src) |
| `force` | boolean | No | Overwrite existing files |
| `dry_run` | boolean | No | Preview without writing files |

### zuraffa_schema

Get the JSON schema for ZFA configuration validation.

**Parameters:** None

### zuraffa_validate

Validate a JSON configuration file.

**Parameters:**
- `config` (object, required): The configuration to validate

---

### Entity Generation Tools (NEW!)

### entity_create

Create a new Zorphy entity with fields. Supports JSON serialization, sealed classes, inheritance, and all Zorphy features.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Entity name in PascalCase (e.g., User, Product) |
| `output` | string | No | Output directory (default: lib/src/domain/entities) |
| `fields` | array | No | Fields in format "name:type" or "name:type?" for nullable |
| `json` | boolean | No | Enable JSON serialization (default: true) |
| `sealed` | boolean | No | Create sealed abstract class (use $$ prefix) |
| `non_sealed` | boolean | No | Create non-sealed abstract class |
| `copywith_fn` | boolean | No | Enable function-based copyWith |
| `compare` | boolean | No | Enable compareTo generation |
| `extends` | string | No | Interface to extend (e.g., $BaseEntity) |
| `subtype` | array | No | Explicit subtypes for polymorphism (e.g., ["$Dog", "$Cat"]) |

**Example Usage:**
```json
{
  "name": "entity_create",
  "arguments": {
    "name": "User",
    "fields": ["name:String", "email:String?", "age:int"],
    "json": true
  }
}
```

### entity_enum

Create a new enum in the entities/enums directory with automatic barrel export.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Enum name in PascalCase (e.g., Status, UserRole) |
| `output` | string | No | Output base directory (default: lib/src/domain/entities) |
| `values` | array | Yes | Enum values (e.g., ["active", "inactive", "pending"]) |

**Example Usage:**
```json
{
  "name": "entity_enum",
  "arguments": {
    "name": "OrderStatus",
    "values": ["pending", "processing", "shipped", "delivered", "cancelled"]
  }
}
```

### entity_add_field

Add field(s) to an existing Zorphy entity. Automatically updates imports if needed.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Entity name (e.g., User) |
| `output` | string | No | Output base directory (default: lib/src/domain/entities) |
| `fields` | array | Yes | Fields to add in format "name:type" or "name:type?" |

**Example Usage:**
```json
{
  "name": "entity_add_field",
  "arguments": {
    "name": "User",
    "fields": ["phone:String?", "address:$Address"]
  }
}
```

### entity_from_json

Create Zorphy entity/ies from a JSON file. Automatically infers types and creates nested entities.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | Yes | Path to JSON file |
| `name` | string | No | Entity name (inferred from file if not provided) |
| `output` | string | No | Output base directory (default: lib/src/domain/entities) |
| `json` | boolean | No | Enable JSON serialization (default: true) |
| `prefix_nested` | boolean | No | Prefix nested entities with parent name (default: true) |

**Example Usage:**
```json
{
  "name": "entity_from_json",
  "arguments": {
    "file": "user_data.json",
    "name": "UserProfile",
    "json": true
  }
}
```

### entity_list

List all Zorphy entities and enums in the project with their properties.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `output` | string | No | Directory to search (default: lib/src/domain/entities) |

**Example Usage:**
```json
{
  "name": "entity_list",
  "arguments": {
    "output": "lib/src/domain/entities"
  }
}
```

### entity_new

Quick-create a simple Zorphy entity with basic defaults. Good for prototyping.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Entity name in PascalCase |
| `output` | string | No | Output directory (default: lib/src/domain/entities) |
| `json` | boolean | No | Enable JSON serialization (default: true) |

**Example Usage:**
```json
{
  "name": "entity_new",
  "arguments": {
    "name": "Product",
    "json": true
  }
}
```

## Project Resources

The MCP server provides access to your project's generated resources:

### resources/list

List all available files in your project's Clean Architecture and entity directories:

- `lib/src/domain/repositories` - Repository interfaces
- `lib/src/domain/usecases` - UseCase implementations
- `lib/src/data/datasources` - Data source implementations
- `lib/src/data/repositories` - Data repository implementations
- `lib/src/presentation` - Views, Presenters, Controllers
- `lib/src/domain/entities` - Entity definitions (Zorphy entities)
- `lib/src/domain/entities/enums` - Enum definitions

**Example Response:**
```json
{
  "resources": [
    {
      "uri": "file://lib/src/domain/entities/user/user.dart",
      "name": "user",
      "description": "user.dart",
      "mimeType": "text/dart"
    },
    {
      "uri": "file://lib/src/domain/entities/enums/status.dart",
      "name": "status",
      "description": "status.dart",
      "mimeType": "text/dart"
    },
    {
      "uri": "file://lib/src/domain/repositories/product_repository.dart",
      "name": "product_repository",
      "description": "product_repository.dart",
      "mimeType": "text/dart"
    }
  ]
}
```

### resources/read

Read the contents of a specific file using its URI from `resources/list`.

**Parameters:**
- `uri` (string, required): File URI to read (from the `resources/list` response)

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "resources/read",
  "id": 10,
  "params": {
    "uri": "file://lib/src/domain/entities/user/user.dart"
  }
}
```

## AI/IDE Integration Examples

### Generate Complete Feature with Entities

```bash
# AI agent workflow:
1. Create enum: entity_enum(name="OrderStatus", values=["pending","shipped"])
2. Create entity: entity_create(name="Order", fields=["customer:$Customer", "total:double"])
3. Generate architecture: zuraffa_generate(name="Order", methods=["get","create"], data=true, vpcs=true)
4. Build: zuraffa_build()
```

### Iterate on Entity Design

```json
// AI agent conversation:
{
  "role": "user",
  "content": "Create a User entity with name, email, and address fields"
}

// Agent calls:
{
  "name": "entity_create",
  "arguments": {
    "name": "User",
    "fields": ["name:String", "email:String?", "address:$Address"]
  }
}
```

### Import from API Response

```json
// After receiving API documentation:
{
  "name": "entity_from_json",
  "arguments": {
    "file": "api_response.json",
    "name": "ApiResponse",
    "json": true
  }
}
```

## Notifications

When tools create new files, the MCP server automatically sends resource change notifications to the agent. This ensures the agent is aware of newly generated files without needing to explicitly query them.

**Example notification after entity creation:**

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/resources/list_changed",
  "params": {
    "changes": [
      {
        "type": "created",
        "uri": "file://lib/src/domain/entities/user/user.dart"
      },
      {
        "type": "created",
        "uri": "file://lib/src/domain/entities/user/user.zorphy.dart"
      },
      {
        "type": "created",
        "uri": "file://lib/src/domain/entities/user/user.g.dart"
      }
    ]
  }
}
```

## Testing

Test the server directly:

```bash
# Test initialize
echo '{"jsonrpc":"2.0","method":"initialize","id":1}' | zuraffa_mcp_server

# List tools (includes entity commands!)
echo '{"jsonrpc":"2.0","method":"tools/list","id":2}' | zuraffa_mcp_server

# Create entity via MCP
echo '{"jsonrpc":"2.0","method":"tools/call","id":3,"params":{"name":"entity_create","arguments":{"name":"TestUser","fields":["name:String"]}}}' | zuraffa_mcp_server
```

## Troubleshooting

### Timeout Issues

**Problem:** MCP client times out during connection or requests.

**Cause:** Using `dart run` compiles the package on every invocation, taking 10-30 seconds.

**Solution:** Use a precompiled executable:

```bash
dart compile exe bin/zuraffa_mcp_server.dart -o zuraffa_mcp_server
```

### Build Errors After Entity Creation

**Problem:** Generated entity code has compilation errors.

**Solution:** Run `zfa build` after entity creation:

```bash
zfa entity create -n User --field name:String
zfa build  # This generates the implementation
```

## Best Practices

### 1. Create Entities Before Architecture

Always create entities before generating Clean Architecture:

```json
// ✅ Good - Create entity first
entity_create(name="Product", fields=["name:String", "price:double"])
zuraffa_generate(name="Product", methods=["get", "create"], data=true)

// ❌ Bad - Product entity doesn't exist yet
zuraffa_generate(name="Product", methods=["get", "create"], data=true)
```

### 2. Use --dry-run for Testing

When working with AI agents, preview changes first:

```json
{
  "name": "entity_create",
  "arguments": {
    "name": "User",
    "fields": ["name:String"],
    "dry_run": true
  }
}
```

### 3. Leverage Resource Notifications

Monitor file creation notifications to understand what was generated:

```bash
# Agent receives notifications for:
# - user.dart (your definition)
# - user.zorphy.dart (generated implementation)
# - user.g.dart (JSON serialization)
```

## Next Steps

- [Entity Generation](../entities/intro) - Complete entity generation guide
- [CLI Reference](../cli/commands) - Complete CLI documentation
- [Entity Commands](../cli/entity-commands) - Entity command reference
- [Architecture Overview](../architecture/overview) - Clean Architecture patterns
