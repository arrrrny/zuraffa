# V6 State Migration Guide: v5 → v6 Dual-Layer Architecture

This guide walks you through migrating from the v5 monolithic `.state.dart`
pattern to the v6 **dual-layer state architecture** — `DomainState` +
`ViewState` with fragmented `SignalSlice`s, `FragmentBuilder` for granular
rebuids, and automated cache-binding for cross-view sync.

## Why Migrate?

### The v5 Problem

In v5, a single generated `.state.dart` file holds **all** state for a
presenter — both domain data (loaded from UseCases) and transient UI state
(dropdowns, tabs, scroll position). Because `zfa build` regenerates this
file, any **manual UI state edits are wiped** on every build cycle.
Developers resort to `@preserve` blocks and workarounds, and any single
UseCase update triggers a full listener cycle across the entire presenter.

### The v6 Solution

v6 introduces a strict **dual-layer boundary**:

| Layer | Class | Ownership | Regenerated? |
|-------|-------|-----------|--------------|
| **DomainState** | `{Name}DomainState` | Auto-generated | ✅ Every `zfa build` |
| **ViewState** | `{Name}ViewState` | Developer-edited | ❌ Scaffolded once, preserved |
| **Presenter** | `{Name}Presenter extends DualLayerPresenter` | Developer-edited | ❌ Scaffolded once, preserved |

Each UseCase gets its own `SignalSlice<T>` inside `DomainState`, enabling
**O(1) granular rebuilds** — a widget listening to the `product` slice does
not rebuild when the `reviews` slice updates.

## Architecture Overview

```
┌──────────────────────────────────────────────┐
│           DualLayerPresenter                 │
│  ┌─────────────────┐  ┌─────────────────┐    │
│  │  DomainState    │  │   ViewState     │    │
│  │  (generated)    │  │  (hand-edited)  │    │
│  │                 │  │                 │    │
│  │  SignalSlice<T> │  │  Signal<T>      │    │
│  │  ─ product      │  │  ─ isLoading    │    │
│  │  ─ reviews      │  │  ─ activeTab    │    │
│  │  ─ related      │  │  ─ scrollOffset │    │
│  └────────┬────────┘  └────────┬────────┘    │
│           │                    │              │
│           ▼                    ▼              │
│     FragmentBuilder<S>   SignalBuilder<T>    │
│     (domain rebuilds)    (UI rebuilds)       │
└──────────────────────────────────────────────┘
```

## Key Concepts

### SignalSlice

A fine-grained reactive wrapper around a single UseCase's `SignalResult<T>`.
Each slice is independent — subscribing to one slice does not trigger
callbacks on other slices.

```dart
final productSlice = SignalSlice<Product>(
  useCase: getProductUseCase,
  params: GetProductParams(id: '123'),
);
productSlice.listen((product, error) { /* O(1) rebuild */ });
```

### DomainState (generated, read-only)

A sealed container of `SignalSlice`s. **Never edit manually** — it is
overwritten on every `zfa build`.

```dart
// GENERATED — do not edit
class ProductDetailDomainState extends DomainState {
  ProductDetailDomainState({required super.presenter});

  late final product = bind<Product>('product', getProductUseCase, GetProductParams());
  late final reviews = bind<List<Review>>('reviews', getReviewsUseCase, GetReviewsParams());
}
```

### ViewState (scaffolded once, preserved)

Holds transient UI state via `Signal<T>` fields. Safe to edit — the
generator **never overwrites** an existing `ViewState` file.

```dart
// SCAFFOLDED — safe to edit, never regenerated
class ProductDetailViewState extends ViewState {
  ProductDetailViewState() {
    registerSignal(isDescriptionExpanded);
    registerSignal(activeTabIndex);
  }

  final isDescriptionExpanded = Signal<bool>(false);
  final activeTabIndex = Signal<int>(0);
}
```

### FragmentBuilder & SignalBuilder

- **`FragmentBuilder<S>`** — subscribes to a single `SignalSlice<S>` and
  rebuilds only when that slice changes. Ships with `onLoading`,
  `onError`, and `onEmpty` builders.
- **`SignalBuilder<T>`** — subscribes to a pure UI `Signal<T>` from
  `ViewState` (e.g. `isEditMode`, `activeTabIndex`).

```dart
FragmentBuilder<Product>(
  slice: controller.domain.slice<Product>('product')!,
  onLoading: (context) => const ProductSkeleton(),
  onError: (context, error) => ErrorCard(error: error),
  builder: (context, product) => ProductCard(product: product),
),
SignalBuilder<bool>(
  signal: controller.view.isDescriptionExpanded,
  builder: (context, expanded) => expanded ? ExpandedView() : CollapsedView(),
),
```

### ControlledWidget

The v6 base widget with typed controller access and `onInit` / `onDispose`
lifecycle hooks.

