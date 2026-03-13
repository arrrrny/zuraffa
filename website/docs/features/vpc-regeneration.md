# VPC Regeneration

**Zuraffa** supports granular regeneration of your presentation layer, allowing you to evolve your business logic without losing custom UI work. By using flags like `--pc` and `--pcs`, you can target specific components for updates while preserving your carefully crafted Views.

---

## 🦄 The VPC Pattern

Zuraffa's presentation layer is built on the **View-Presenter-Controller (VPC)** pattern:

*   **View**: Pure Flutter UI code.
*   **Presenter**: Orchestrates UseCases and prepares data.
*   **Controller**: Manages user interactions and feature lifecycle.
*   **State**: The single source of truth for the UI.

---

## 🚀 Regeneration Flags

Zuraffa gives you full control over what gets updated:

| Flag | Generated Components | Best Use Case |
| :--- | :--- | :--- |
| `--vpcs` | View, Presenter, Controller, State | Initial feature scaffolding. |
| `--pcs` | Presenter, Controller, State | Adding new methods or state fields while keeping custom UI. |
| `--pc` | Presenter, Controller | Updating logic without changing the State structure. |
| `--view` | View only | Resetting or regenerating the UI layer. |

---

## 🛠️ Common Workflows

### 1. Adding New Functionality
Suppose you have a `Product` feature and want to add a `watch` capability without touching your custom UI:

```bash
zfa generate Product --methods=watch --pcs --force
```
This will:
1. Generate the `WatchProductUseCase`.
2. Add the UseCase to the `ProductPresenter`.
3. Add a `isWatching` flag and `currentProduct` stream to `ProductState`.
4. Update `ProductController` to handle the subscription.
5. **Preserve your existing `ProductView`.**

### 2. Evolving State
If you need more granular loading indicators (e.g., `isCreating`, `isUpdating`), Zuraffa can regenerate the State object and the logic to drive it:

```bash
zfa generate Product --methods=create,update --pcs --force
```

---

## 🧠 Smart Injection

When you regenerate a Presenter, Zuraffa's **AST-aware** generator doesn't just overwrite the file—it intelligently injects new UseCase dependencies into the constructor and registers them using `registerUseCase()`. This ensures that your manual customizations in other parts of the file are preserved whenever possible.

---

## 📂 Next Steps

*   [**UseCase Types**](../architecture/usecases) - Learn about the business logic driving your VPC.
*   [**CLI Reference**](../cli/commands) - Master all generation flags.
