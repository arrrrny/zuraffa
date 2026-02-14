# VPC Regeneration

Zuraffa v3 supports VPC regeneration so you can evolve logic without losing UI work. Use `--pc`, `--pcs`, `--vpc`, and `--vpcs` to control the scope.

## Overview

VPC regeneration enables you to:

1. **Evolve business logic** without losing custom UI
2. **Add new methods** to existing UseCases
3. **Update state management** without UI changes
4. **Preserve custom styling** and layouts

## VPC Generation Flags

### Complete Generation (`--vpc`)

Generates View + Presenter + Controller:

```bash
zfa generate Product --methods=get,getList --vpc
```

### Complete Generation with State (`--vpcs`)

Generates View + Presenter + Controller + State:

```bash
zfa generate Product --methods=get,getList --vpcs
```

### Controller + Presenter Only (`--pc`)

Generates Presenter + Controller, preserves existing View:

```bash
zfa generate Product --methods=get,getList --pc
```

### Controller + Presenter + State (`--pcs`)

Generates Presenter + Controller + State, preserves existing View:

```bash
zfa generate Product --methods=get,getList --pcs
```

## Use Cases for VPC Regeneration

### 1. Adding New Methods

Add new operations to existing entities:

```bash
# Initial generation
zfa generate Product --methods=get,getList --vpcs

# Later: Add create/update methods without affecting UI
zfa generate Product --methods=create,update --pc --force
```

### 2. Evolving State Management

Update state without touching custom UI:

```bash
# Add new loading states
zfa generate Product --methods=watch,watchList --pcs --force
```

### 3. Preserving Custom UI

Regenerate business logic while keeping custom View:

```bash
# Your custom View remains untouched
zfa generate Product --methods=get,getList,create --pc --force
```

## Generated Architecture

### Controller Regeneration

When regenerating with `--pc` or `--pcs`, the Controller is updated:

```dart
// lib/src/presentation/pages/product/product_controller.dart
class ProductController extends Controller with StatefulController<ProductState> {
  final ProductPresenter _presenter;

  ProductController(this._presenter) : super();

  @override
  ProductState createInitialState() => const ProductState();

  Future<void> loadProduct(String id) async {
    updateState(viewState.copyWith(isGetting: true));

    final result = await _presenter.getProduct(id);

    result.fold(
      (product) => updateState(viewState.copyWith(
        isGetting: false,
        currentProduct: product,
      )),
      (failure) => updateState(viewState.copyWith(
        isGetting: false,
        error: failure,
      )),
    );
  }

  // NEW: If adding watch method
  StreamSubscription<Result<Product, AppFailure>>? _watchSubscription;

  Future<void> startWatchingProduct(String id) async {
    _watchSubscription?.cancel();
    
    updateState(viewState.copyWith(isWatching: true));

    _watchSubscription = _presenter.watchProduct(id).listen(
      (result) {
        result.fold(
          (product) => updateState(viewState.copyWith(
            currentProduct: product,
            isWatching: false,
          )),
          (failure) => updateState(viewState.copyWith(
            error: failure,
            isWatching: false,
          )),
        );
      },
    );
  }

  @override
  void onDisposed() {
    _watchSubscription?.cancel();
    _presenter.dispose();
    super.onDisposed();
  }
}
```

### Presenter Regeneration

Presenter is updated with new UseCase injections:

```dart
// lib/src/presentation/pages/product/product_presenter.dart
class ProductPresenter extends Presenter {
  final ProductRepository productRepository;

  late final GetProductUseCase _getProduct;
  late final GetProductListUseCase _getProductList;
  // NEW: Added when watch method is added
  late final WatchProductUseCase _watchProduct;

  ProductPresenter({required this.productRepository}) {
    _getProduct = registerUseCase(GetProductUseCase(productRepository));
    _getProductList = registerUseCase(GetProductListUseCase(productRepository));
    // NEW: Registration for watch method
    _watchProduct = registerUseCase(WatchProductUseCase(productRepository));
  }

  Future<Result<Product, AppFailure>> getProduct(String id) {
    return _getProduct.call(id);
  }

  Future<Result<List<Product>, AppFailure>> getProductList() {
    return _getProductList.call(const NoParams());
  }

  // NEW: Method for watch functionality
  Stream<Result<Product, AppFailure>> watchProduct(String id) {
    return _watchProduct.call(id);
  }
}
```

### State Regeneration

When using `--pcs` or `--vpcs`, state is regenerated with new fields:

