# 🗺️ Zuraffa Roadmap

**The Path to AI-First State Management**

> "The only state management framework built by AI, for AI agents." 🦒

---

## 🎯 Vision

Zuraffa will become the **definitive state management solution for AI-first Flutter applications**. By combining:

1. **Zero Dependencies** - Own the entire stack from JSON → State → UI
2. **Morphy Integration** - Better than Freezed, built for ZikZak AI
3. **TDD by Default** - 100% test coverage, every time
4. **@zuraffa Annotation** - Riverpod-level DX with zero external deps
5. **AI-Native** - Claude generates perfect code, developers write intent

---

## 📍 Current Status: v0.3.0 ✅

**Release Date:** November 2025

### What We Have

- ✅ Full Clean Architecture code generation
- ✅ Entity generation with zikzak_morphy
- ✅ DataSource pattern (Remote/Local/Mock)
- ✅ Repository with cache-first logic
- ✅ UseCase generation (Get/GetProducts/CRUD)
- ✅ **TDD First: 100% test coverage by default**
- ✅ Filter support for GetProducts
- ✅ Dynamic package name detection
- ✅ Read-only by default, `--crud` flag for full CRUD

### CLI Commands

```bash
# Full-stack generation
zuraffa generate Product --from-json product.json

# With CRUD
zuraffa generate Product --from-json product.json --crud

# Entity only
zuraffa create entity Product --from-json product.json
```

### Generated Output

**19 files per entity:**
- 1 Entity + .g.dart (Morphy)
- 4 DataSources (interface + remote + local + mock)
- 2 Repositories (interface + impl)
- 3 UseCases (Get + GetProducts + Filter)
- 9 Test files (100% coverage!)

**All tests pass on first generation!** ✅

---

## 🚧 Next Up: v0.4.0 - @zuraffa Providers

**ETA:** Q1 2026
**Status:** Planning

### Goal: Riverpod-like DX, Zero Dependencies

Introduce the `@zuraffa` annotation for reactive state management without adding external dependencies.

### What We'll Add

#### 1. @zuraffa Annotation

```dart
@zuraffa
Future<Result<Product, AppFailure>> getProduct(ZuraffaRef ref, String id) async {
  final repo = ref.read(productRepositoryProvider);
  return await repo.getById(id);
}
```

**AI generates:**
```dart
final getProductProvider = ZuraffaProvider<Result<Product, AppFailure>, String>(
  (ref, id) async {
    final repo = ref.read(productRepositoryProvider);
    return await repo.getById(id);
  },
);
```

#### 2. ZuraffaWidget

```dart
class ProductPage extends ZuraffaWidget {
  final String productId;

  @override
  Widget build(BuildContext context, ZuraffaRef ref) {
    final productResult = ref.watch(getProductProvider(productId));

    return productResult.fold(
      onSuccess: (product) => Text(product.name),
      onError: (failure) => Text('Error: ${failure.message}'),
      onLoading: () => CircularProgressIndicator(),
    );
  }
}
```

#### 3. Minimal Runtime Package

```dart
// lib/zuraffa.dart - The ENTIRE public API (~200 lines)

abstract class ZuraffaWidget extends StatelessWidget {
  Widget build(BuildContext context, ZuraffaRef ref);
}

abstract class ZuraffaRef {
  T read<T>(ProviderBase<T> provider);
  T watch<T>(ProviderBase<T> provider);
}

sealed class Result<S, F> {  // Already exists!
  T fold<T>({
    required T Function(S) onSuccess,
    required T Function(F) onError,
    T Function()? onLoading,
  });
}
```

#### 4. Code Generation

**CLI generates:**
- Provider definitions
- State classes with @morphy
- ZuraffaWidget boilerplate
- **Tests for all providers** (TDD!)

### Features

#### 1. State Notifiers with Lifecycle Safety

```dart
@zuraffa
class TodoListNotifier extends ZuraffaNotifier<List<Todo>> {
  @override
  List<Todo> build() => [];

  Future<void> addTodo(String title) async {
    // Post the new todo to the server
    final newTodo = await api.addTodo(title);

    // Check if the provider is still mounted
    // after the async operation
    if (!ref.mounted) return;

    // If it is, update the state
    state = [...state, newTodo];
  }

  void removeTodo(String id) {
    state = state.where((todo) => todo.id != id).toList();
  }
}
```

