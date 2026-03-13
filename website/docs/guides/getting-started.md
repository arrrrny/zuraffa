# Getting Started

Welcome to **Zuraffa**, the AI-first framework for Flutter. This guide will walk you through setting up your project and generating your first feature in minutes.

---

## 📦 Installation

Add Zuraffa to your `pubspec.yaml`:

```yaml
dev_dependencies:
  zuraffa: ^3.19.0
```

Activate the CLI globally:

```bash
dart pub global activate zuraffa
```

---

## ⚡ Quick Start

### 1. Initialize Zuraffa
Run this in your project root to set up the configuration:

```bash
zfa init
```

### 2. Create an Entity
Zuraffa uses **Zorphy** for immutable, type-safe entities. Let's create a `Product`:

```bash
zfa entity create -n Product \
  --field name:String \
  --field price:double \
  --field description:String?
```

### 3. Generate the Feature
Now, generate the entire Clean Architecture stack for this entity:

```bash
zfa generate Product --methods=get,getList,create,update,delete --data --vpcs --state --test
```

### 4. Build Code
Run the build runner to generate JSON serialization and entity boilerplate:

```bash
zfa build
```

---

## 🏗️ What Was Generated?

Zuraffa just created a complete, production-ready feature slice:

*   **Domain Layer**: Entities, Repository Interfaces, and 5 UseCases (`GetProduct`, `CreateProduct`, etc.).
*   **Data Layer**: `DataProductRepository` implementation and both Remote and Local DataSources.
*   **Presentation Layer**: A full VPC stack (`ProductView`, `ProductPresenter`, `ProductController`, and `ProductState`).
*   **Infrastructure**: Automated Dependency Injection (GetIt) and Unit Tests.

---

## 🤖 Using with AI

If you are using an AI agent like **Trae**, **Cursor**, or **Windsurf**, Zuraffa's built-in **MCP Server** allows the agent to understand your project structure automatically. Just ask:

> "Add a 'stock' field to the Product entity and update the UI to show it."

---

## 📂 Next Steps

*   [**Architecture Overview**](../architecture/overview) - Deep dive into the VPC pattern.
*   [**MCP Server**](../features/mcp-server) - Enable AI-native development.
*   [**CLI Reference**](../cli/commands) - Master the `zfa` command.
