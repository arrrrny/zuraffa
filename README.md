# 🦒 Zuraffa

[![Pub Version](https://img.shields.io/pub/v/zuraffa)](https://pub.dev/packages/zuraffa)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/badge/docs-docusaurus-blue)](https://arrrrny.github.io/zuraffa/)

**The AI-First Clean Architecture Framework for Flutter.**

Zuraffa is a comprehensive toolkit designed to streamline Flutter development by enforcing Clean Architecture principles, ensuring type safety, and integrating seamlessly with modern AI coding assistants via MCP.

---

## 🦄 Why Zuraffa?

*   **🤖 AI-Native (MCP)**: The first Flutter framework with a built-in **Model Context Protocol** server. AI agents (Trae, Cursor, Windsurf) can understand, generate, and refactor your code with 100% precision.
*   **🏗️ Clean Architecture by Default**: Strict separation of Domain, Data, and Presentation layers. No more spaghetti code.
*   **🛡️ Type-Safe Everything**: Uses `Result<T, AppFailure>` for error handling. Stop catching exceptions; start matching results.
*   **⚡ Zero Boilerplate**: The `zfa` CLI handles the heavy lifting—UseCases, Repositories, VPCs (View-Presenter-Controller), and Tests are generated in seconds.
*   **🧩 Smart Caching & Sync**: Built-in patterns for offline-first apps with configurable cache policies and automatic sync.
*   **🧪 Mock-Ready**: Instant mock data generation for rapid prototyping without a backend.

---

## 🤖 The AI Advantage (MCP)

Zuraffa exposes your project structure to AI agents through its **MCP Server**. This allows AI to:
*   **Contextual Generation**: "Add a 'PlaceOrder' usecase to the existing 'Cart' domain."
*   **Smart Refactoring**: "Rename this entity field and update all related layers."
*   **Automated Diagnostics**: AI can run `zfa doctor` and fix architectural violations automatically.

To enable, just install Zuraffa. Compatible IDEs will detect the server automatically.

---

## 📦 Installation

Add Zuraffa to your `pubspec.yaml`:

```yaml
dependencies:
  zuraffa: ^3.19.0

dev_dependencies:
  zuraffa: ^3.19.0
  build_runner: ^2.4.0
  zorphy_annotation: ^1.6.0 # Required for supercharged entities
```

Activate the CLI globally:

```bash
dart pub global activate zuraffa
```

---

## ⚡ Quick Start

### 1. Initialize
```bash
zfa init
```

### 2. Define an Entity
Zuraffa uses **Zorphy** for immutable, type-safe entities.
```bash
zfa entity create -n Product --field name:String --field price:double --field stock:int
```

### 3. Generate a Feature
Generate the full stack (Domain, Data, Presentation, Tests) in one go:
```bash
zfa feature Product --methods=get,getList,create --data --vpcs --state --test
```

### 4. Granular Control (Make)
Need just a specific part? Use `zfa make`:
```bash
zfa make Search usecase --domain=search --params=SearchRequest --returns=Listing
```

### 5. Build
```bash
zfa build
```

---

## 🛠️ CLI Power Commands

| Command | Description |
| :--- | :--- |
| `zfa feature` | High-level command to generate full feature slices. |
| `zfa make` | Low-level command for granular generation (UseCases, Mocks, DI, etc.). |
| `zfa entity` | Create and manage Zorphy entities with field validation. |
| `zfa doctor` | Lints your architecture and suggests fixes. |
| `zfa build` | Optimized wrapper for `build_runner`. |

---

## 🔄 Revert & Negation

### Smart Revert
Accidentally added a method or plugin? Use `--revert` to undo the change. Zuraffa's AST-aware reverter will remove only the specific code added, preserving your manual changes.
```bash
zfa make Product usecase --methods=watch --revert
```

### Negatable Flags
Every boolean flag has a `--no-` counterpart to explicitly disable features.
```bash
zfa feature Product --data --no-zorphy # Generate data layer but skip Zorphy
```

---

## 📂 Project Layout

```text
lib/src/
├── data/           # Models, DataSources, Repository Impls
├── domain/         # Entities, Repository Interfaces, UseCases
├── presentation/   # VPC (View, Presenter, Controller, State)
└── di/             # Automated Dependency Injection (GetIt)
```

---

## 🌐 Learn More

*   **Documentation**: [zuraffa.dev](https://arrrrny.github.io/zuraffa/)
*   **Example Project**: [Github Example](https://github.com/arrrrny/zuraffa/tree/master/example)
*   **Discord/Community**: [Join us!](https://github.com/arrrrny/zuraffa/issues)

Made with 🦒 and ⚡️ by [Arrrrny](https://github.com/arrrrny).
