import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/routing/route_annotation_scanner.dart';

void main() {
  late Directory tempDir;
  late String libDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zfa_route_scan_');
    libDir = '${tempDir.path}/lib';
    Directory(libDir).createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  File writeFile(String relativePath, String content) {
    final file = File('$libDir/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return file;
  }

  group('RouteAnnotationScanner', () {
    test('scans @Route with all named args', () async {
      writeFile('src/features/products/products_view.dart', '''
import 'package:zuraffa/zuraffa.dart';

@Route(
  path: '/products/:id',
  name: 'product-detail',
  deepLinkAware: true,
  parent: 'catalog',
  guardRedirect: '/sign-in',
)
class ProductView {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.routes, hasLength(1));
      final route = scan.routes.first;
      expect(route.viewClassName, 'ProductView');
      expect(route.path, '/products/:id');
      expect(route.name, 'product-detail');
      expect(route.deepLinkAware, true);
      expect(route.parent, 'catalog');
      expect(route.guardRedirect, '/sign-in');
      expect(route.line, greaterThan(0));
      expect(route.importUri, 'src/features/products/products_view.dart');
    });

    test('derives route name from View class when name: absent', () async {
      writeFile('dashboard_view.dart', '''
@Route(path: '/dashboard', isShell: true)
class DashboardView {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.routes.single.name, 'dashboard');
      expect(scan.routes.single.isShell, true);
    });

    test('decodes middleware, params and query args', () async {
      writeFile('secure_view.dart', '''
@Route(
  path: '/secure/:userId/:flag',
  middleware: [AuthGuard, LogGuard],
  params: {'userId': int, 'flag': bool},
  query: ['tab'],
)
class SecureView {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      final route = scan.routes.single;
      expect(route.middleware, ['AuthGuard', 'LogGuard']);
      expect(route.params, {'userId': 'int', 'flag': 'bool'});
      expect(route.query, ['tab']);
    });

    test('decodes redirect: RouteRedirect(from:, to:) named arg', () async {
      writeFile('home_view.dart', '''
@Route(path: '/home', redirect: RouteRedirect(from: '/old-home', to: '/home'))
class HomeView {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.redirects, hasLength(1));
      expect(scan.redirects.first.from, '/old-home');
      expect(scan.redirects.first.to, '/home');
      // The route itself still registers.
      expect(scan.routes, hasLength(1));
    });

    test('scans standalone @Route.redirect form', () async {
      writeFile('legacy_view.dart', '''
@Route.redirect(from: '/legacy', to: '/home')
class LegacyView {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.redirects, hasLength(1));
      expect(scan.redirects.first.from, '/legacy');
      expect(scan.redirects.first.to, '/home');
      // No @Route(...) on the class -> no route registered, but the class
      // is still a View, so no non-View issue either.
      expect(scan.routes, isEmpty);
      expect(scan.issues, isEmpty);
    });

    test('scans standalone @Route.middleware and merges with @Route', () async {
      writeFile('admin_view.dart', '''
@Route(path: '/admin')
@Route.middleware([AuthGuard])
class AdminView {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.routes.single.middleware, ['AuthGuard']);
      expect(scan.routes.single.path, '/admin');
    });

    test('non-View class is an error in strict mode', () async {
      writeFile('not_a_view.dart', '''
@Route(path: '/oops')
class SomeService {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.issues, hasLength(1));
      expect(scan.issues.first.isError, true);
      expect(scan.issues.first.message, contains('SomeService'));
      expect(scan.issues.first.message.toLowerCase(), contains('view'));
    });

    test('non-View class is a warning in lenient mode', () async {
      writeFile('not_a_view.dart', '''
@Route(path: '/oops')
class SomeService {}
''');
      final scan = await RouteAnnotationScanner(
        strictNonView: false,
      ).scanDirectory(libDir);
      expect(scan.issues, hasLength(1));
      expect(scan.issues.first.isError, false);
      // Route still included in lenient mode.
      expect(scan.routes, hasLength(1));
    });

    test('extends *View counts as a View', () async {
      writeFile('custom_view.dart', '''
@Route(path: '/custom')
class CustomScreen extends BaseView {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.issues, isEmpty);
      expect(scan.routes.single.viewClassName, 'CustomScreen');
    });

    test('detects shell View constructor child param', () async {
      writeFile('shell_view.dart', '''
@Route(path: '/shell', isShell: true)
class ShellView {
  const ShellView({super.key, required this.child});
  final Widget child;
}
''');
      writeFile('plain_shell_view.dart', '''
@Route(path: '/plain-shell', isShell: true)
class PlainShellView {
  const PlainShellView({super.key});
}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      final shell = scan.routes.firstWhere(
        (r) => r.viewClassName == 'ShellView',
      );
      final plain = scan.routes.firstWhere(
        (r) => r.viewClassName == 'PlainShellView',
      );
      expect(shell.viewAcceptsChild, true);
      expect(plain.viewAcceptsChild, false);
    });

    test('skips .g.dart generated files', () async {
      writeFile('generated_view.g.dart', '''
@Route(path: '/stale')
class GeneratedView {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.routes, isEmpty);
    });

    test('multiple views across directories all scanned', () async {
      writeFile(
        'a/home_view.dart',
        '@Route(path: \'/home\')\nclass HomeView {}\n',
      );
      writeFile(
        'b/nested/products_view.dart',
        '@Route(path: \'/products\')\nclass ProductsView {}\n',
      );
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(
        scan.routes.map((r) => r.path),
        containsAll(['/home', '/products']),
      );
    });

    test('indexes guard classes for import resolution', () async {
      writeFile('guards/auth_guard.dart', '''
import 'package:zuraffa/zuraffa.dart';

class AuthGuard extends ZuraffaRouteGuard {
  @override
  Future<bool> canActivate(ZfaRouteNavigationContext context) async => true;
}
''');
      writeFile(
        'v/secure_view.dart',
        '@Route(path: \'/secure\', middleware: [AuthGuard])\nclass SecureView {}\n',
      );
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.classIndex.containsKey('AuthGuard'), true);
      expect(scan.classIndex['AuthGuard'], 'guards/auth_guard.dart');
    });

    test('malformed @Route without path is reported as an issue', () async {
      writeFile('bad_view.dart', '''
@Route(deepLinkAware: true)
class BadView {}
''');
      final scan = await RouteAnnotationScanner().scanDirectory(libDir);
      expect(scan.issues, hasLength(1));
      expect(scan.issues.first.isError, true);
      expect(scan.issues.first.message, contains('path'));
    });
  });
}
