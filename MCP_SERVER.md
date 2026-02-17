# 🤖 Zuraffa MCP Server Reference

The **Zuraffa MCP Server** exposes the full power of the Zuraffa CLI to AI agents and IDEs supporting the [Model Context Protocol](https://modelcontextprotocol.io/). This allows AI assistants (like Trae, Cursor, Windsurf) to directly manipulate your codebase, creating entities, generating features, and diagnosing issues with context-aware precision.

## 🛠️ Available Tools

The server provides a suite of tools categorized by function.

### 1. Project Management & Health

| Tool | Description | Key Arguments |
|------|-------------|---------------|
| `zuraffa_doctor` | 🏥 Diagnoses project health, checking for misconfigurations, missing dependencies, or dead code. | None |
| `zuraffa_config_init` | Initializes Zuraffa configuration in a new project. | None |
| `zuraffa_config_show` | Displays the current configuration. | None |
| `zuraffa_config_set` | Modifies a configuration value. | `key`, `value` |
| `zuraffa_build` | 🏗️ Runs `build_runner` to generate code (JSON serialization, Zorphy entities). | None |

### 2. Domain Modeling (Entities)

Manage your domain layer directly through AI.

| Tool | Description | Key Arguments |
|------|-------------|---------------|
| `zuraffa_entity_create` | Creates a new Zorphy entity with specified fields. | `name` (required), `fields` (e.g., "name:String"), `output` |
| `zuraffa_entity_enum` | Creates a new Enum. | `name` (required), `values` (comma-separated) |
| `zuraffa_entity_add_field` | Adds a new field to an existing entity. | `entity`, `field` (name:type) |
| `zuraffa_entity_list` | Lists all detected entities in the project. | None |
| `zuraffa_entity_from_json` | Generates an entity from a JSON structure. | `name`, `json` |

### 3. Feature Generation (`zuraffa_generate`)

This is the **primary tool** for scaffolding Clean Architecture features. It corresponds to the `zfa generate` CLI command but with structured inputs for AI.

**Core Arguments:**
- `name` (Required): The name of the Entity (e.g., "Product").
- `methods`: List of CRUD methods to generate (`get`, `getList`, `create`, `update`, `delete`, `watch`, `watchList`).

**Layer Control:**
- `data`: Generate Data Layer (Repository Implementation + DataSources).
- `vpc`: Generate Presentation Layer (View + Presenter + Controller).
- `state`: Generate State class (Recommended with `vpc`).
- `test`: Generate Unit Tests for UseCases.
- `di`: Generate Dependency Injection setup.

**Data Source Fine-Tuning:**
- `remote`: Generate Remote DataSource (API). Default: `true`.
- `local`: Generate Local DataSource (Cache/DB). Default: `true`.
- `mock`: Generate Mock DataSource.
- `cache`: Enable Caching repository logic.

**Example Usage by AI:**
> "Generate a full feature for the 'Order' entity including UI, data layer with caching, and tests."
>
> **Tool Call:**
> ```json
> {
>   "name": "Order",
>   "methods": ["get", "getList", "create"],
>   "vpc": true,
>   "state": true,
>   "data": true,
>   "cache": true,
>   "test": true
> }
> ```

### 4. Specialized Generation

Tools for specific tasks or isolated generation.

| Tool | Description |
|------|-------------|
| `zuraffa_graphql` | Generates GraphQL queries, mutations, or subscriptions. |
| `zuraffa_view` | Generates only the View layer for an entity. |
| `zuraffa_test` | Generates tests for existing features. |
| `zuraffa_di` | Regenerates the Dependency Injection container. |
| `zuraffa_route` | Generates GoRouter routing configuration. |
| `zuraffa_mock` | Generates Mock DataSource for testing or preview. |

### 5. Validation & Schemas

| Tool | Description |
|------|-------------|
| `zuraffa_validate` | Validates a `zuraffa.json` configuration file. |
| `zuraffa_schema` | Returns the JSON schema for Zuraffa configuration. |

## 🏗️ How AI Uses the Architecture

When you ask an AI to "create a feature," it follows this flow using the tools above:

1.  **Analysis**: Calls `zuraffa_entity_list` to understand existing domain objects.
2.  **Modeling**: Calls `zuraffa_entity_create` to define new data structures if needed.
3.  **Scaffolding**: Calls `zuraffa_generate` with specific flags to build the UseCases, Repositories, and UI.
4.  **Refinement**: Calls `zuraffa_build` to finalize code generation.
5.  **Verification**: Calls `zuraffa_doctor` or runs tests to ensure integrity.

This structured approach ensures that the AI respects your project's architecture, enforcing separation of concerns and type safety at every step.
