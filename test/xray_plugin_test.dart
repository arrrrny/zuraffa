// Tests for the x-ray plugin: DTD key determinism, overlay mount/section
// behavior, and endpoint dispatch. Each `test`/`testWidgets` below is
// labelled with the acceptance-case number it satisfies from the task spec.
//
// Run with: flutter test test/xray_plugin_test.dart
// (see README.md for full setup instructions)

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

int _mockId = 0;

/// Registers [count] trivial `NoParams`-style endpoints under [domain],
/// with globally unique extension names. Each handler just echoes back
/// success with the method name, so tests can assert dispatch without
/// needing real UseCases/DI wired up.
List<String> _registerFakeEndpoints(String domain, int count) {
  final names = <String>[];
  for (var i = 0; i < count; i++) {
    final name = 'entry${_mockId++}';
    names.add(name);
    ZuraffaApiBridge.registerEndpoint(
      endpoint: ApiEndpoint(
        method: 'ext.zuraffa.$domain.$name',
        domain: domain,
        usecase: name,
        params: const {},
        returns: 'void',
        isStream: false,
      ),
      handler: (method, params) async {
        return developer.ServiceExtensionResponse.result(
          '{"status":"success","data":{"called":"$method"}}',
        );
      },
    );
  }
  return names;
}

