// Replace: example/lib/main.dart
//
// Diff from the original example app: adds product_api_bridge registration
// and wraps runApp's child in XRayHost with x-ray enabled. Everything else
// (DI setup, cache init, todo bridge) is unchanged from the shipped example.

import 'package:example/src/domain/domain.dart';
import 'package:example/src/presentation/pages/todo/todo_view.dart';
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:example/src/api/bridges/todo_api_bridge.dart';
import 'package:example/src/api/bridges/product_api_bridge.dart';
import './src/di/index.dart' as auto_di;
import './src/cache/index.dart' as auto_cache;

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  auto_di.setupDependencies(getIt);
  await Hive.initFlutter();
  await auto_cache.initAllCaches();
}

void _initializeBridge() {
  ZuraffaApiBridge.init();
  registerTodoApiBridge();
  registerProductApiBridge();

  // Register entity field schemas so x-ray builds typed forms.
  XRayPlugin().registerEntitySchema('Todo', [
    const XRayEntityField(name: 'id', type: 'int'),
    const XRayEntityField(name: 'title', type: 'String'),
    const XRayEntityField(name: 'isCompleted', type: 'bool'),
    const XRayEntityField(name: 'createdAt', type: 'DateTime'),
  ]);
  XRayPlugin().registerEntitySchema('Product', [
    const XRayEntityField(name: 'id', type: 'String'),
    const XRayEntityField(name: 'name', type: 'String'),
    const XRayEntityField(name: 'description', type: 'String'),
    const XRayEntityField(name: 'price', type: 'double'),
    const XRayEntityField(name: 'createdAt', type: 'DateTime'),
  ]);

  // x-ray: DTD/VM-Service keys + debug overlay.
  // No-op in release builds — safe to leave enabled unconditionally.
  Zuraffa.enableXRay(
    const XRayConfig(
      useCases: true,
      endpointCatalog: true,
      overlayPosition: OverlayPosition.bottomRight,
    ),
  );
}

void main() {
  Zuraffa.enableLogging();
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies()
      .then((_) {
        // NOTE: unlike the original example (which called this after
        // runApp), the bridge + x-ray must be initialized *before*
        // runApp() here. XRayHost decides whether to mount the overlay
        // once, in its first build/initState — if `enableXRay` runs after
        // that first build, XRayHost has already committed to rendering
        // `child` with no overlay for this session.
        _initializeBridge();
        runApp(const ZuraffaExampleApp());
      })
      .catchError((Object error, StackTrace st) {
        debugPrint('❌ setupDependencies failed: $error');
        debugPrintStack(stackTrace: st);
        _initializeBridge();
        runApp(const ZuraffaExampleApp());
      });
}

/// Example app demonstrating Zuraffa Clean Architecture + x-ray.
class ZuraffaExampleApp extends StatelessWidget {
  const ZuraffaExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // XRayHost wraps the whole MaterialApp. When x-ray isn't enabled (e.g.
    // release builds), it returns `child` verbatim — zero overhead, zero
    // extra widgets in the tree.
    return XRayHost(
      child: MaterialApp(
        title: 'Zuraffa Clean Architecture Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: TodoView(todoRepository: getIt<TodoRepository>()),
      ),
    );
  }
}