**Why ref.mounted matters:**
- Prevents updating disposed providers
- Avoids memory leaks from async operations
- Safer than manual lifecycle management

#### 2. Automatic Retry Logic

**Per-Provider Configuration:**

```dart
// Define custom retry strategy
Duration retry(int retryCount, Object error) {
  if (error is SomeSpecificError) return null; // Don't retry
  if (retryCount > 5) return null;              // Max 5 retries

  return Duration(seconds: retryCount * 2);     // Exponential backoff
}

@Zuraffa(retry: retry)
Future<Result<Product, AppFailure>> getProduct(String id) async {
  // Automatically retries on failure!
  final product = await _repository.getById(id);
  return Success(product);
}
```

**Global Retry Configuration:**

```dart
void main() {
  runApp(
    ZuraffaScope(
      // Global retry configuration
      retry: (retryCount, error) {
        if (error is NetworkFailure) return Duration(seconds: retryCount * 2);
        if (error is ServerFailure && retryCount > 3) return null;
        return Duration(seconds: 1);
      },
      child: MyApp(),
    ),
  );
}
```

#### 3. ZuraffaScope & Container

```dart
// Root of your app
void main() {
  runApp(
    ZuraffaScope(
      // Global configuration
      retry: defaultRetryStrategy,
      observers: [LoggingObserver()],
      overrides: [
        // Override for testing
        productRepositoryProvider.overrideWith(mockRepository),
      ],
      child: MyApp(),
    ),
  );
}

// Access the container anywhere
final container = ZuraffaScope.containerOf(context);
final product = container.read(getProductProvider('id'));
```

#### 4. Core Features Summary

- **Zero external dependencies** (no riverpod, no provider, no bloc)
- **Automatic rebuilds** with ref.watch()
- **Provider composition** (providers can watch other providers)
- **Loading/Error states** built into Result<T, F>
- **Lifecycle safety** with ref.mounted checks
- **Automatic retries** with exponential backoff
- **Global configuration** via ZuraffaScope
- **100% test coverage** for all generated providers
- **Morphy-powered state classes** (not Freezed!)

### Migration Path

```dart
// v0.3.0 (Current) - Manual setState
class ProductPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    // Manual state management
  }
}

// v0.4.0 - Auto-generated @zuraffa providers
class ProductPage extends ZuraffaWidget {
  @override
  Widget build(BuildContext context, ZuraffaRef ref) {
    // Automatic reactivity!
    final product = ref.watch(getProductProvider(id));
  }
}
```

---

## 🎯 Future: v0.5.0 - Advanced State Management

**ETA:** Q2 2026

### Features

#### 1. State Notifiers

```dart
@zuraffa
class CartNotifier extends ZuraffaNotifier<CartState> {
  @override
  CartState build() => CartState.initial();

  void addProduct(Product product) {
    state = state.copyWith(items: [...state.items, product]);
  }
}
```

#### 2. Async Providers with Caching

```dart
@zuraffa(cache: Duration(hours: 24))
Future<Result<Product, AppFailure>> getProduct(String id) async {
  // Zuraffa automatically:
  // 1. Checks memory cache
  // 2. Checks disk cache (if persistOffline: true)
  // 3. Fetches from network
  // 4. Updates all caches
}
```

#### 3. Provider Families

```dart
@zuraffa
Future<Result<Product, AppFailure>> getProduct(String id) {
  // Automatically becomes a family
  // ref.watch(getProductProvider('product-123'))
}
```

#### 4. Stream Providers

```dart
@zuraffa
Stream<Result<Message, AppFailure>> watchMessages(String chatId) async* {
  // Real-time updates
  yield* _repository.messageStream(chatId);
}
```

---

## 🌟 Vision: v1.0.0 - AI-Native State Management

**ETA:** Q3 2026
**Status:** The Dream

### The Ultimate Goal

**Zuraffa becomes the first state management framework where AI (Claude) is a first-class citizen.**

#### 1. AI Code Suggestions

```bash
$ zuraffa generate Product --from-json product.json

🤖 AI: I noticed you have an AuthRepository. Should I:
   1. Add authentication checks to ProductRepository?
   2. Generate a permission-based ProductFilter?
   3. Create a GetMyProductsUseCase for user-specific products?

Your choice (1-3 or 'n' for none):
```

