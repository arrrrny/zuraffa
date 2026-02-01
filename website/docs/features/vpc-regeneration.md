---
sidebar_position: 2
title: VPC Regeneration
---

# Granular VPC Regeneration

Zuraffa allows you to regenerate business logic (Presenter/Controller) without overwriting your custom UI code.

## The Problem

When you customize your View (UI), running `--vpc` again would overwrite your changes:

```bash
# ❌ This overwrites your custom View
zfa generate Product --methods=get,getList --vpc --force
```

## The Solution

Use `--pc` or `--pcs` to regenerate only the business logic layer:

```bash
# ✅ Regenerate Presenter + Controller only
zfa generate Product --methods=get,getList --pc --force

# ✅ Regenerate Presenter + Controller + State
zfa generate Product --methods=get,getList --pcs --force
```

## Available Flags

| Flag | Generates | Use When |
|------|-----------|----------|
| `--vpc` | View + Presenter + Controller | Initial generation or full regeneration |
| `--pc` | Presenter + Controller | You have custom View, need to update business logic |
| `--pcs` | Presenter + Controller + State | You have custom View, need to update business logic and state |
| `--state` | State only | You only need to regenerate state class |

## Common Workflows

### Initial Generation

Start with full VPC generation:

```bash
zfa generate Product --methods=get,getList,create --repository --data --vpc --state --di
```

This generates:
- ✅ `product_view.dart` - UI layer
- ✅ `product_presenter.dart` - Business logic orchestration
- ✅ `product_controller.dart` - State management
- ✅ `product_state.dart` - Immutable state

### Customize the View

Edit `product_view.dart` to match your design:

```dart
class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  _ProductViewState(super.controller);

  @override
  Widget get view {
    return Scaffold(
      key: globalKey,
      appBar: AppBar(
        title: const Text('My Custom Products'),
        // Your custom app bar
      ),
      body: ControlledWidgetBuilder<ProductController>(
        builder: (context, controller) {
          // Your custom UI
          return CustomProductList(
            products: controller.viewState.productList,
            onTap: (product) => _showDetails(product),
          );
        },
      ),
    );
  }
  
  void _showDetails(Product product) {
    // Your custom navigation
  }
}
```

### Add New Methods

When you need to add new methods (e.g., `update`, `delete`), regenerate only the business logic:

```bash
# Add update and delete methods without touching your custom View
zfa generate Product --methods=get,getList,create,update,delete --pcs --force
```

This updates:
- ✅ `product_presenter.dart` - Adds new UseCase calls
- ✅ `product_controller.dart` - Adds new state management methods
- ✅ `product_state.dart` - Adds new loading flags
- ❌ `product_view.dart` - **NOT TOUCHED** - Your custom UI is safe!

### Update State Structure

If you only need to regenerate the state class:

```bash
zfa generate Product --methods=get,getList,create,update,delete --state --force
```

## Example: Iterative Development

### Step 1: Initial Generation

```bash
zfa generate Product --methods=get,getList --repository --data --vpc --state --di
```

### Step 2: Customize View

```dart
// product_view.dart - Add custom UI
class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  @override
  Widget get view {
    return Scaffold(
      key: globalKey,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Products'),
            // Custom app bar
          ),
          ControlledWidgetBuilder<ProductController>(
            builder: (context, controller) {
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = controller.viewState.productList[index];
                    return CustomProductCard(product: product);
                  },
                  childCount: controller.viewState.productList.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### Step 3: Add Create Method

```bash
# Add create method - View stays untouched
zfa generate Product --methods=get,getList,create --pcs --force
```

### Step 4: Use New Method in View

```dart
// product_view.dart - Add FAB to use new create method
class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  @override
  Widget get view {
    return Scaffold(
      key: globalKey,
      body: /* your custom UI */,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(),
        child: Icon(Icons.add),
      ),
    );
  }
  
  void _showCreateDialog() {
    // Show dialog and call controller.createProduct()
  }
}
```

### Step 5: Add Update and Delete

```bash
# Add more methods - View still safe
zfa generate Product --methods=get,getList,create,update,delete --pcs --force
```

## Best Practices

### 1. Always Use `--force` with `--pc`/`--pcs`

Since you're intentionally regenerating, use `--force` to overwrite:

```bash
zfa generate Product --methods=get,getList,create --pcs --force
```

### 2. Commit Before Regenerating

Always commit your custom View before regenerating:

```bash
git add lib/src/presentation/pages/product/product_view.dart
git commit -m "feat: custom product view UI"

# Now safe to regenerate
zfa generate Product --methods=get,getList,create --pcs --force
```

### 3. Use Version Control

Keep your View in version control so you can always revert if needed:

```bash
# Check what changed
git diff lib/src/presentation/pages/product/

# Revert if needed
git checkout lib/src/presentation/pages/product/product_view.dart
```

### 4. Separate UI and Logic

Keep your View focused on UI only. All business logic should be in the Controller:

```dart
// ❌ Bad: Business logic in View
class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  void _handleCreate() {
    if (nameController.text.isEmpty) {
      // validation logic
    }
    final product = Product(name: nameController.text);
    controller.createProduct(product);
  }
}

// ✅ Good: Business logic in Controller
class ProductController extends Controller {
  Future<void> createProduct(String name) async {
    if (name.isEmpty) {
      updateState(viewState.copyWith(error: ValidationFailure('Name required')));
      return;
    }
    // ... rest of logic
  }
}

class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  void _handleCreate() {
    controller.createProduct(nameController.text);
  }
}
```

## Troubleshooting

### View Was Overwritten

If you accidentally used `--vpc` instead of `--pc`:

```bash
# Revert the View
git checkout lib/src/presentation/pages/product/product_view.dart

# Use correct flag
zfa generate Product --methods=get,getList,create --pc --force
```

### State Not Updated

If you used `--pc` but need state changes, use `--pcs`:

```bash
zfa generate Product --methods=get,getList,create,update,delete --pcs --force
```

### Controller Methods Missing

Ensure you include all methods you need:

```bash
# Include all methods you want in the controller
zfa generate Product --methods=get,getList,create,update,delete,watch,watchList --pcs --force
```
