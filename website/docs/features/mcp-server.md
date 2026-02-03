# MCP Server

The `zuraffa_mcp_server` is a **Model Context Protocol (MCP) server** that exposes Zuraffa CLI functionality as MCP tools, enabling seamless integration with AI-powered development environments like Claude Desktop, Cursor, and VS Code.

## What is MCP?

The **Model Context Protocol** is a standardized protocol that allows AI assistants to access tools, resources, and configuration within your development environment. MCP enables AI agents to:

- Execute CLI commands
- Access project files
- Generate code
- Retrieve project metadata
- Integrate with your development workflow

## Installation Options

Zuraffa MCP server offers three installation approaches to suit different needs:

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
    "zfa": {
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
  /// The name of your MCP server
  "flutter-clean-architecture": {
    /// The command which runs the MCP server
    "command": "/usr/local/bin/zuraffa_mcp_server",
    /// The arguments to pass to the MCP server
    "args": [],
    /// The environment variables to set
    "env": {}
  }
}
```

## Available Tools

The MCP server exposes Zuraffa CLI functionality as MCP tools:

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
| `morphy` | boolean | No | Use Morphy-style typed patches |
| `repo` | string | No | Repository to inject (enforces Single Responsibility Principle) |
| `usecases` | array | No | UseCases to compose (orchestrator pattern) |
| `variants` | array | No | Variants for polymorphic pattern |
| `domain` | string | No | Domain folder for custom UseCases (required for custom) |
| `method` | string | No | Repository method name (default: auto from UseCase name) |
| `append` | boolean | No | Append method to existing repository/datasource files |
| `params` | string | No | Params type for custom UseCase (default: NoParams) |
| `returns` | string | No | Return type for custom UseCase (default: void) |
| `type` | string | No | UseCase type: usecase, stream, background, completable |
| `output` | string | No | Output directory (default: lib/src) |
| `dry_run` | boolean | No | Preview without writing files |
| `force` | boolean | No | Overwrite existing files |
| `verbose` | boolean | No | Enable verbose output |
| `test` | boolean | No | Generate unit tests |
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
  "name": "generate",
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
| `verbose` | boolean | No | Enable verbose output |

### zuraffa_schema

Get the JSON schema for ZFA configuration validation.

**Parameters:** None

### zuraffa_validate

Validate a JSON configuration file.

**Parameters:**
- `config` (object, required): The configuration to validate

## Project Resources

The MCP server provides access to your project's generated resources:

### resources/list

List all available files in your project's Clean Architecture directories:

- `lib/src/domain/repositories` - Repository interfaces
- `lib/src/domain/usecases` - UseCase implementations
- `lib/src/data/data_sources` - Data source implementations
- `lib/src/data/repositories` - Data repository implementations
- `lib/src/presentation` - Views, Presenters, Controllers
- `lib/src/domain/entities` - Entity definitions

**Example Response:**
```json
{
  "resources": [
    {
      "uri": "file://lib/src/domain/repositories/product_repository.dart",
      "name": "product_repository",
      "description": "product_repository.dart",
      "mimeType": "text/dart"
    },
    {
      "uri": "file://lib/src/domain/usecases/product/get_product_usecase.dart",
      "name": "product.get_product_usecase",
      "description": "product/get_product_usecase.dart",
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
    "uri": "file://lib/src/domain/repositories/product_repository.dart"
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "contents": [
      {
        "uri": "file://lib/src/domain/repositories/product_repository.dart",
        "mimeType": "text/dart",
        "text": "abstract class ProductRepository {\n  Future<Product> get(String id);\n  Future<List<Product>> getList();\n  Future<Product> create(Product product);\n  Future<Product> update(Product product);\n  Future<void> delete(String id);\n}"
      }
    ]
  },
  "id": 10
}
```

## Notifications

When the `zuraffa_generate` tool creates new files, the MCP server automatically sends resource change notifications to the agent. This ensures the agent is aware of newly generated files without needing to explicitly query them.

**Example notification sent after generating code:**

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/resources/list_changed",
  "params": {
    "changes": [
      {
        "type": "created",
        "uri": "file://lib/src/domain/repositories/product_repository.dart"
      },
      {
        "type": "created",
        "uri": "file://lib/src/domain/usecases/product/get_product_usecase.dart"
      }
    ]
  }
}
```

This enables the agent to:
- Automatically become aware of new files as they are created
- Update its context with generated code without manual intervention
- Call `resources/list` to see all available files in the project
- Call `resources/read` to read the contents of specific files
- Continue working with the generated files seamlessly

## Testing

Test the server directly:

```bash
# Test initialize (using precompiled binary)
echo '{"jsonrpc":"2.0","method":"initialize","id":1}' | zuraffa_mcp_server

# List tools
echo '{"jsonrpc":"2.0","method":"tools/list","id":2}' | zuraffa_mcp_server

# Get schema
echo '{"jsonrpc":"2.0","method":"tools/call","id":3,"params":{"name":"zuraffa_schema","arguments":{}}}' | zuraffa_mcp_server
```

## Troubleshooting

### Timeout Issues

**Problem:** MCP client times out during connection or requests.

**Cause:** Using `dart run` compiles the package on every invocation, taking 10-30 seconds.

**Solution:** Use a precompiled executable:

```bash
# From zuraffa directory
dart compile exe bin/zuraffa_mcp_server.dart -o zuraffa_mcp_server

# Then update your MCP configuration to use the precompiled binary:
"command": "zuraffa_mcp_server"
```

**Alternative:** If you must use `dart run`, increase your MCP client timeout setting to at least 90 seconds.

### General Issues

- Ensure Dart is in your PATH (if using `dart run`)
- Check the working directory in your MCP configuration
- Make sure the entity file exists at the expected path before generating
- Recompile the executable if you've made code changes to `zuraffa_mcp_server.dart`

## Best Practices

### 1. Use Pre-compiled Binaries for Production

For fastest startup and best performance, use the pre-compiled binaries from GitHub Releases.

### 2. Configure Proper Working Directory

Always set the correct `cwd` (current working directory) to your Flutter project root in MCP configuration.

### 3. Leverage Notifications

Take advantage of automatic resource change notifications to keep AI agents synchronized with your project.

### 4. Use --dry-run for Preview

When integrating with AI agents, use `dry_run: true` to preview changes before applying them.

## Next Steps

- [CLI Reference](../cli/commands) - Complete CLI documentation with all flags and options
- [Architecture Overview](../architecture/overview) - Clean Architecture patterns
- [UseCase Types](../architecture/usecases) - UseCase patterns and ZFA patterns