#### 2. AI Code Review

```bash
$ zuraffa review lib/domain/usecases/checkout_usecase.dart

🤖 AI: Analyzing CheckoutUseCase...

   ✅ Follows Clean Architecture
   ✅ Has 98% test coverage
   ⚠️  Suggestion: Split into smaller usecases:
      - ValidateCartUseCase
      - ProcessPaymentUseCase
      - CreateOrderUseCase
      - CheckoutOrchestratorUseCase

   Apply suggestions? (y/n)
```

#### 3. AI Refactoring

```bash
$ zuraffa refactor "add offline support to Product feature"

🤖 AI: I'll add offline support by:
   1. Generating OfflineProductRepository with local-first logic
   2. Adding sync queue for pending operations
   3. Generating tests for offline scenarios
   4. Adding connectivity monitoring

   Proceed? (y/n)
```

#### 4. AI Test Generation

```bash
$ zuraffa test generate lib/domain/usecases/checkout_usecase.dart

🤖 AI: Analyzing dependencies...
   - CartRepository (3 methods)
   - PaymentRepository (2 methods)
   - OrderRepository (4 methods)

   Generating 47 test cases:
   ✓ Happy path scenarios (12)
   ✓ Error scenarios (18)
   ✓ Edge cases (11)
   ✓ Integration tests (6)

   Coverage: 98%
```

#### 5. AI Architecture Analysis

```bash
$ zuraffa analyze

🤖 AI: Analyzing your architecture...

   📊 Statistics:
   - 24 entities
   - 18 repositories
   - 67 usecases
   - 100% test coverage ✅

   🎯 Suggestions:
   1. ProductRepository and OrderRepository have similar code
      → Generate shared CrudRepository<T> base class?
   2. 8 usecases have duplicate validation logic
      → Extract ValidationUseCase?
   3. CartState and CheckoutState could share fields
      → Generate shared OrderState parent?

   Apply all? (y/n)
```

### Advanced Features

#### 1. Offline-First by Default

```dart
@zuraffa(offline: OfflineStrategy.cacheFirst)
Future<Result<Product, AppFailure>> getProduct(String id) {
  // Zuraffa handles:
  // - Connectivity checks
  // - Local caching
  // - Sync queues
  // - Conflict resolution
}
```

#### 2. Real-Time Sync

```dart
@zuraffa(realtime: true)
class CartNotifier extends ZuraffaNotifier<CartState> {
  // Auto-syncs with backend via WebSocket
  // Handles concurrent modifications
  // Conflict resolution with CRDTs
}
```

#### 3. AI-Powered Performance

```dart
@zuraffa(optimize: true)
Future<List<Product>> searchProducts(String query) {
  // AI analyzes usage patterns and auto-optimizes:
  // - Predictive caching
  // - Request batching
  // - Smart pagination
}
```

#### 4. Integration with ZikZak AI Backend

```dart
@zuraffa(backend: ZikZakAI)
Future<Result<Product, AppFailure>> getProduct(String id) {
  // Native integration with ZikZak AI's backend
  // - Auto-authentication
  // - Smart caching based on AI predictions
  // - Personalized data fetching
}
```

---

## 🏆 Competitive Advantages

### vs Riverpod

| Feature | Zuraffa v1.0 | Riverpod |
|---------|--------------|----------|
| Dependencies | Zero | flutter_riverpod, freezed, etc |
| Serialization | Morphy | Freezed |
| Code Gen | AI-powered | riverpod_generator |
| Test Gen | 100% auto | Manual |
| Offline-First | Built-in | Manual |
| AI Integration | First-class | None |
| Clean Arch | Enforced | Optional |
| Backend Integration | ZikZak AI native | Generic |

### vs BLoC

| Feature | Zuraffa v1.0 | BLoC |
|---------|--------------|------|
| Boilerplate | Zero (AI-generated) | Massive |
| Testing | Auto-generated | Manual setup |
| Learning Curve | Minimal | Steep |
| State Management | Declarative | Event-driven |
| Code Gen | AI-powered | None |
| Clean Arch | Built-in | Manual |

### vs GetX

| Feature | Zuraffa v1.0 | GetX |
|---------|--------------|------|
| Architecture | Clean (enforced) | None |
| Type Safety | Full | Partial |
| Testing | 100% coverage | Hard to test |
| Code Generation | AI-powered | None |
| Dependencies | Zero extra | Many |

