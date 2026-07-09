# Integrations

Zuraffa integrates with AI agents via the **MCP server**, with GraphQL APIs via schema introspection, with IDEs via **Zed extension**, and with observability platforms via **OpenTelemetry**.

## MCP Server

The MCP server (`bin/zuraffa_mcp_server.dart`) implements the **Model Context Protocol** (JSON-RPC 2.0 over stdio), enabling AI agents to drive the canonical v5 workflow programmatically.

### Architecture

The MCP server does **not** import the zfa CLI code directly. Instead, it spawns CLI subprocesses via `Process.run()` — this keeps the server lightweight and avoids slow JIT warmup.

```
AI Agent (Claude, Zed, etc.)
  → JSON-RPC over stdio
    → zuraffa_mcp_server (reads stdin, writes stdout)
      → Process.run('dart run zuraffa:zuraffa', [...args])
        → zfa CLI generates files
```

**Executable resolution** (`_resolveExecutable` in `zuraffa_mcp_server.dart`, ~line 1410):
1. Compiled binary next to the MCP server (Zed extension scenario)
2. Compiled binary in current directory
3. `zfa` in PATH (only if compiled binary, not a shell script)
4. Fallback: `dart run zuraffa:zuraffa` (slow JIT path)

### Built-in Tools

| MCP Tool | Underlying CLI Command |
|---|---|
| `zuraffa_make` | `zfa make` |
| `zuraffa_entity_create` | `zfa entity create` |
| `zuraffa_entity_enum` | `zfa entity enum` |
| `zuraffa_entity_add_field` | `zfa entity add-field` |
| `zuraffa_entity_from_json` | `zfa entity create --from-json` |
| `zuraffa_entity_list` | `zfa entity list` |
| `zuraffa_build` | `zfa build` |
| `zuraffa_config_init / config_show / config_set` | `zfa config init / show / set` |
| `zuraffa_schema` | `zfa schema` |
| `zuraffa_validate` | `zfa validate` |
| `zuraffa_graphql` | `zfa graphql` (introspection flow) |
| `zuraffa_doctor` | `zfa doctor` |

Additionally, every plugin's capabilities are dynamically registered as MCP tools using the naming convention `zuraffa_<plugin_id>_<capability_name>`.

### MCP Resources

The server also exposes MCP **resources** for file access:
- **`resources/list`** — scans project files (cached for 10 minutes, max 100 files)
- **`resources/read`** — reads a file by `file://` URI with `text/dart` MIME type

### Key Source Files

| File | Purpose |
|---|---|
| `bin/zuraffa_mcp_server.dart` | Full MCP server implementation (~1,600 lines) |
| `doc/MCP_SERVER.md` | User-facing MCP documentation |
| `extensions/zed/` | Zed extension packaging |

### Agent Contract (from `doc/MCP_SERVER.md`)

When an AI agent is asked to implement a feature, it should:

1. Inspect the project and existing entities
2. Create entities with `zuraffa_entity_create` (if they don't exist)
3. Generate architecture with `zuraffa_make`
4. Build with `zuraffa_build`
5. Let the developer fill in narrow implementation details (business logic, UI polish)

---

## GraphQL Integration

Zuraffa can introspect a remote GraphQL endpoint and generate entities, enums, and use cases from the schema.

### Pipeline

```
GraphQL endpoint URL
  → Introspection query (HTTP POST)
    → GqlSchema parsed (types, fields, enums, operations)
      → Schema translator maps to EntitySpec, EnumSpec, OperationSpec
        → Entity emitter generates Dart files with Zorphy annotations
```

### Key Source Files

| File | Purpose |
|---|---|
| `lib/src/graphql/graphql_introspection_service.dart` | Fetches schema via standard introspection query |
| `lib/src/graphql/graphql_schema.dart` | Data models: `GqlTypeRef`, `GqlField`, `GqlTypeDef`, `GqlSchema` |
| `lib/src/graphql/graphql_schema_translator.dart` | Maps GraphQL scalars → Dart types, infers ID fields, resolves references |
| `lib/src/graphql/graphql_entity_emitter.dart` | Generates Dart files using `code_builder`, delegates to `zorphy` CLI |
| `lib/src/commands/graphql_command.dart` | CLI command wrapping `CreateGraphqlCapability` |
| `lib/src/plugins/graphql/` | Plugin with `CreateGraphqlCapability` |

### Usage

```bash
# Introspect and generate entities from a GraphQL endpoint
zfa graphql introspect https://api.example.com/graphql

# Generate from an existing schema
zfa graphql generate -n Product --type query --returns Product
```

---

## Zed Extension

The `extensions/zed/` directory contains packaging for the [Zed editor](https://zed.dev) extension, embedding the MCP server for in-editor AI generation.

---

## OpenTelemetry

Zuraffa ships opinionated OpenTelemetry integration for observability.

### Components

| Component | File | Purpose |
|---|---|---|
| `OtelTracer` | `lib/src/core/otel_tracer.dart` | Thin singleton for creating/managing OTel traces — handles the happy path and business operations |
| `OtelFailureReporter` | `lib/src/core/otel_failure_reporter.dart` | Maps each `AppFailure` to an OTel Span with error status and enriched attributes |
| `OtelLogExporter` | `lib/src/core/otel_log_exporter.dart` | Exports structured logs to OTLP-compatible collectors |

### Key Features

- **`OtelTracer.trace()`** — wraps a business operation in a span (auto-handles end/error)
- **`OtelFailureReporter`** — uses `BatchSpanProcessor` + `CollectorExporter` for efficient delivery
- **Failure span attributes**: `failure.type`, `failure.message`, `failure.cause`, `http.status_code` (for `ServerFailure`)
- **Shared TracerProvider** — both `OtelTracer` and `OtelFailureReporter` share the same global `TracerProvider` registered at startup via `OtelFailureReporter.initialize`

### Usage

```dart
// Initialize once at app startup
OtelFailureReporter.initialize(
  collectorEndpoint: Uri.parse('https://otel.mybackend.com/v1/traces'),
  serviceName: 'my_app',
);

// Register with Zuraffa
Zuraffa.addFailureReporter(otelFailureReporter);

// Trace business operations
final result = await OtelTracer.instance.trace(
  'checkout.process',
  attributes: [Attribute.fromString('order.id', orderId)],
  () async => processOrder(orderId),
);
```

UseCase execution automates tracing — each `UseCase.call()` wraps execution in an OTel span with `useCaseName`, `params`, and result/failure context.

---

## Source Map

```
bin/
├── zuraffa_mcp_server.dart          # MCP server (~1600 lines)
extensions/zed/                       # Zed editor extension
lib/src/
├── core/
│   ├── otel_tracer.dart              # OpenTelemetry tracing singleton
│   ├── otel_failure_reporter.dart    # Failure-to-span mapping
│   └── otel_log_exporter.dart        # Structured log export
├── graphql/
│   ├── graphql_introspection_service.dart
│   ├── graphql_schema.dart
│   ├── graphql_schema_translator.dart
│   ├── graphql_entity_emitter.dart
│   └── graphql.dart
├── commands/graphql_command.dart     # CLI graphql command
└── plugins/graphql/                  # GraphQL generation plugin
```