```dart
// lib/src/presentation/pages/product/product_state.dart
@immutable
class ProductState {
  final bool isGetting;
  final bool isGettingList;
  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  final bool isLoading; // Overall loading state
  final Product? currentProduct;
  final List<Product> productList;
  final AppFailure? error;
  // NEW: Added when watch method is added
  final bool isWatching;

  const ProductState({
    this.isGetting = false,
    this.isGettingList = false,
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    this.isWatching = false, // NEW: Added
    this.currentProduct,
    this.productList = const [],
    this.error,
  });

  ProductState copyWith({
    bool? isGetting,
    bool? isGettingList,
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    bool? isWatching, // NEW: Added
    Product? currentProduct,
    List<Product>? productList,
    AppFailure? error,
  }) {
    return ProductState(
      isGetting: isGetting ?? this.isGetting,
      isGettingList: isGettingList ?? this.isGettingList,
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      isWatching: isWatching ?? this.isWatching, // NEW: Added
      currentProduct: currentProduct ?? this.currentProduct,
      productList: productList ?? this.productList,
      error: error ?? this.error,
    );
  }

  bool get isLoading =>
      isGetting || isGettingList || isCreating || isUpdating || isDeleting || isWatching; // NEW: Added
}
```

## ZFA Patterns and VPC Regeneration

### Entity-Based Pattern

Perfect for evolving entity-based features:

```bash
# Start with basic CRUD
zfa generate Product --methods=get,getList --vpcs

# Add real-time features
zfa generate Product --methods=watch,watchList --pcs --force

# Add create/update/delete
zfa generate Product --methods=create,update,delete --pcs --force
```

### Single Repository Pattern

Regenerate custom UseCase business logic:

```bash
# Initial generation
zfa generate ProcessCheckout --domain=checkout --repo=Checkout --vpc

# Add new functionality
zfa generate ProcessCheckout --domain=checkout --repo=Checkout --params=NewParams --returns=NewResult --pc --force
```

### Orchestrator Pattern

Update orchestrated workflows:

```bash
# Add new composed UseCases
zfa generate ProcessCheckout --usecases=ValidateCart,CreateOrder,ProcessPayment,SendNotification --pc --force
```

## Advanced VPC Regeneration

### Using `--force` with VPC

Always use `--force` when regenerating VPC components:

```bash
# Add new methods to existing VPC
zfa generate Product --methods=watch --pc --force

# Update state with new loading indicators
zfa generate Product --methods=watch --pcs --force
```

### Combining with Other Features

```bash
# Add caching to existing VPC
zfa generate Product --methods=get,getList --pcs --cache --force

# Add testing to existing VPC
zfa generate Product --methods=get,getList --pcs --test --force

# Add DI to existing VPC
zfa generate Product --methods=get,getList --pcs --di --force
```

### Preserving Custom Views

The `--pc` and `--pcs` flags are ideal for preserving custom UI:

```bash
# Your custom View with complex layouts remains untouched
zfa generate Product --methods=get,getList,create,update --pc --force

# Only regenerate business logic layers
```

## Best Practices

### 1. Progressive Enhancement

Start simple and add complexity gradually:

```bash
# Start with basic operations
zfa generate Product --methods=get,getList --vpcs

# Add more operations as needed
zfa generate Product --methods=watch,watchList --pcs --force

# Add advanced features
zfa generate Product --methods=create,update,delete --pcs --force
```

### 2. Preserve Custom UI

Use `--pc` or `--pcs` to preserve custom Views:

```bash
# Custom View with complex layout
zfa generate Product --methods=get,getList --vpc  # Initial generation

# Add new features without touching UI
zfa generate Product --methods=watch --pcs --force  # Regenerates only business logic
```

### 3. State Evolution

Use `--pcs` when adding new state requirements:

```bash
# Add new loading states
zfa generate Product --methods=streamOperation --pcs --force

# New error handling
zfa generate Product --methods=complexOperation --pcs --force
```

### 4. Domain-Specific Regeneration

Work within domain boundaries:

```bash
# Regenerate within checkout domain
zfa generate ProcessCheckout --domain=checkout --pc --force

# Add to search domain
zfa generate SearchProduct --domain=search --pcs --force
```

## Migration from 1.x

### Before (1.x)
```bash
# Regeneration affected all layers
zfa generate Product --methods=get,create --vpc --force
```

### After (ZFA)
```bash
# Granular regeneration preserves custom UI
zfa generate Product --methods=get,create --pc --force  # Preserves View

# Domain organization
zfa generate ProcessCheckout --domain=checkout --pc --force
```

## Troubleshooting

### View Preservation Issues

If your custom View is being overwritten:
- Use `--pc` or `--pcs` instead of `--vpc` or `--vpcs`
- Ensure you're not accidentally regenerating the View layer

### State Inconsistencies

If getting state errors after regeneration:
- Use `--pcs` to regenerate state along with controller/presenter
- Check that new state fields are properly initialized

### Missing Methods

If new UseCase methods aren't appearing in regenerated code:
- Ensure you're using `--force` flag
- Check that the UseCase files exist and contain the new methods

## Next Steps

- [UseCase Types](../architecture/usecases) - Detailed VPC architecture and patterns
- [State Management](../architecture/usecases) - State management patterns
- [CLI Reference](../cli/commands) - Complete VPC regeneration flags
