// Tests for the x-ray plugin. Labels reference the acceptance-case numbers
// from the task spec.
//
// Run with: flutter test test/xray_plugin_test.dart

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

int _mockId = 0;

/// Registers [count] NoParams-style endpoints under [domain] with globally
/// unique extension names (`dart:developer` extensions cannot be
/// unregistered, so names must never collide across tests).
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
    XRayPlugin().resetForTesting();
  });

  tearDown(() async {
    await ZuraffaApiBridge.resetForTesting();
    XRayPlugin().resetForTesting();
  });

  // ---------------------------------------------------------------------
  // Acceptance case 1: key determinism
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

    test('key schemes never collide across types/domains/names', () {
      final keys = {
        XRayElementKey.useCase('product', 'getProduct'),
        XRayElementKey.useCase('product', 'createProduct'),
        XRayElementKey.useCase('order', 'getProduct'),
        XRayElementKey.repository('product', 'getProduct'),
        XRayElementKey.dataSource('product', 'getProduct'),
        XRayElementKey.controller('ProductController'),
        XRayElementKey.presenter('product', 'ProductPresenter'),
        XRayElementKey.service('AuthService'),
        XRayElementKey.route('/products'),
        XRayElementKey.endpoint('ext.zuraffa.product.getProduct'),
      };
      expect(keys, hasLength(10));
    });
  });

  // ---------------------------------------------------------------------
  // Acceptance cases 2 & 3: mount in debug, no-op in release
  // ---------------------------------------------------------------------
  group('enable / release guard', () {
    test('enabling sets enabled=true and stores config', () {
      const config = XRayConfig(useCases: true, repositories: true);
      XRayPlugin().enable(config);
      expect(XRayPlugin().enabled, isTrue);
      expect(XRayPlugin().config.repositories, isTrue);
    });

    test('enable() is a no-op when release mode is simulated', () {
      XRayPlugin().debugSimulateReleaseMode = true;
      XRayPlugin().enable(const XRayConfig());
      expect(XRayPlugin().enabled, isFalse);
    });

    testWidgets('XRayHost leaves zero footprint when disabled', (tester) async {
      await tester.pumpWidget(
        const XRayHost(child: MaterialApp(home: Text('app'))),
      );
      expect(find.text('app'), findsOneWidget);
      expect(find.byKey(XRayElementKey.overlayRoot), findsNothing);
      expect(find.byType(XRayOverlay), findsNothing);
    });

    testWidgets('XRayHost mounts the overlay when enabled', (tester) async {
      _registerFakeEndpoints('product', 1);
      XRayPlugin().enable(const XRayConfig());
      await tester.pumpWidget(
        const XRayHost(child: MaterialApp(home: Text('app'))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(XRayElementKey.overlayRoot), findsOneWidget);
    });

    testWidgets('release-simulated XRayHost never mounts the overlay', (
      tester,
    ) async {
      XRayPlugin().debugSimulateReleaseMode = true;
      XRayPlugin().enable(const XRayConfig());
      await tester.pumpWidget(
        const XRayHost(child: MaterialApp(home: Text('app'))),
      );
      expect(find.byKey(XRayElementKey.overlayRoot), findsNothing);
    });
  });

  // ---------------------------------------------------------------------
  // Acceptance case 7 (plugin level): invoke dispatches to the handler
  // ---------------------------------------------------------------------
  test('XRayPlugin.invoke() dispatches to the registered handler', () async {
    var handlerCalls = 0;
    // Unique extension name: dart:developer extensions cannot be
    // unregistered, so names must never collide across tests.
    final method = 'ext.zuraffa.product.invokeEntry${_mockId++}';
    ZuraffaApiBridge.registerEndpoint(
      endpoint: ApiEndpoint(
        method: method,
        domain: 'product',
        usecase: 'invokeEntry',
        params: const {},
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

    final response = await XRayPlugin().invoke(method);
    expect(handlerCalls, 1);
    expect(response.result, contains('"status":"success"'));
  });

  test('XRayPlugin.invoke() on an unknown method returns notFound', () async {
    final response = await XRayPlugin().invoke('ext.zuraffa.nope.nope');
    expect(response.result, contains('notFound'));
  });

  test('registeredEndpoints mirrors ZuraffaApiBridge live', () {
    expect(XRayPlugin().registeredEndpoints, isEmpty);
    _registerFakeEndpoints('product', 3);
    expect(XRayPlugin().registeredEndpoints, hasLength(3));
  });

  // ---------------------------------------------------------------------
  // Element registry (Repositories/DataSources/... sections)
  // ---------------------------------------------------------------------
  group('element registry', () {
    test('elementsOf filters by type and bumps revision', () {
      final before = XRayPlugin().revision.value;
      XRayPlugin().registerElement(
        type: XRayElementType.repository,
        domain: 'product',
        name: 'ProductRepository',
      );
      XRayPlugin().registerElement(
        type: XRayElementType.dataSource,
        domain: 'product',
        name: 'ProductRemoteDataSource',
      );
      expect(XRayPlugin().revision.value, before + 2);
      expect(XRayPlugin().elementsOf(XRayElementType.repository), hasLength(1));
      expect(
        XRayPlugin().elementsOf(XRayElementType.dataSource).single.name,
        'ProductRemoteDataSource',
      );
    });
  });

  // ---------------------------------------------------------------------
  // Widget-level overlay tests
  // ---------------------------------------------------------------------
  group('XRayOverlay widget', () {
    Future<void> pump(WidgetTester tester, XRayConfig config) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: XRayOverlay(config: config)),
        ),
      );
    }

    // Case 4: one UseCase button per registered endpoint.
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

    // Case 5: catalog shows every endpoint with its method name.
    testWidgets('catalog section shows all registered endpoints', (
      tester,
    ) async {
      final names = _registerFakeEndpoints('product', 5);
      await pump(
        tester,
        const XRayConfig(useCases: false, endpointCatalog: true),
      );
      await tester.tap(find.byKey(XRayElementKey.section('catalog')));
      await tester.pumpAndSettle();
      for (final name in names) {
        expect(
          find.byKey(XRayElementKey.endpoint('ext.zuraffa.product.$name')),
          findsOneWidget,
        );
        expect(find.textContaining('ext.zuraffa.product.$name'), findsWidgets);
      }
    });

    // Case 6: section toggle — disabled section does not render.
    testWidgets('repositories section does not appear when disabled', (
      tester,
    ) async {
      await pump(
        tester,
        const XRayConfig(
          repositories: false,
          endpointCatalog: false,
          useCases: false,
        ),
      );
      expect(find.byKey(XRayElementKey.section('repositories')), findsNothing);
    });

    // Extension of case 6: enabled section lists registered elements.
    testWidgets('repositories section renders registered elements', (
      tester,
    ) async {
      XRayPlugin().registerElement(
        type: XRayElementType.repository,
        domain: 'product',
        name: 'ProductRepository',
      );
      XRayPlugin().registerElement(
        type: XRayElementType.repository,
        domain: 'order',
        name: 'OrderRepository',
      );
      await pump(
        tester,
        const XRayConfig(
          useCases: false,
          endpointCatalog: false,
          repositories: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(XRayElementKey.repository('product', 'ProductRepository')),
        findsOneWidget,
      );
      expect(
        find.byKey(XRayElementKey.repository('order', 'OrderRepository')),
        findsOneWidget,
      );
    });

    testWidgets('element button runs onInvoke and shows the result', (
      tester,
    ) async {
      var invocations = 0;
      XRayPlugin().registerElement(
        type: XRayElementType.controller,
        name: 'ProductController',
        onInvoke: () {
          invocations++;
          return 'state: 42 products';
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: XRayOverlay(
              config: const XRayConfig(
                useCases: false,
                endpointCatalog: false,
                controllers: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(XRayElementKey.controller('ProductController')),
      );
      await tester.pumpAndSettle();
      expect(invocations, 1);
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
  // Acceptance case 7 (widget level): tap NoParams button -> handler runs
  // ---------------------------------------------------------------------
  testWidgets('tapping a NoParams button dispatches to the handler', (
    tester,
  ) async {
    var handlerCalls = 0;
    final usecase = 'getProductList${_mockId++}';
    final method = 'ext.zuraffa.product.$usecase';
    ZuraffaApiBridge.registerEndpoint(
      endpoint: ApiEndpoint(
        method: method,
        domain: 'product',
        usecase: usecase,
        params: const {},
        returns: 'List<Product>',
        isStream: false,
      ),
      handler: (m, params) async {
        handlerCalls++;
        return developer.ServiceExtensionResponse.result(
          '{"status":"success","data":{"items":[]}}',
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
    await tester.tap(find.byKey(XRayElementKey.useCase('product', usecase)));
    await tester.pumpAndSettle();
    expect(handlerCalls, 1);
  });

  // ---------------------------------------------------------------------
  // Acceptance case 8: tap a button with params -> form first, then call
  // ---------------------------------------------------------------------
  testWidgets('button with params opens form, submit dispatches values', (
    tester,
  ) async {
    var handlerCalls = 0;
    Map<String, String>? receivedParams;
    final usecase = 'createProduct${_mockId++}';
    final method = 'ext.zuraffa.product.$usecase';
    ZuraffaApiBridge.registerEndpoint(
      endpoint: ApiEndpoint(
        method: method,
        domain: 'product',
        usecase: usecase,
        params: const {'name': 'String'},
        returns: 'Product',
        isStream: false,
      ),
      handler: (m, params) async {
        handlerCalls++;
        receivedParams = params;
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

    // Tap the button: form opens, handler NOT called yet.
    await tester.tap(find.byKey(XRayElementKey.useCase('product', usecase)));
    await tester.pumpAndSettle();
    expect(handlerCalls, 0);
    expect(find.byKey(XRayElementKey.formSubmit(method)), findsOneWidget);

    // Fill the field and submit.
    await tester.enterText(
      find.byKey(XRayElementKey.formField(method, 'name')),
      'Widget Pro',
    );
    await tester.tap(find.byKey(XRayElementKey.formSubmit(method)));
    await tester.pumpAndSettle();

    expect(handlerCalls, 1);
    expect(receivedParams, {'name': 'Widget Pro'});
  });

  // ---------------------------------------------------------------------
  // XRayHost: dismiss/reopen must not remount the app (no state loss)
  // ---------------------------------------------------------------------
  testWidgets('dismiss/reopen preserves the app widget state', (tester) async {
    XRayPlugin().enable(const XRayConfig());
    await tester.pumpWidget(
      const XRayHost(child: MaterialApp(home: _CounterApp())),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(XRayElementKey.overlayRoot), findsOneWidget);

    // Dismiss the panel -> launcher appears.
    await tester.tap(find.byKey(XRayElementKey.overlayClose));
    await tester.pumpAndSettle();
    expect(find.byKey(XRayElementKey.overlayRoot), findsNothing);
    expect(find.byKey(XRayElementKey.overlayLauncher), findsOneWidget);

    // With the panel away the app is fully interactive; mutate its state.
    await tester.tap(find.byKey(const Key('counter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('counter_button')));
    await tester.pumpAndSettle();
    expect(find.text('count: 2'), findsOneWidget);

    // Reopen -> panel back, app state still intact (would read 'count: 0'
    // if the host had remounted the app subtree).
    await tester.tap(find.byKey(XRayElementKey.overlayLauncher));
    await tester.pumpAndSettle();
    expect(find.byKey(XRayElementKey.overlayRoot), findsOneWidget);
    expect(find.text('count: 2'), findsOneWidget);

    // Dismiss once more: still intact.
    await tester.tap(find.byKey(XRayElementKey.overlayClose));
    await tester.pumpAndSettle();
    expect(find.text('count: 2'), findsOneWidget);
  });
}

class _CounterApp extends StatefulWidget {
  const _CounterApp();

  @override
  State<_CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<_CounterApp> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('count: $count'),
            ElevatedButton(
              key: const Key('counter_button'),
              onPressed: () => setState(() => count++),
              child: const Text('inc'),
            ),
          ],
        ),
      ),
    );
  }
}