---

## 🎨 Design Principles

### 1. AI-First, Always

Every feature is designed with AI code generation in mind. Developers write **intent**, AI writes **implementation**.

### 2. Zero Magic, Full Control

Unlike other frameworks, Zuraffa generates **readable, debuggable code**. No hidden magic. You own every line.

### 3. Morphy Over Freezed

Freezed is great, but Morphy is **optimized for ZikZak AI's needs**:
- Primitive JSON Forever™
- Better inheritance support
- Cleaner generated code

### 4. TDD is Not Optional

Tests are generated **before** code runs. If a feature doesn't have tests, it doesn't ship.

### 5. Own the Stack

From JSON → Entity → UseCase → State → UI, Zuraffa controls every layer. No external dependencies that might break.

---

## 🚀 Milestones

### Phase 1: Foundation ✅ (v0.1.0 - v0.3.0)
- ✅ Entity generation with Morphy
- ✅ Clean Architecture code generation
- ✅ TDD with 100% test coverage
- ✅ CLI infrastructure

### Phase 2: State Management 🚧 (v0.4.0 - v0.5.0)
- 🚧 @zuraffa annotation
- 🚧 ZuraffaWidget + ZuraffaRef
- 🚧 Provider system (zero deps)
- 🚧 Async state handling
- 🚧 Caching primitives

### Phase 3: AI Integration 🔮 (v0.6.0 - v0.9.0)
- 🔮 AI code suggestions
- 🔮 AI code review
- 🔮 AI refactoring
- 🔮 AI test generation
- 🔮 AI architecture analysis

### Phase 4: Production Ready 🎯 (v1.0.0)
- 🎯 Offline-first by default
- 🎯 Real-time sync
- 🎯 ZikZak AI backend integration
- 🎯 Performance optimization
- 🎯 Production battle-tested

---

## 📊 Success Metrics

### v0.3.0 (Current)
- ✅ Generate 19 files in <10 seconds
- ✅ 100% test pass rate
- ✅ Zero manual setup required

### v0.4.0 (Target)
- 🎯 Riverpod-level DX
- 🎯 Still zero external dependencies
- 🎯 10x reduction in boilerplate vs manual

### v1.0.0 (Dream)
- 🎯 #1 state management for AI-first apps
- 🎯 Adopted by 10,000+ developers
- 🎯 "The only state management built for AI agents"

---

## 🤝 Contributing to the Vision

Want to help build the future of Flutter state management?

1. **Use Zuraffa** in your projects
2. **Report bugs** and suggest features
3. **Contribute code** via PRs
4. **Spread the word** about AI-first development

---

## 💬 Philosophy

> "State management frameworks ask developers to write boilerplate. Zuraffa asks AI to write it instead."

> "Why choose between Riverpod and BLoC when AI can generate the perfect solution for your exact use case?"

> "TDD isn't a practice. It's the default."

---

## 📋 v0.4.0 Implementation Checklist

### Phase 1: Core Primitives (Week 1-2)

#### ZuraffaRef & Lifecycle
- [ ] `abstract class ZuraffaRef`
  - [ ] `T read<T>(ProviderBase<T> provider)`
  - [ ] `T watch<T>(ProviderBase<T> provider)`
  - [ ] `bool get mounted` - lifecycle check
  - [ ] `void invalidate(ProviderBase provider)` - force refresh

#### ZuraffaNotifier Base Class
- [ ] `abstract class ZuraffaNotifier<T>`
  - [ ] `T build()` - initial state
  - [ ] `T get state` - current state
  - [ ] `set state(T value)` - update state + notify
  - [ ] `ZuraffaRef get ref` - access to ref
  - [ ] `void dispose()` - cleanup

#### Provider Base Classes
- [ ] `abstract class ProviderBase<T>`
  - [ ] ID generation
  - [ ] State storage
  - [ ] Listener management
- [ ] `class ZuraffaProvider<T, P>` - Simple providers
- [ ] `class ZuraffaNotifierProvider<T>` - Stateful notifiers
- [ ] `class ZuraffaFutureProvider<T>` - Async providers

### Phase 2: Retry Logic (Week 3)