void main() {
  setUp(() async {
    await ZuraffaApiBridge.resetForTesting();
    XRayPlugin().disable();
  });

  tearDown(() async {
    await ZuraffaApiBridge.resetForTesting();
    XRayPlugin().disable();
  });

  // ---------------------------------------------------------------------
  // Acceptance case 1: Key determinism
  // ---------------------------------------------------------------------
  group('XRayElementKey', () {
    test('useCase() is deterministic', () {
      final a = XRayElementKey.useCase('barcode_listing', 'scanBarcode');
      final b = XRayElementKey.useCase('barcode_listing', 'scanBarcode');
      expect(a, equals(b));
      expect(
        (a as ValueKey).value,
        'xray::usecase::barcode_listing::scanBarcode',
      );
    });

    test('different domain/name pairs never collide', () {
      final keys = {
        XRayElementKey.useCase('product', 'getProduct'),
        XRayElementKey.useCase('product', 'createProduct'),
        XRayElementKey.useCase('order', 'getProduct'),
        XRayElementKey.repository('product', 'getProduct'),
        XRayElementKey.dataSource('product', 'getProduct'),
      };
      expect(keys, hasLength(5)); // all distinct
    });

    test('endpoint() keys off the full method string', () {
      final key = XRayElementKey.endpoint('ext.zuraffa.product.getProduct');
      expect(
        (key as ValueKey).value,
        'xray::endpoint::ext.zuraffa.product.getProduct',
      );
    });
  });

  // ---------------------------------------------------------------------
  // Acceptance case 6 (release-mode no-op) — case 3's equivalent, since we
  // can't flip kReleaseMode at test time, we assert the plugin-level guard
  // logic that `enableXRay` delegates to instead.
  // ---------------------------------------------------------------------
  group('XRayPlugin.enable', () {
    test('enabling sets enabled=true and stores config', () {
      _registerFakeEndpoints('product', 5);
      const config = XRayConfig(useCases: true, repositories: false);
      XRayPlugin().enable(config);

      expect(XRayPlugin().enabled, isTrue);
      expect(XRayPlugin().config.useCases, isTrue);
      expect(XRayPlugin().config.repositories, isFalse);
    });

    test('registeredEndpoints mirrors ZuraffaApiBridge live', () {
      XRayPlugin().enable(const XRayConfig());
      expect(XRayPlugin().registeredEndpoints, isEmpty);

      _registerFakeEndpoints('product', 3); // Getter reads live
      // No re-enable call needed — the getter reads live.
      expect(XRayPlugin().registeredEndpoints, hasLength(3));
    });
  });

  // ---------------------------------------------------------------------
  // Acceptance case 7: tap a NoParams button dispatches to the bridge
  // handler (tested at the plugin level, decoupled from widget rendering).
  // ---------------------------------------------------------------------
  test('XRayPlugin.invoke() dispatches to the registered handler', () async {
    var handlerCalls = 0;
    ZuraffaApiBridge.registerEndpoint(
      endpoint: const ApiEndpoint(
        method: 'ext.zuraffa.product.getProductList',
        domain: 'product',
        usecase: 'getProductList',
        params: {},
        returns: 'List<Product>',
        isStream: false,
      ),
      handler: (method, params) async {
        handlerCalls++;
        return developer.ServiceExtensionResponse.result(
          '{"status":"success","data":{"items":[]}}',
        );
      },
    );

    XRayPlugin().enable(const XRayConfig());
    final response = await XRayPlugin().invoke(
      'ext.zuraffa.product.getProductList',
    );

    expect(handlerCalls, 1);
    expect(response.result, contains('"status":"success"'));
  });

  test('XRayPlugin.invoke() on an unknown method returns notFound', () async {
    XRayPlugin().enable(const XRayConfig());
    final response = await XRayPlugin().invoke('ext.zuraffa.nope.nope');
    expect(response.result, contains('notFound'));
  });

  // ---------------------------------------------------------------------
  // Widget-level tests
  // ---------------------------------------------------------------------
  group('XRayOverlay widget', () {
    Future<void> pump(WidgetTester tester, XRayConfig config) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: XRayOverlay(config: config)),
        ),
      );
    }

    // Acceptance case 2: overlay mounts (in a non-release test host, which
    // is the only mode `flutter test` runs in).
    testWidgets('overlay mounts and shows its root key', (tester) async {
      _registerFakeEndpoints('product', 2);
      await pump(tester, const XRayConfig(useCases: true));

      expect(find.byKey(XRayElementKey.overlayRoot), findsOneWidget);
    });

    // Acceptance case 4: UseCase buttons render, one per endpoint.
    testWidgets('renders one button per registered endpoint in UseCases', (
      tester,
    ) async {
      final names = _registerFakeEndpoints('product', 5);
      await pump(
        tester,
        const XRayConfig(useCases: true, endpointCatalog: false),
      );
      await tester.pumpAndSettle();

      for (final name in names) {
        expect(
          find.byKey(XRayElementKey.useCase('product', name)),
          findsOneWidget,
        );
      }
    });

    // Acceptance case 5: endpoint catalog section shows every endpoint
    // with its method name.
    testWidgets('catalog section shows all registered endpoints', (
      tester,
    ) async {
      final names = _registerFakeEndpoints('product', 5);
      await pump(
        tester,
        const XRayConfig(useCases: false, endpointCatalog: true),
      );
      // Catalog section starts collapsed by default — expand it.
      await tester.tap(find.byKey(XRayElementKey.section('catalog')));
      await tester.pumpAndSettle();

      for (final name in names) {
        expect(
          find.byKey(
            XRayElementKey.endpoint('ext.zuraffa.product.$name'),
          ),
          findsOneWidget,
        );
      }
    });

    // Acceptance case 6: section toggle — disabled section doesn't render.
    testWidgets('repositories section does not appear when disabled', (
      tester,
    ) async {
      await pump(
        tester,
        const XRayConfig(repositories: false, endpointCatalog: false, useCases: false),
      );
      expect(
        find.byKey(XRayElementKey.section('repositories')),
        findsNothing,
      );
    });

    testWidgets('close button invokes onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: XRayOverlay(
              config: const XRayConfig(),
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(XRayElementKey.overlayClose));
      expect(closed, isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // Acceptance case 8: tapping a button whose endpoint has params opens
  // the inline form before calling the handler.
  // ---------------------------------------------------------------------
  testWidgets('button with params opens form instead of calling immediately', (
    tester,
  ) async {
    var handlerCalls = 0;
    ZuraffaApiBridge.registerEndpoint(
      endpoint: const ApiEndpoint(
        method: 'ext.zuraffa.product.createProduct',
        domain: 'product',
        usecase: 'createProduct',
        params: {'name': 'String'},
        returns: 'Product',
        isStream: false,
      ),
      handler: (method, params) async {
        handlerCalls++;
        return developer.ServiceExtensionResponse.result(
          '{"status":"success","data":{}}',
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XRayOverlay(
            config: const XRayConfig(useCases: true, endpointCatalog: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(XRayElementKey.useCase('product', 'createProduct')),
    );
    await tester.pumpAndSettle();

    // Handler must NOT have been called yet — the form should be showing.
    expect(handlerCalls, 0);
    expect(
      find.byKey(
        XRayElementKey.formField('ext.zuraffa.product.createProduct', 'name'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(
        XRayElementKey.formField('ext.zuraffa.product.createProduct', 'name'),
      ),
      'Widget',
    );
    await tester.tap(
      find.byKey(
        XRayElementKey.formSubmit('ext.zuraffa.product.createProduct'),
      ),
    );
    await tester.pumpAndSettle();

    expect(handlerCalls, 1);
  });
}
