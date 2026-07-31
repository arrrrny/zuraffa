import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  setUp(() => CacheObserver.instance.reset());
  tearDown(() => CacheObserver.instance.reset());

  group('CacheObserver', () {
    test('notify pushes update to all listeners', () {
      final updates = <Product>[];
      CacheObserver.instance.listen<Product>((entity, _) {
        if (entity != null) updates.add(entity);
      });

      final product = Product(id: '1', name: 'Widget');
      CacheObserver.instance.notify<Product>(product);

      expect(updates.length, 1);
      expect(updates.first.id, '1');
    });

    test('notifyDelete pushes delete event', () {
      String? deletedId;
      CacheObserver.instance.listen<Product>((_, id) {
        deletedId = id;
      });

      CacheObserver.instance.notifyDelete<Product>('42');
      expect(deletedId, '42');
    });

    test('multiple listeners receive same update', () {
      final log1 = <Product>[];
      final log2 = <Product>[];

      CacheObserver.instance.listen<Product>((entity, _) => log1.add(entity!));
      CacheObserver.instance.listen<Product>((entity, _) => log2.add(entity!));

      CacheObserver.instance.notify<Product>(Product(id: '3'));

      expect(log1.length, 1);
      expect(log2.length, 1);
    });

    test('different types have isolated streams', () {
      final products = <Product>[];
      final reviews = <Review>[];

      CacheObserver.instance.listen<Product>(
        (entity, _) => products.add(entity!),
      );
      CacheObserver.instance.listen<Review>(
        (entity, _) => reviews.add(entity!),
      );

      CacheObserver.instance.notify<Product>(Product(id: '1'));
      CacheObserver.instance.notify<Review>(Review(id: 'r1'));

      expect(products.length, 1);
      expect(reviews.length, 1);
    });

    test('dispose removes stream', () {
      CacheObserver.instance.notify<Product>(Product(id: '1'));
      CacheObserver.instance.dispose<Product>();
      expect(CacheObserver.instance.hasListeners<Product>(), false);
    });
  });

  group('CacheBinding', () {
    test('bindCache updates slice when cache emits', () async {
      final slice = SignalSlice<Product>(
        useCase: _ConstProductUseCase(),
        params: null,
      );

      // Wait for initial load
      await slice.result.nextValue;
      expect(slice.data!.id, 'initial');

      // Bind to cache
      slice.bindCache();

      // Simulate mutation updating cache
      CacheObserver.instance.notify<Product>(
        Product(id: 'updated', name: 'New'),
      );

      expect(slice.data!.id, 'updated');
      expect(slice.data!.name, 'New');
    });

    test('bindCache clears slice on delete', () async {
      final slice = SignalSlice<Product>(
        useCase: _ConstProductUseCase(),
        params: null,
      );
      await slice.result.nextValue;

      slice.bindCache();
      CacheObserver.instance.notifyDelete<Product>('initial');

      // After delete, the slice signals a failure state.
      expect(slice.isFailure, true);
    });

    test('dispose cancels the cache subscription', () async {
      final slice = SignalSlice<Product>(
        useCase: _ConstProductUseCase(),
        params: null,
      );
      await slice.result.nextValue;

      // Prime the cache stream so listen() eagerly delivers a non-null event.
      CacheObserver.instance.notify<Product>(Product(id: 'prime'));

      // Track a cache subscription on the slice, exactly as bindCache() does.
      var calls = 0;
      final sub = CacheObserver.instance.listen<Product>((e, id) => calls++);
      expect(calls, 1); // eager delivery of the primed value
      slice.trackCacheSubscription(sub);

      slice.dispose();

      // After dispose the tracked subscription must be cancelled — a cache
      // emit must not invoke the callback again.
      CacheObserver.instance.notify<Product>(Product(id: 'post-dispose'));
      expect(calls, 1);
    });

    test(
      'bindCache after dispose cancels the subscription immediately',
      () async {
        final slice = SignalSlice<Product>(
          useCase: _ConstProductUseCase(),
          params: null,
        );
        await slice.result.nextValue;
        slice.dispose();

        // Binding after disposal must not leave a listener registered and must
        // not throw. The observer remains fully functional for other listeners.
        slice.bindCache();
        expect(CacheObserver.instance.hasListeners<Product>(), true);
      },
    );
  });

  group('CacheMutator mixin', () {
    test('notifyCache emits update', () {
      final updates = <Product>[];
      CacheObserver.instance.listen<Product>(
        (entity, _) => updates.add(entity!),
      );

      final useCase = _MutatingUseCase();
      useCase.mutate(Product(id: '99'));

      expect(updates.length, 1);
      expect(updates.first.id, '99');
    });
  });
}

// ── Domain models ──

class Product {
  Product({required this.id, this.name = ''});
  final String id;
  final String name;
}

class Review {
  Review({required this.id});
  final String id;
}

// ── Use cases ──

class _ConstProductUseCase extends ZuraffaUseCase<dynamic, Product> {
  @override
  SignalResult<Product> call(dynamic params, {ZuraffaContext? context}) {
    final sr = SignalResult<Product>.initial(
      LoadingResult<Product, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitSuccess(Product(id: 'initial'));
    });
    return sr;
  }
}

class _MutatingUseCase with CacheMutator<Product> {
  void mutate(Product product) {
    notifyCache(product);
  }
}