#### Retry Strategy
- [ ] `typedef RetryStrategy = Duration? Function(int retryCount, Object error)`
- [ ] Default exponential backoff implementation
- [ ] Per-provider retry configuration
- [ ] Global retry configuration

#### Retry Execution
- [ ] Retry wrapper for Future providers
- [ ] Retry count tracking
- [ ] Error type filtering
- [ ] Max retry limit
- [ ] Delay between retries

### Phase 3: ZuraffaScope & Container (Week 4)

#### ZuraffaScope Widget
- [ ] `class ZuraffaScope extends InheritedWidget`
  - [ ] Global retry configuration
  - [ ] Observer support
  - [ ] Provider overrides (for testing)
  - [ ] `static ZuraffaContainer containerOf(BuildContext)`

#### ZuraffaContainer
- [ ] `class ZuraffaContainer`
  - [ ] Provider instance storage
  - [ ] Dependency graph
  - [ ] `T read<T>(ProviderBase<T>)` - one-time read
  - [ ] `void listen<T>()` - subscribe to changes
  - [ ] `void dispose()` - cleanup all providers

### Phase 4: ZuraffaWidget (Week 5)

#### Widget Base Class
- [ ] `abstract class ZuraffaWidget extends StatelessWidget`
  - [ ] Automatic ZuraffaRef injection
  - [ ] `Widget build(BuildContext, ZuraffaRef)`
  - [ ] Automatic subscription management
  - [ ] Dispose on unmount

#### Rebuild Optimization
- [ ] Track provider dependencies per widget
- [ ] Only rebuild when watched providers change
- [ ] Batch updates

### Phase 5: Code Generation (Week 6-7)

#### @zuraffa Annotation
- [ ] `class Zuraffa` annotation class
  - [ ] `RetryStrategy? retry` parameter
  - [ ] `Duration? cache` parameter (future)

#### Generator Infrastructure
- [ ] Provider code generator
  - [ ] Scan for @zuraffa annotations
  - [ ] Generate provider definitions
  - [ ] Generate notifier classes
  - [ ] Generate tests
- [ ] CLI integration
  - [ ] `zuraffa generate providers` command
  - [ ] Watch mode for development

#### Generated Code Templates
- [ ] Simple provider template
- [ ] Notifier provider template
- [ ] Future provider template
- [ ] Family provider template
- [ ] Test template for each type

### Phase 6: Testing (Week 8)

#### Test Generators
- [ ] Provider test generator
  - [ ] Test state initialization
  - [ ] Test state updates
  - [ ] Test ref.mounted checks
  - [ ] Test retry logic
- [ ] Integration test generator
  - [ ] Test provider composition
  - [ ] Test ZuraffaScope overrides

#### Manual Tests
- [ ] Unit tests for all primitives
- [ ] Integration tests for full flow
- [ ] Performance tests
- [ ] Memory leak tests

### Phase 7: Documentation (Week 9)

#### API Documentation
- [ ] ZuraffaRef API docs
- [ ] ZuraffaNotifier API docs
- [ ] ZuraffaScope API docs
- [ ] Retry strategy guide
- [ ] Migration guide from v0.3.0

#### Examples
- [ ] Simple counter example
- [ ] Todo list with API
- [ ] Shopping cart with retry
- [ ] Real-time chat example

### Phase 8: Release (Week 10)

- [ ] Final bug fixes
- [ ] Performance optimization
- [ ] README update
- [ ] CHANGELOG for v0.4.0
- [ ] Release blog post
- [ ] Tag and publish v0.4.0

---

## 🎯 v0.4.0 Success Criteria

### Must Have
- ✅ ZuraffaRef with read/watch
- ✅ ZuraffaNotifier with lifecycle safety
- ✅ Automatic retry (per-provider + global)
- ✅ ZuraffaScope & Container
- ✅ @zuraffa code generation
- ✅ 100% test coverage for generated code
- ✅ Zero external dependencies

### Nice to Have
- Provider families (can wait for v0.5.0)
- Persistent caching (can wait for v0.5.0)
- DevTools integration (can wait for v1.0.0)

### Performance Targets
- Provider lookup: <1ms
- State update: <5ms
- Widget rebuild: <10ms
- No memory leaks

---

<p align="center">
  <strong>For Humanity. For ZikZak. For AI Agents. 🦒</strong>
</p>
