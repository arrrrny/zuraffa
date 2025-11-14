# 🦒 Zuraffa State Management - Counter Example

This is a simple counter example showing v0.4.0 state management in action!

## Step 1: Create the Notifier

Create `lib/counter_notifier.dart`:

```dart
import 'package:zuraffa/zuraffa.dart';

class CounterNotifier extends ZuraffaNotifier<int> {
  @override
  int build() => 0; // Initial state

  void increment() {
    state = state + 1;
  }

  void decrement() {
    state = state - 1;
  }

  Future<void> incrementAsync() async {
    await Future.delayed(Duration(seconds: 1));
    if (!ref.mounted) return; // Safety check!
    state = state + 1;
  }
}

// Create the provider
final counterProvider = ZuraffaNotifierProvider<CounterNotifier, int>(
  () => CounterNotifier(),
  id: 'counter',
);
```

## Step 2: Create the Counter Page

Create `lib/counter_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';
import 'counter_notifier.dart';

class CounterPage extends ZuraffaWidget {
  const CounterPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, ZuraffaRef ref) {
    // Watch the counter - auto-rebuilds when it changes!
    final count = ref.watch(counterProvider);

    // Get the notifier to call methods
    final notifier = (counterProvider as ZuraffaNotifierProvider).getNotifier(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text('Zuraffa Counter'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Count:',
              style: TextStyle(fontSize: 24),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: notifier.decrement,
                  child: Icon(Icons.remove),
                  heroTag: 'decrement',
                ),
                SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: notifier.increment,
                  child: Icon(Icons.add),
                  heroTag: 'increment',
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: notifier.incrementAsync,
              child: Text('Async +1 (with safety check)'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Step 3: Wrap Your App with ZuraffaScope

Update `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';
import 'counter_page.dart';

void main() {
  runApp(
    ZuraffaScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zuraffa Counter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CounterPage(),
    );
  }
}
```

## Step 4: Run It!

```bash
flutter run
```

## ✨ What You Get

- ✅ **Auto-rebuilds** - Widget rebuilds when count changes
- ✅ **Lifecycle safety** - `ref.mounted` check prevents crashes
- ✅ **Type-safe** - Full type inference
- ✅ **Zero dependencies** - No Riverpod, Provider, or BLoC!
- ✅ **Clean separation** - State logic in notifier, UI in widget

## 🎯 Advanced: Using ZuraffaConsumer

If you don't want to extend ZuraffaWidget, use ZuraffaConsumer:

```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZuraffaConsumer(
        builder: (context, ref) {
          final count = ref.watch(counterProvider);
          return Text('Count: $count');
        },
      ),
    );
  }
}
```

## 🚀 Next: Try with Your Generated Product!

Now try using state management with your generated Product code:

```dart
// Create a provider for your Product repository
final productRepositoryProvider = ZuraffaProvider<ProductRepository, void>(
  (ref, _) => DataProductRepository(
    remoteDataSource: RemoteProductDataSource(...),
    localDataSource: LocalProductDataSource(...),
  ),
  id: 'productRepository',
);

// Create a future provider to load products
final productsProvider = ZuraffaFutureProvider<List<Product>, void>(
  (ref, _) async {
    final repo = ref.read(productRepositoryProvider);
    final result = await repo.getAll();
    return result.fold(
      (failure) => throw Exception(failure.message),
      (products) => products,
    );
  },
  id: 'products',
);

// Use in your widget
class ProductListPage extends ZuraffaWidget {
  @override
  Widget build(BuildContext context, ZuraffaRef ref) {
    final productsFuture = ref.watch(productsProvider);

    return FutureBuilder<List<Product>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final products = snapshot.data!;
        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ListTile(
              title: Text(product.name),
              subtitle: Text('\$${product.price}'),
            );
          },
        );
      },
    );
  }
}
```

---

**For Humanity. For ZikZak. For AI Agents.** 🦒
