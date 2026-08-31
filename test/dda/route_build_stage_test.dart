@Tags(['slow'])
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

import '../helpers/project_root.dart';
import '../helpers/run_zfa_source.dart';

// A1, A3, A4 + U10–U24: end-to-end route build stage over temp projects.
//
// The real entry point per the spec: annotate a View → run the stage (the
// same code `zfa build` runs) → assert on the generated
// `lib/src/routing/zfa_router.g.dart`.

void main() {
  late Directory sandbox;

  Directory makeProject({
    String pubspecDeps = '  go_router: ^14.0.0',
    bool writePubspec = true,
  }) {
    final dir = Directory.systemTemp.createTempSync('zfa_route_stage_');
    if (writePubspec) {
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: stage_app
environment:
  sdk: ^3.11.0
dependencies:
$pubspecDeps
''');
    }
    Directory(p.join(dir.path, 'lib', 'views')).createSync(recursive: true);
    return dir;
  }

  void writeView(String fileName, String source) {
    File(p.join(sandbox.path, 'lib', 'views', fileName)).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

$source
''');
  }

  String routerPath() =>
      p.join(sandbox.path, 'lib', 'src', 'routing', 'zfa_router.g.dart');

  setUp(() {
    sandbox = makeProject();
  });

  tearDown(() async {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    await findProjectRoot();
  });

  group('stage e2e', () {
    test(
      'writes router file with route, name, view class and import',
      () async {
        writeView('products_view.dart', '''
@ZfaRoute(path: '/products')
class ProductsView {}
''');

        final result = await RouteBuildStage(projectRoot: sandbox.path).run();

        expect(result.success, isTrue, reason: result.errors.join('\n'));
        expect(result.wroteRouterFile, isTrue);
        final file = File(routerPath());
        expect(
          file.existsSync(),
          isTrue,
          reason: 'zfa_router.g.dart must exist',
        );
        final code = file.readAsStringSync();
        expect(code, contains('createZfaRouter'));
        expect(code, contains('GoRouter'));
        expect(code, contains("path: '/products'"));
        expect(code, contains("name: 'products'"));
        expect(code, contains('ProductsView'));
        expect(code, contains('package:stage_app/views/products_view.dart'));
        expect(code, contains('DO NOT EDIT'));
      },
    );

    test('idempotent: two runs produce byte-identical output', () async {
      writeView('home_view.dart', '''
@ZfaRoute(path: '/home')
class HomeView {}
''');
      writeView('about_view.dart', '''
@ZfaRoute(path: '/about')
class AboutView {}
''');

      final stage = RouteBuildStage(projectRoot: sandbox.path);
      await stage.run();
      final first = File(routerPath()).readAsStringSync();
      await stage.run();
      final second = File(routerPath()).readAsStringSync();

      expect(second, equals(first));
    });

    test('both spellings @Route and @ZfaRoute produce routes', () async {
      writeView('a_view.dart', '''
@Route(path: '/a')
class AView {}
''');
      writeView('b_view.dart', '''
@ZfaRoute(path: '/b')
class BView {}
''');

      final result = await RouteBuildStage(projectRoot: sandbox.path).run();

      expect(result.success, isTrue, reason: result.errors.join('\n'));
      final code = File(routerPath()).readAsStringSync();
      expect(code, contains("path: '/a'"));
      expect(code, contains("path: '/b'"));
    });

    test(
      'redirect e2e: @ZfaRoute.redirect emits rule, no GoRoute for it',
      () async {
        writeView('legacy_view.dart', '''
@ZfaRoute.redirect(from: '/legacy', to: '/home')
class LegacyRedirect {}
''');
        writeView('home_view.dart', '''
@ZfaRoute(path: '/home')
class HomeView {}
''');

        final result = await RouteBuildStage(projectRoot: sandbox.path).run();

        expect(result.success, isTrue, reason: result.errors.join('\n'));
        final code = File(routerPath()).readAsStringSync();
        expect(code, contains("matchedLocation == '/legacy'"));
        expect(code, contains("return '/home'"));
        // Redirect-only annotation contributes no route of its own.
        expect(code, isNot(contains("path: '/legacy'")));
      },
    );

    test('redirect legacy named-args form still works', () async {
      writeView('legacy_view.dart', '''
@ZfaRoute(redirectFrom: '/old', redirectTo: '/home')
class LegacyRedirect {}
''');
      writeView('home_view.dart', '''
@ZfaRoute(path: '/home')
class HomeView {}
''');

      final result = await RouteBuildStage(projectRoot: sandbox.path).run();

      expect(result.success, isTrue, reason: result.errors.join('\n'));
      final code = File(routerPath()).readAsStringSync();
      expect(code, contains("matchedLocation == '/old'"));
    });

    test(
      'shell nesting: isShell + parent by name nests children under shell View',
      () async {
        writeView('dashboard_shell.dart', '''
@ZfaRoute(path: '/dashboard', isShell: true)
class DashboardShell {}
''');
        writeView('analytics_view.dart', '''
@ZfaRoute(path: '/analytics', parent: 'dashboard')
class AnalyticsView {}
''');

        final result = await RouteBuildStage(projectRoot: sandbox.path).run();

        expect(result.success, isTrue, reason: result.errors.join('\n'));
        final code = File(routerPath()).readAsStringSync();
        expect(code, contains('ShellRoute'));
        // Shell builder renders the shell view AROUND the child.
        expect(code, contains('DashboardShell(child: child)'));
        // Child path is nested under the shell's path.
        expect(code, contains("path: '/dashboard/analytics'"));
        expect(code, contains('AnalyticsView'));
      },
    );

    test('shell nesting: parent by path nests identically', () async {
      writeView('dashboard_shell.dart', '''
@ZfaRoute(path: '/dashboard', isShell: true)
class DashboardShell {}
''');
      writeView('analytics_view.dart', '''
@ZfaRoute(path: '/analytics', parent: '/dashboard')
class AnalyticsView {}
''');

      final result = await RouteBuildStage(projectRoot: sandbox.path).run();

      expect(result.success, isTrue, reason: result.errors.join('\n'));
      final code = File(routerPath()).readAsStringSync();
      expect(code, contains("path: '/dashboard/analytics'"));
    });

    test(
      'guard e2e: middleware emits canActivate/onRejected redirect block',
      () async {
        writeView('profile_view.dart', '''
@ZfaRoute(path: '/profile', middleware: [AuthGuard])
class ProfileView {}
''');

        final result = await RouteBuildStage(projectRoot: sandbox.path).run();

        expect(result.success, isTrue, reason: result.errors.join('\n'));
        final code = File(routerPath()).readAsStringSync();
        expect(code, contains('AuthGuard'));
        expect(code, contains('canActivate'));
        expect(code, contains('onRejected'));
      },
    );

    test(
      'typed path param: pathParameters int yields final int id + int.parse',
      () async {
        writeView('items_view.dart', '''
@ZfaRoute(path: '/items/:id', pathParameters: {'id': 'int'})
class ItemsView {}
''');

        final result = await RouteBuildStage(projectRoot: sandbox.path).run();

        expect(result.success, isTrue, reason: result.errors.join('\n'));
        final code = File(routerPath()).readAsStringSync();
        expect(code, contains('class ItemsViewRouteParams'));
        expect(code, contains('final int id'));
        expect(code, contains("int.parse(state.pathParameters['id']!)"));
      },
    );

    test('typed query params with safe defaults when absent', () async {
      writeView('search_view.dart', '''
@ZfaRoute(path: '/search', queryParameters: {'q': 'String', 'page': 'int'})
class SearchView {}
''');

      final result = await RouteBuildStage(projectRoot: sandbox.path).run();

      expect(result.success, isTrue, reason: result.errors.join('\n'));
      final code = File(routerPath()).readAsStringSync();
      expect(code, contains('final String q'));
      expect(code, contains('final int page'));
      // Query params tolerate absence: tryParse with default, not a crash.
      expect(code, contains('tryParse'));
    });

    test('mixed path + query params land in one params class', () async {
      writeView('settings_view.dart', '''
@ZfaRoute(
  path: '/users/:userId/settings',
  pathParameters: {'userId': 'int'},
  queryParameters: {'tab': 'String'},
)
class SettingsView {}
''');

      final result = await RouteBuildStage(projectRoot: sandbox.path).run();

      expect(result.success, isTrue, reason: result.errors.join('\n'));
      final code = File(routerPath()).readAsStringSync();
      expect(code, contains('class SettingsViewRouteParams'));
      expect(code, contains('final int userId'));
      expect(code, contains('final String tab'));
    });

    test('deep link marker emitted only for deepLinkAware routes', () async {
      writeView('share_view.dart', '''
@ZfaRoute(path: '/share', deepLinkAware: true)
class ShareView {}
''');
      writeView('plain_view.dart', '''
@ZfaRoute(path: '/plain')
class PlainView {}
''');

      final result = await RouteBuildStage(projectRoot: sandbox.path).run();

      expect(result.success, isTrue, reason: result.errors.join('\n'));
      final code = File(routerPath()).readAsStringSync();
      expect(code, contains('Deep-link-aware'));
      final plainIndex = code.indexOf("path: '/plain'");
      final shareIndex = code.indexOf('Deep-link-aware');
      // The marker belongs to /share, not to /plain (plain route has none).
      expect(plainIndex, greaterThan(-1));
      expect(
        code.substring(plainIndex, plainIndex + 80),
        isNot(contains('Deep-link-aware')),
      );
    });

    test(
      'empty project (no annotations, no stale file): success, writes nothing',
      () async {
        writeView('plain.dart', 'class NotARoute {}\n');

        final result = await RouteBuildStage(projectRoot: sandbox.path).run();

        expect(result.success, isTrue);
        expect(result.wroteRouterFile, isFalse);
        expect(File(routerPath()).existsSync(), isFalse);
      },
    );

    test('stale router file regenerated as valid empty config', () async {
      // Seed a stale router file from a previous build.
      final stalePath = routerPath();
      File(stalePath).createSync(recursive: true);
      File(stalePath).writeAsStringSync('// stale content with route /old\n');

      final result = await RouteBuildStage(projectRoot: sandbox.path).run();

      expect(result.success, isTrue);
      expect(result.wroteRouterFile, isTrue);
      final code = File(stalePath).readAsStringSync();
      expect(code, isNot(contains('/old')));
      expect(code, contains('createZfaRouter'));
    });

    test('removed routes are pruned from the regenerated file', () async {
      writeView('home_view.dart', '''
@ZfaRoute(path: '/home')
class HomeView {}
''');
      writeView('old_view.dart', '''
@ZfaRoute(path: '/old')
class OldView {}
''');

      await RouteBuildStage(projectRoot: sandbox.path).run();
      var code = File(routerPath()).readAsStringSync();
      expect(code, contains("path: '/old'"));

      // Remove the annotated view, regenerate.
      File(p.join(sandbox.path, 'lib', 'views', 'old_view.dart')).deleteSync();
      await RouteBuildStage(projectRoot: sandbox.path).run();
      code = File(routerPath()).readAsStringSync();
      expect(code, isNot(contains("path: '/old'")));
      expect(code, contains("path: '/home'"));
    });

    test('validation fails the stage before any file is written', () async {
      writeView('a_view.dart', '''
@ZfaRoute(path: '/dupe')
class AView {}
''');
      writeView('b_view.dart', '''
@ZfaRoute(path: '/dupe')
class BView {}
''');

      final result = await RouteBuildStage(projectRoot: sandbox.path).run();

      expect(result.success, isFalse);
      expect(result.errors, isNotEmpty);
      expect(result.errors.first, contains('/dupe'));
      expect(result.errors.first, contains('AView'));
      expect(result.errors.first, contains('BView'));
      expect(
        File(routerPath()).existsSync(),
        isFalse,
        reason: 'no router file may be written when validation fails',
      );
    });

    test(
      'go_router missing from pubspec fails with actionable error',
      () async {
        sandbox.deleteSync(recursive: true);
        sandbox = makeProject(pubspecDeps: '  http: ^1.0.0');
        writeView('home_view.dart', '''
@ZfaRoute(path: '/home')
class HomeView {}
''');

        final result = await RouteBuildStage(projectRoot: sandbox.path).run();

        expect(result.success, isFalse);
        expect(result.errors.join('\n'), contains('go_router'));
      },
    );

    test(
      'non-View annotation target fails with class name and location',
      () async {
        writeView('not_a_view.dart', '''
@ZfaRoute(path: '/services')
class ServiceLocator {}
''');

        final result = await RouteBuildStage(projectRoot: sandbox.path).run();

        expect(result.success, isFalse);
        expect(result.errors.join('\n'), contains('ServiceLocator'));
      },
    );
  });

  group('build command wiring (subprocess)', () {
    setUpAll(() async {
      await initZfaSourceBin();
    });

    test('zfa build --dda-routes-only produces the router file', () async {
      writeView('products_view.dart', '''
@ZfaRoute(path: '/products')
class ProductsView {}
''');

      final proc = await runZfaSource(
        ['build', '--dda-routes-only'],
        workingDirectory: sandbox.path,
      );
      final out = '${proc.stdout}\n${proc.stderr}';

      expect(proc.exitCode, equals(0), reason: out);
      expect(File(routerPath()).existsSync(), isTrue, reason: out);
      expect(
        File(routerPath()).readAsStringSync(),
        contains("path: '/products'"),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'zfa build --dda-routes-only fails on DDA validation errors',
      () async {
        writeView('a_view.dart', '''
@ZfaRoute(path: '/dupe')
class AView {}
''');
        writeView('b_view.dart', '''
@ZfaRoute(path: '/dupe')
class BView {}
''');

        final proc = await runZfaSource(
          ['build', '--dda-routes-only'],
          workingDirectory: sandbox.path,
        );
        final out = '${proc.stdout}\n${proc.stderr}';

        expect(proc.exitCode, equals(1), reason: out);
        expect(out, contains('/dupe'));
        expect(
          File(routerPath()).existsSync(),
          isFalse,
          reason: 'no router file may be written when validation fails',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('zfa build --no-dda-routes skips the route stage', () async {
      writeView('products_view.dart', '''
@ZfaRoute(path: '/products')
class ProductsView {}
''');

      final proc = await runZfaSource(
        ['build', '--dda-routes-only', '--no-dda-routes'],
        workingDirectory: sandbox.path,
      );
      final out = '${proc.stdout}\n${proc.stderr}';

      expect(proc.exitCode, equals(0), reason: out);
      expect(
        File(routerPath()).existsSync(),
        isFalse,
        reason: '--no-dda-routes must skip route generation entirely',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
