# Caching Strategy

**Zuraffa** provides a sophisticated, offline-first caching strategy that seamlessly bridges your remote and local data sources. By using the `--cache` flag, Zuraffa generates a **Cached Repository** that handles data synchronization, persistence, and optimistic updates automatically.

---

## 🦄 How It Works

Zuraffa uses a "Cache-Aside" pattern enhanced with configurable policies:

1.  **Request**: The UI calls a UseCase (e.g., `GetProduct`).
2.  **Cache Check**: The Cached Repository checks the **Local DataSource** (Hive/SQLite).
3.  **Policy Execution**: Based on the `CachePolicy`, it either returns the cached data immediately or fetches from the **Remote DataSource**.
4.  **Sync**: New data from the remote source is automatically persisted to the local source.
5.  **Return**: The Result is returned to the UI.

---

## 🚀 Basic Usage

### 1. Generate with Caching
Enable caching for an entity with a single flag:

```bash
zfa feature Product --data --cache
```

### 2. Configure Storage
Choose your preferred local storage engine (default is **Hive**):

```bash
zfa feature Product --data --cache --cache-storage=sqlite
```

---

## 🛡️ Cache Policies

Zuraffa supports multiple policies to fit different user experiences:

| Policy | Description | Best Use Case |
| :--- | :--- | :--- |
| `CacheFirst` | Returns cached data if available, otherwise fetches remote. | Performance-critical screens. |
| `RemoteFirst` | Always tries remote first, falls back to cache on failure. | Real-time data (e.g., Prices). |
| `CacheAndSync` | Returns cache immediately, then fetches remote and updates. | Social feeds or dashboards. |
| `LocalOnly` | Only interacts with the local database. | Drafts or offline-only features. |

---

## 🛠️ The Cached Stack

When you use the `--cache` flag, Zuraffa generates:

### Local DataSource (`product_local_datasource.dart`)
Handles CRUD operations on your local database (Hive or SQLite). It includes optimized methods for:
- **Individual Fetching**: `get(id)`
- **List Fetching**: `getList()`
- **Persistence**: `save(product)` and `saveAll(products)`

### Cached Repository (`cached_product_repository.dart`)
The orchestrator that implements your Repository interface. It manages the logic between your Remote and Local DataSources based on the active `CachePolicy`.

---

## 🧠 Optimistic Updates

Zuraffa's caching system is designed for **Optimistic UI**. When you perform an update, the repository can immediately update the local cache while the remote request happens in the background. If the remote request fails, the repository handles the rollback automatically.

---

## 📂 Next Steps

*   [**Sync Strategy**](./sync) - Learn about background synchronization.
*   [**Dependency Injection**](./dependency-injection) - How the Cached stack is wired.
*   [**CLI Reference**](../cli/commands) - Master all caching flags.
