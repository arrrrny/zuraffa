# 🦒 Zuraffa

[![Pub Version](https://img.shields.io/pub/v/zuraffa)](https://pub.dev/packages/zuraffa)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/badge/docs-docusaurus-blue)](https://arrrrny.github.io/zuraffa/)

**The AI-First Clean Architecture Framework for Flutter.**

Zuraffa (Zürafa means Giraffe in Türkçe) is a comprehensive toolkit designed to streamline Flutter development by enforcing Clean Architecture principles, ensuring type safety, and integrating seamlessly with modern AI coding assistants.

## 🚀 Why Zuraffa?

- **🤖 AI-Ready**: Built-in Model Context Protocol (MCP) server allows AI agents (Trae, Cursor, Windsurf) to understand and manipulate your project structure directly.
- **🏗️ Clean Architecture**: Enforced separation of concerns with Domain, Data, and Presentation layers.
- **🛡️ Type-Safe**: Say goodbye to `try-catch` blocks. Uses `Result<T, AppFailure>` for robust error handling.
- **⚡ High Performance**: Fine-grained rebuilds, efficient state management, and optimized asset handling.
- **🧩 Modular**: Plugin-based architecture allows you to generate exactly what you need—from full features to single UseCases.
- **📦 Zero Boilerplate**: The powerful `zfa` CLI handles all the repetitive setup, letting you focus on business logic.

---

## 🤖 AI Integration (MCP)

Zuraffa is the first Flutter framework designed with AI agents in mind. It includes a built-in **MCP Server** that exposes your project's structure and generation capabilities to compatible IDEs.

### What can the AI do?
- **Analyze Project**: Understand your existing entities, use cases, and configuration.
- **Create Entities**: Define new domain models directly from natural language descriptions.
- **Generate Features**: Scaffold entire features (Repository, UseCase, UI, Tests) with a single prompt.
- **Diagnose Issues**: Run `zfa doctor` checks to identify potential problems.

To use these features, simply install Zuraffa globally or as a dev dependency. Your AI-enabled editor will automatically detect the MCP server.

---

## 📦 Installation

Add Zuraffa to your `pubspec.yaml`:

```yaml
dependencies:
  zuraffa: ^3.17.0

dev_dependencies:
  zuraffa: ^3.17.0
  build_runner: ^2.4.0
  zorphy_annotation: ^1.6.0 # Required for entity generation
```

Activate the CLI globally for easier access:

```bash
dart pub global activate zuraffa
```

---

## ⚡ Quick Start

### 1. Initialize Project
Set up the Zuraffa configuration in your project root:

```bash
zfa init
```

### 2. Create an Entity
Define your domain model first. Zuraffa uses **Zorphy** for immutable, supercharged entities.

```bash
# Create a User entity
zfa entity create -n User --field name:String --field email:String?

# Create an Order entity with a relationship
zfa entity create -n Order --field id:String --field user:$User --field total:double
```

### 3. Generate Feature
Generate the entire Clean Architecture stack for your entity in one command:

```bash
# Generate everything: Data, Domain, Presentation (VPC), State, and Tests
zfa generate Order --methods=get,create,update --data --vpcs --state --test
```

### 4. Build Code
Run the build runner to generate JSON serialization and entity boilerplate:

```bash
zfa build
```

---

## 🏗️ Architecture Overview

Zuraffa enforces a strict separation of concerns:

### 1. Domain Layer (Pure Dart)
- **Entities**: Immutable data models (e.g., `User`, `Order`).
- **Repositories (Interfaces)**: Contracts for data operations (e.g., `UserRepository`).
- **UseCases**: Single-responsibility business logic units (e.g., `CreateOrderUseCase`).

### 2. Data Layer
- **DataSources**: Remote (API) and Local (DB/Cache) data providers.
- **Repositories (Implementations)**: Orchestrates data sources to fulfill domain contracts.

### 3. Presentation Layer (VPC)
- **View**: The UI widget (Stateless/Stateful).
- **Presenter**: Prepares data for the View.
- **Controller**: Handles user input and executes UseCases.
- **State**: Represents the current state of the View.

---

## 🛠️ CLI Reference

The `zfa` CLI is your power tool for development.

| Command | Description |
|---------|-------------|
| `zfa init` | Initialize Zuraffa in the current project. |
| `zfa config` | View or modify global/project configuration. |
| `zfa doctor` | Check for common issues and misconfigurations. |
| `zfa entity` | Create, list, and manage domain entities. |
| `zfa generate <Name>` | Generate code for a feature (Alias: `zfa g`). |
| `zfa build` | Run `build_runner` to generate code. |
| `zfa make <Plugin>` | Run a specific generator plugin directly. |

### Generation Flags

Customize `zfa generate` with these flags:

- `--data`: Generate Data Layer (Repository Impl + DataSources).
- `--vpcs`: Generate View-Presenter-Controller.
- `--state`: Generate State class.
- `--test`: Generate Unit Tests.
- `--mock`: Generate Mock DataSources.
- `--remote / --no-remote`: Control Remote DataSource generation.
- `--local / --no-local`: Control Local DataSource generation.

---

## 📂 Project Structure

A typical Zuraffa project looks like this:

```
lib/
├── src/
│   ├── data/
│   │   ├── datasources/       # Remote and Local DataSources
│   │   ├── models/            # DTOs (Data Transfer Objects)
│   │   └── repositories/      # Repository Implementations
│   ├── domain/
│   │   ├── entities/          # Zorphy Entities
│   │   ├── repositories/      # Repository Interfaces
│   │   └── usecases/          # Business Logic
│   └── presentation/
│       └── views/             # UI Features (View + Controller + State)
├── main.dart
└── zuraffa.yaml               # Project Configuration
```


Made with ⚡️ by [Arrrrny](https://github.com/arrrrny) & the Zuraffa Community.
