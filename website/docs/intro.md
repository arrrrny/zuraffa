# 🦒 Welcome to Zuraffa

**The AI-First Clean Architecture Framework for Flutter.**

Zuraffa is a comprehensive toolkit designed to bridge the gap between human intent and production-ready code. It enforces **Clean Architecture** principles, ensures **Type Safety**, and provides an **AI-Native** workflow through its built-in Model Context Protocol (MCP) server.

---

## 🦄 Why Zuraffa?

*   **🤖 AI-Native (MCP)**: The first Flutter framework with a built-in **Model Context Protocol** server. Your AI agent (Trae, Cursor, Windsurf) can now understand, generate, and refactor your code with 100% precision.
*   **🏗️ Clean Architecture by Default**: Strict separation of Domain, Data, and Presentation layers. No more spaghetti code.
*   **🛡️ Type-Safe Everything**: Uses `Result<T, AppFailure>` for error handling. Stop catching exceptions; start matching results.
*   **⚡ Zero Boilerplate**: The `zfa` CLI handles the heavy lifting—UseCases, Repositories, VPCs (View-Presenter-Controller), and Tests are generated in seconds.
*   **🧪 Mock-Ready**: Instant mock data generation for rapid prototyping without a backend.

---

## 🤖 The AI Advantage

Zuraffa is built for the era of AI-assisted development. By exposing your project's architectural structure to AI agents, Zuraffa enables a higher level of autonomy and accuracy:

1.  **Contextual Generation**: "Add a 'PlaceOrder' usecase to the existing 'Cart' domain."
2.  **Smart Refactoring**: "Rename this entity field and update all related layers."
3.  **Automated Alignment**: AI can run `zfa doctor` to identify and fix architectural violations automatically.

---

## ⚡ Quick Start

### 1. Install

```yaml
dev_dependencies:
  zuraffa: ^3.19.0
```

```bash
dart pub global activate zuraffa
zfa init
```

### 2. Define an Entity
Zuraffa uses **Zorphy** for immutable, type-safe entities.
```bash
zfa entity create -n Product --field name:String --field price:double
```

### 3. Generate a Feature
Generate the full stack (Domain, Data, Presentation, Tests) in one go:
```bash
zfa feature Product --methods=get,getList,create --data --vpcs --state --test
```

### 4. Modular Generation (Make)
Need just a specific part? Use `zfa make` to run one or more plugins:
```bash
zfa make Search usecase data di --domain=search --params=SearchRequest --returns=Listing
```

### 5. Build
```bash
zfa build
```

---

## 🏗️ Core Patterns

### Entity-Based CRUD
```bash
zfa feature Product --methods=get,getList,create,update,delete --data --vpcs
```

### Custom UseCase with a Repository
```bash
zfa make ProcessCheckout usecase data --domain=checkout --repo=Checkout --params=CheckoutRequest --returns=OrderConfirmation
```

### Orchestrator UseCase
```bash
zfa make ProcessCheckout usecase --domain=checkout --usecases=ValidateCart,CreateOrder,ProcessPayment --params=CheckoutRequest --returns=Order
```

---

## 📂 Where to Go Next?

*   [**Architecture Overview**](./architecture/overview) - Learn about the VPC pattern and Result type.
*   [**MCP Server**](./features/mcp-server) - Set up Zuraffa for your AI agent.
*   [**CLI Reference**](./cli/commands) - Master the `zfa` command line.
*   [**Entities**](./entities/intro) - Supercharge your data models with Zorphy.