```dart
class ProductDetailView extends ControlledWidget<ProductDetailPresenter> {
  const ProductDetailView({super.key, required super.controller});

  @override
  void onInit() => controller.domain.slice<Product>('product')?.refresh();

  @override
  Widget build(BuildContext context) { /* ... */ }
}
```

## Migration Steps

### 1. Generate v6 state for an entity

Use the `--v6-state` flag with `zfa view` or `zfa make`:

```bash
# Via zfa view
zfa view Product --v6-state --methods=get,update

# Via zfa make (view plugin auto-registers --v6-state)
zfa make Product view --v6-state --methods=get,update
```

This generates four files:

| File | Regenerated? | Purpose |
|------|--------------|---------|
| `product_domain_state.dart` | ✅ Every build | SignalSlices for domain data |
| `product_view_state.dart` | ❌ Once | Transient UI state (Signal fields) |
| `product_presenter.dart` | ❌ Once | DualLayerPresenter wiring |
| `product_view.dart` | ✅ Template | ControlledWidget + FragmentBuilder |

### 2. Migrate existing v5 state files

Use `zfa migrate state` to convert v5 monolithic `.state.dart` files to the
v6 slice pattern:

```bash
# Preview changes
zfa migrate state --dry-run

# Apply
zfa migrate state
```

The migrator:
- Detects `*Presenter` classes with `UseCase` fields
- Generates `late final` slice bindings (`bind<T>(...)`) for each UseCase
- Derives semantic slice keys from field names (strips `UseCase` suffix,
  common action prefixes like `get`/`fetch`/`load`)
- Creates a `.bak` backup when writing over the source file

### 3. Move transient UI state to ViewState

Any UI state that lived inside the v5 generated state file (dropdowns,
tabs, scroll position, form fields) must move to `ViewState`:

**Before (v5):**
```dart
// product_state.dart — wiped on every build
class ProductState {
  bool isDropdownOpen = false;  // ❌ lost on regeneration
  int activeTab = 0;            // ❌ lost on regeneration
}
```

**After (v6):**
```dart
// product_view_state.dart — preserved across builds
class ProductViewState extends ViewState {
  ProductViewState() {
    registerSignal(isDropdownOpen);
    registerSignal(activeTab);
  }
  final isDropdownOpen = Signal<bool>(false);
  final activeTab = Signal<int>(0);
}
```

### 4. Update views to use FragmentBuilder

Replace monolithic state consumption with `FragmentBuilder` + `SignalBuilder`:

**Before (v5):**
```dart
// Rebuilds the ENTIRE view on any state change
Widget build(BuildContext context) {
  final state = controller.state;
  return Column(children: [
    if (state.isLoading) CircularProgressIndicator(),
    Text(state.product?.name ?? ''),
    Text(state.reviews?.length.toString() ?? '0'),
  ]);
}
```

**After (v6):**
```dart
// Each section rebuilds independently
Widget build(BuildContext context) {
  return Column(children: [
    FragmentBuilder<Product>(
      slice: controller.domain.slice<Product>('product')!,
      onLoading: (context) => const CircularProgressIndicator(),
      builder: (context, product) => Text(product.name),
    ),
    FragmentBuilder<List<Review>>(
      slice: controller.domain.slice<List<Review>>('reviews')!,
      builder: (context, reviews) => Text('${reviews.length}'),
    ),
  ]);
}
```

### 5. Enable cache-binding (optional)

For `@Cacheable` entities, the generated `DomainState` automatically calls
`..bindCache()` on each slice. When a mutation UseCase updates the cache
(via `CacheMutator.notifyCache()`), **all** active slices for that entity
type across all views receive the update — no network re-fetch needed.

Enable globally in `.zfa.json`:
```json
{
  "state": { "cacheBinding": true }
}
```

## Backward Compatibility

v6 is **fully backward-compatible** with v5:

- Existing v5 views that consume the monolithic state object continue to
  work — `SlicePresenter.combinedState` exposes all slices as a single map.
- The `--v6-state` flag is **opt-in**; without it, the v5 generation path is
  unchanged.
- `ControlledWidget`, `FragmentBuilder`, and `SignalBuilder` are additive —
  they don't replace any existing widget classes.

## Verification Checklist

After migrating:

- [ ] `dart analyze` passes with no new issues
- [ ] `zfa build` regenerates `DomainState` but preserves `ViewState` and
      `Presenter` edits
- [ ] Updating one slice does not trigger rebuilds on widgets listening to
      other slices (use the `FragmentBuilder` golden test as a template)
- [ ] Disposed views do not receive cache updates (no memory leaks)
- [ ] Old-style views still compile without changes

## References

- **Parent Epic**: #162 — .state.dart Enhancements
- **Track 2.1**: #167 — Fragmented Signal Slices
- **Track 2.2**: #166 — Dual-Layer State Boundary
- **Track 2.3**: #169 — Automated Cache-Binding
- **Track 2.4**: #173 — ControlledWidget with FragmentBuilder
