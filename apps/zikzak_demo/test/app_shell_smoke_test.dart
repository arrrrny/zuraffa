import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/app/my_app.dart';
import 'package:zikzak_demo/src/di/service_locator.dart';
import 'package:zikzak_demo/src/routing/app_router.dart';

void main() {
  setUp(() {
    // Same DI bootstrap main() performs — registers all generated usecases
    // and repositories so generated views can resolve their presenters.
    // GetIt resets between tests so re-registration is idempotent.
    getIt.reset();
    setupDependencies(getIt);
  });

  testWidgets('app shell builds: GoRouter + getAllRoutes construct', (
    tester,
  ) async {
    // Pump the root app widget. This exercises main.dart's MaterialApp.router
    // wiring and the generated getAllRoutes() aggregation — a real boot smoke
    // test without needing a physical device.
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MyApp), findsOneWidget);
  });

  testWidgets('entity CRUD route renders (datasource DI wired)', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Navigate to a generated entity list route whose repository depends on a
    // registered datasource (the #346 runtime crash path).
    appRouter.go('/grocery_product');
    await tester.pumpAndSettle();

    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      '/grocery_product',
    );
  });
}
