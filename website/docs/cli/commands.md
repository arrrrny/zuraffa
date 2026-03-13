# CLI Commands Reference

The `zfa` CLI is the primary way to interact with the Zuraffa framework. In v3, we've introduced a more granular and powerful command structure focused on **Features** and **Plugins**.

---

## 🦄 Commands Overview

| Command | Description |
| :--- | :--- |
| [`zfa feature`](#feature) | High-level command to generate full feature slices. |
| [`zfa make`](#make) | Granular command to run specific plugins (UseCases, DI, Mocks, etc.). |
| [`zfa entity`](#entity) | Create and manage Zorphy entities. |
| [`zfa config`](#config) | Manage project-wide ZFA settings. |
| [`zfa doctor`](#doctor) | Audit your project for architectural consistency. |
| [`zfa init`](#init) | Initialize a new Zuraffa project. |

---

## 🚀 feature

The `feature` command is your main tool for scaffolding entire architectural slices. It coordinates multiple plugins to ensure a consistent, Clean Architecture implementation.

```bash
zfa feature <Name> [options]
```

### Examples

**Generate a complete CRUD stack for an entity:**
```bash
zfa feature Product --methods=get,getList,create,update,delete --data --vpcs --state --di --test
```

**Generate a feature with caching and mock data:**
```bash
zfa feature Product --data --cache --mock --use-mock
```

---

## 🛠️ make

The `make` command provides granular access to individual Zuraffa plugins. This is ideal for adding specific components to an existing feature or for "AI-assisted" micro-refactors. **The key advantage of `make` is that you can run multiple plugins in a single command.**

```bash
zfa make <Name> <plugin1> <plugin2> ... [options]
```

### Available Plugins

Zuraffa v3 is built on a modular plugin system. Each plugin can be run independently using `zfa make` or combined for complex generation tasks.

| Plugin ID | Description |
| :--- | :--- |
| **`usecase`** | Generates UseCases (Entity-based, Stream, Sync, Orchestrator, etc.). |
| **`repository`** | Generates Repository interfaces and implementations. |
| **`datasource`** | Generates Remote and Local DataSources. |
| **`service`** | Generates Service interfaces for external integrations. |
| **`provider`** | Generates Data Providers for the presentation layer. |
| **`cache`** | Generates caching logic, dual-datasources, and cache policies. |
| **`di`** | Generates GetIt dependency injection registrations. |
| **`mock`** | Generates static mock data and mock data source implementations. |
| **`view`** | Generates the Flutter View (UI layer). |
| **`presenter`** | Generates the Presenter (logic orchestration). |
| **`controller`** | Generates the Controller (interaction handling). |
| **`state`** | Generates the immutable State object. |
| **`route`** | Generates routing constants and entity-specific routes. |
| **`graphql`** | Generates GraphQL queries, mutations, and subscriptions. |
| **`observer`** | Generates Observer classes for tracking lifecycle events. |
| **`test`** | Generates unit tests for UseCases and logic. |
| **`feature`** | A meta-plugin that coordinates full feature scaffolding. |
| **`method_append`** | AST-aware plugin for adding methods to existing files. |

### Standalone vs. Combined Usage

One of Zuraffa's most powerful features is that **plugins are context-aware**. 

*   **Standalone**: Run a single plugin to add a specific component. 
    *   Example: `zfa make Product di` only updates dependency injection.
*   **Combined**: Run multiple plugins together to build a vertical slice.
    *   Example: `zfa make Product usecase repository di` builds the domain logic, data interface, and wires them up in one go.
*   **Feature Presets**: The `zfa feature` command is essentially a shortcut for running a curated list of plugins (usecase, data, vpc, di, test) with sensible defaults.

### Examples

**Run multiple plugins together:**
```bash
# Generate UseCases, Data layer, and DI for a search feature
zfa make Search usecase data di --domain=search --params=SearchRequest --returns=Listing
```

**Add a specific UseCase to an existing domain:**
```bash
zfa make SearchProducts usecase --domain=search --params=SearchQuery --returns=List<Product>
```

**Regenerate only the DI registrations:**
```bash
zfa make Product di --force
```

---

## 🔄 Smart Revert

Every `make` and `feature` command supports the `--revert` flag. Zuraffa uses an **AST-aware reverter** that intelligently undoes changes:

*   **File Deletion**: If a file was created by the command, it is deleted.
*   **Method Removal**: If a method was appended to an existing file (e.g., adding a method to a Repository), only that method is removed.
*   **Cleanup**: If removing an appended method leaves a class or file empty, Zuraffa will automatically clean up the file to keep your project tidy.

```bash
# Undo the search usecase generation
zfa make SearchProducts usecase --revert
```

---

## 🛡️ Negatable Flags

Zuraffa supports negatable flags for all boolean options. This is useful when your project configuration defaults to `true` but you want to skip a feature for a specific command.

*   `--no-zorphy`: Disable Zorphy entity patterns.
*   `--no-data`: Skip data layer generation even if requested by a feature preset.
*   `--no-test`: Skip test generation.

```bash
zfa feature Product --data --no-zorphy
```

---

## 🏗️ Plugin-Specific Flags

### UseCase Plugin (`zfa make <Name> usecase`)

| Flag | Description |
| :--- | :--- |
| `--domain` | **Required** for custom usecases. Folder for organization. |
| `--type` | `usecase` (default), `stream`, `sync`, `background`, `completable`. |
| `--params` | Parameter type (default: `NoParams`). |
| `--returns` | Return type (default: `void`). |
| `--repo` | Repository interface to inject. |
| `--service` | Service interface to inject. |

### VPC Plugin (`zfa make <Name> vpc`)

| Flag | Description |
| :--- | :--- |
| `--vpcs` | Generate View, Presenter, Controller, and State. |
| `--pcs` | Generate Presenter, Controller, and State (preserves custom View). |
| `--pc` | Generate Presenter and Controller only. |

### Data Plugin (`zfa make <Name> data`)

| Flag | Description |
| :--- | :--- |
| `--cache` | Enable dual-datasource caching (Remote + Local). |
| `--cache-storage` | `hive` (default) or `sqlite`. |
| `--mock` | Generate mock data and data sources. |

---

## 📂 Next Steps

*   [**Entity Commands**](./entity-commands) - Deep dive into Zorphy entities.
*   [**Architecture Overview**](../architecture/overview) - Understand the patterns behind the commands.
*   [**MCP Server**](../features/mcp-server) - How to use these commands via AI.
