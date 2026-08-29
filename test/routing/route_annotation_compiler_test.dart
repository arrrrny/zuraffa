import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/routing/route_annotation_compiler.dart';
import 'package:zuraffa/src/routing/route_model.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zfa_route_compile_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Directory makeProject(Map<String, String> files) {
    File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: test_app\n');
    for (final entry in files.entries) {
      final file = File('${tempDir.path}/${entry.key}');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }
    return tempDir;
  }

  group('RouteAnnotationCompiler', () {
    test('e2e: writes lib/src/routing/zfa_router.g.dart (SC-001)', () async {
      makeProject({
        'lib/src/features/products/products_view.dart': '''
import 'package:zuraffa/zuraffa.dart';

@Route(path: '/products/:id', params: {'id': int})
class ProductsView {}
''',
      });

      final outcome = await RouteAnnotationCompiler().compile(tempDir.path);

      expect(outcome.skipped, false);
      expect(outcome.routeCount, 1);
      final routerFile = File(
        '${tempDir.path}/lib/src/routing/zfa_router.g.dart',
      );
      expect(
        routerFile.existsSync(),
        true,
        reason: 'router config must be generated at the well-known path',
      );
      final source = routerFile.readAsStringSync();
      expect(source, contains("path: '/products/:id'"));
      expect(source, contains('class ProductsViewRouteParams'));
      expect(
        source,
        contains(
          "import 'package:test_app/src/features/products/products_view.dart';",
        ),
      );
    });

    test('idempotent: two runs produce byte-identical output', () async {
      makeProject({
        'lib/home_view.dart': '@Route(path: \'/home\')\nclass HomeView {}\n',
        'lib/about_view.dart': '@Route(path: \'/about\')\nclass AboutView {}\n',
      });

      await RouteAnnotationCompiler().compile(tempDir.path);
      final first = File(
        '${tempDir.path}/lib/src/routing/zfa_router.g.dart',
      ).readAsStringSync();
      await RouteAnnotationCompiler().compile(tempDir.path);
      final second = File(
        '${tempDir.path}/lib/src/routing/zfa_router.g.dart',
      ).readAsStringSync();
      expect(second, equals(first));
    });

    test('SC-002: 100 annotated Views compile under 2 seconds', () async {
      final files = <String, String>{};
      for (var i = 0; i < 100; i++) {
        files['lib/src/views/view_$i.dart'] =
            '''
@Route(path: '/screen-$i/:id', params: {'id': int})
class Screen${i}View {}
''';
      }
      makeProject(files);

      final sw = Stopwatch()..start();
      final outcome = await RouteAnnotationCompiler().compile(tempDir.path);
      sw.stop();

      expect(outcome.routeCount, 100);
      expect(
        sw.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason: 'SC-002: 100 views must compile in under 2 seconds',
      );
    });

    test('no annotations + stale router file -> valid empty config', () async {
      makeProject({
        'lib/src/routing/zfa_router.g.dart': '// stale generated content',
      });
      final outcome = await RouteAnnotationCompiler().compile(tempDir.path);
      expect(outcome.skipped, false);
      final source = File(
        '${tempDir.path}/lib/src/routing/zfa_router.g.dart',
      ).readAsStringSync();
      expect(source, contains('final List<RouteBase> zfaRoutes = [];'));
    });

    test(
      'no annotations + no router file -> skipped, nothing written',
      () async {
        makeProject({'lib/home.dart': 'void main() {}\n'});
        final outcome = await RouteAnnotationCompiler().compile(tempDir.path);
        expect(outcome.skipped, true);
        expect(
          File(
            '${tempDir.path}/lib/src/routing/zfa_router.g.dart',
          ).existsSync(),
          false,
        );
      },
    );

    test('validation errors aggregate with file:line locations', () async {
      makeProject({
        'lib/a_view.dart': '@Route(path: \'/dupe\')\nclass AView {}\n',
        'lib/b_view.dart': '@Route(path: \'/dupe\')\nclass BView {}\n',
        'lib/c_view.dart':
            '@Route(path: \'/c\', parent: \'ghost\')\nclass CView {}\n',
      });

      expect(
        () => RouteAnnotationCompiler().compile(tempDir.path),
        throwsA(
          isA<RouteCompilationException>()
              .having(
                (e) => e.errors.length,
                'errors.length',
                greaterThanOrEqualTo(2),
              )
              .having(
                (e) => e.errors
                    .map((err) => '${err.filePath}:${err.line}')
                    .join('|'),
                'locations',
                allOf(contains('a_view.dart'), contains('c_view.dart')),
              )
              .having(
                (e) => e.errors.first.message,
                'duplicate message lists both classes',
                allOf(contains('AView'), contains('BView')),
              ),
        ),
      );
    });

    test('deep link files written when deepLinkAware routes exist', () async {
      makeProject({
        'lib/share_view.dart':
            '@Route(path: \'/share\', deepLinkAware: true)\nclass ShareView {}\n',
      });
      await RouteAnnotationCompiler().compile(tempDir.path);
      expect(
        File(
          '${tempDir.path}/.well-known/apple-app-site-association',
        ).existsSync(),
        true,
      );
      expect(
        File('${tempDir.path}/.well-known/assetlinks.json').existsSync(),
        true,
      );
      expect(
        File(
          '${tempDir.path}/.well-known/apple-app-site-association',
        ).readAsStringSync(),
        contains('/share'),
      );
    });

    test('redirect rules compile into the router file (US-3)', () async {
      makeProject({
        'lib/home_view.dart': '@Route(path: \'/home\')\nclass HomeView {}\n',
        'lib/legacy_view.dart':
            '@Route.redirect(from: \'/legacy\', to: \'/home\')\nclass LegacyView {}\n',
      });
      await RouteAnnotationCompiler().compile(tempDir.path);
      final source = File(
        '${tempDir.path}/lib/src/routing/zfa_router.g.dart',
      ).readAsStringSync();
      expect(source, contains("path: '/legacy', redirect: (_, __) => '/home'"));
    });

    test('shell + child compile into nested ShellRoute (US-4)', () async {
      makeProject({
        'lib/dashboard_view.dart': '''
@Route(path: '/dashboard', isShell: true)
class DashboardView {
  const DashboardView({required this.child});
  final Object child;
}
''',
        'lib/analytics_view.dart':
            '@Route(path: \'/analytics\', parent: \'dashboard\')\nclass AnalyticsView {}\n',
      });
      await RouteAnnotationCompiler().compile(tempDir.path);
      final source = File(
        '${tempDir.path}/lib/src/routing/zfa_router.g.dart',
      ).readAsStringSync();
      expect(source, contains('ShellRoute('));
      expect(source, contains("path: 'analytics'"));
      expect(source, contains('DashboardView(child: child)'));
    });

    test('controller type mismatch fails the compile (SC-004)', () async {
      makeProject({
        'lib/product_view.dart':
            '@Route(path: \'/products/:id\', params: {\'id\': int})\nclass ProductView {}\n',
        'lib/product_controller.dart': '''
class ProductController {
  const ProductController({this.id});
  final String id;
}
''',
      });
      expect(
        () => RouteAnnotationCompiler().compile(tempDir.path),
        throwsA(
          isA<RouteCompilationException>().having(
            (e) => e.errors.first.message,
            'first error message',
            allOf(contains('int'), contains('String')),
          ),
        ),
      );
    });
  });
}
