# MCP Server

The `zuraffa_mcp_server` is a **Model Context Protocol (MCP) server** that exposes Zuraffa CLI functionality as MCP tools, enabling seamless integration with AI-powered development environments like Claude Desktop, Cursor, and VS Code.

## What is MCP?

The **Model Context Protocol** is a standardized protocol that allows AI assistants to access tools, resources, and configuration within your development environment. MCP enables AI agents to:

- Execute CLI commands
- Access project files
- Generate code
- Create entities and data models
- Retrieve project metadata
- Integrate with your development workflow

## Installation Options

Zuraffa MCP server offers three installation approaches to suit different needs. Additionally, you can configure Zorphy (entity generation) defaults via startup flags.

### Zorphy Configuration Flags

Enable Zorphy-style typed entity patches by default for all MCP tool calls:

```json
{
  "mcpServers": {
    "zuraffa": {
      "command": "/usr/local/bin/zuraffa_mcp_server",
      "args": ["--zorphy"],
      "cwd": "/path/to/your/flutter/project"
    }
  }
}
```

Available flags:
- `--zorphy` / `--always-zorphy`: Enable Zorphy by default

When enabled, all code generation will use Zorphy-style typed patches instead of `Partial<T>` for update operations. You can still override this per-request using the `zorphy: false` parameter.

### 1. Automatic via pub.dev (Recommended for Most Users)

```bash
# Activate globally
dart pub global activate zuraffa

# MCP server is immediately available
zuraffa_mcp_server
```

**Benefits:**
- Single command installation
- Dart automatically compiles and caches the executable
- Fast startup after first run
- Automatic updates with `dart pub global activate zuraffa`

### 2. Pre-compiled Binaries (Fastest - No Compilation Needed)

Pre-built binaries are automatically published to [GitHub Releases](https://github.com/arrrrny/zuraffa/releases) for instant startup:

- **macOS ARM64**: `zuraffa_mcp_server-macos-arm64`
- **macOS x64**: `zuraffa_mcp_server-macos-x64`
- **Linux x64**: `zuraffa_mcp_server-linux-x64`
- **Windows x64**: `zuraffa_mcp_server-windows-x64.exe`

```bash
# Download and install (macOS example)
curl -L https://github.com/arrrrny/zuraffa/releases/latest/download/zuraffa_mcp_server-macos-arm64 -o zuraffa_mcp_server
chmod +x zuraffa_mcp_server
sudo mv zuraffa_mcp_server /usr/local/bin/
```

**Benefits:**
- Zero startup time - ready to use immediately
- No compilation overhead
- Optimized for performance
- Instant availability after download

### 3. Compile from Source (For Developers)

Build the server from source for full control:

```bash
# Clone the repository
git clone https://github.com/arrrrny/zuraffa.git
cd zuraffa

# Compile executable
dart compile exe bin/zuraffa_mcp_server.dart -o zuraffa_mcp_server

# Install to system path (optional)
sudo mv zuraffa_mcp_server /usr/local/bin/
```

**Benefits:**
- Full control over compilation
- Ability to modify source code
- Custom optimizations
- Development flexibility

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

Generate Clean Architecture code for your Flutter project.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Entity or UseCase name in PascalCase |
| `methods` | array | No | Methods: get, getList, create, update, delete, watch, watchList |
| `vpc` | boolean | No | Generate View, Presenter, Controller (presentation layer) |
| `pc` | boolean | No | Generate Presenter + Controller only (preserve custom View) |
| `pcs` | boolean | No | Generate Presenter + Controller + State (preserve custom View) |
| `state` | boolean | No | Generate State object with granular loading states |
| `data` | boolean | No | Generate data layer (DataRepository + DataSource) |
| `datasource` | boolean | No | Generate DataSource only |
| `init` | boolean | No | Generate initialize method for repository and datasource |
| `id_field` | string | No | ID field name (default: id) |
| `id_field_type` | string | No | ID field type (default: String) |
| `query_field` | string | No | Query field name for get/watch (default: id) |
| `query_field_type` | string | No | Query field type (default: matches id_field_type) |
| `zorphy` | boolean | No | Use Zorphy-style typed patches |
| `repo` | string | No | Repository to inject (enforces Single Responsibility Principle) |
| `usecases` | array | No | UseCases to compose (orchestrator pattern) |
| `variants` | array | No | Variants for polymorphic pattern |
| `domain` | string | No | Domain folder for custom UseCases (required for custom) |
| `params` | string | No | Params type for custom UseCase (default: NoParams) |
| `returns` | string | No | Return type for custom UseCase (default: void) |
| `type` | string | No | UseCase type: usecase, stream, background, completable |
| `output` | string | No | Output directory (default: lib/src) |
| `dry_run` | boolean | No | Preview without writing files |
| `force` | boolean | No | Overwrite existing files |
| `cache` | boolean | No | Enable caching with dual datasources |
| `cache_policy` | string | No | Cache policy: daily, restart, ttl |
| `cache_storage` | string | No | Local storage: hive, sqlite, shared_preferences |
| `mock` | boolean | No | Generate mock data files |
| `mock_data_only` | boolean | No | Generate only mock data files |
| `use_mock` | boolean | No | Use mock datasource in DI (default: remote) |
| `di` | boolean | No | Generate dependency injection files (get_it) |

**Example Usage:**
```json
{
  "name": "zuraffa_generate",
  "arguments": {
    "name": "Product",
    "methods": ["get", "getList", "create"],
    "vpc": true,
    "data": true,
    "state": true
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
- `lib/src/data/data_sources` - Data source implementations
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
# AI agent workflow in Claude Desktop:
1. Create enum: entity_enum(name="OrderStatus", values=["pending","shipped"])
2. Create entity: entity_create(name="Order", fields=["customer:$Customer", "total:double"])
3. Generate architecture: zuraffa_generate(name="Order", methods=["get","create"], data=true, vpc=true)
4. Build: Automatic via notifications
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
