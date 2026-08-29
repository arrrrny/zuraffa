import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

// U1–U7: the scanner must hand plugins TYPED annotation argument values.
//
// Regression evidence (why this file exists): `_parseAnnotation` stored every
// named argument via `argumentExpression.toSource()`, so `path: '/home'`
// arrived as the *string-with-quotes* `'/home'` and `deepLinkAware: true`
// arrived as the *String* `'true'` — which made `DecoratorAST.get<bool>`
// throw on real scanner output and broke `RouteDDAPlugin.onApply`.

void main() {
  late Directory sandbox;

  Directory writeProject(String source) {
    final dir = Directory.systemTemp.createTempSync('zfa_scan_literal_');
    File(
      '${dir.path}/pubspec.yaml',
    ).writeAsStringSync('name: scan_app\nenvironment:\n  sdk: ^3.11.0\n');
    Directory('${dir.path}/lib').createSync();
    File('${dir.path}/lib/home_view.dart').writeAsStringSync(source);
    return dir;
  }

  setUp(() {
    sandbox = writeProject('');
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<DecoratorAST> scanFirst(String source) async {
    final dir = writeProject(source);
    try {
      final results = await ASTScanner(projectRoot: '${dir.path}/lib').scan();
      return results.first.decorator;
    } finally {
      dir.deleteSync(recursive: true);
    }
  }

  test(
    'string literal named arg scans to typed String without quotes',
    () async {
      final d = await scanFirst('''
@ZfaRoute(path: '/home')
class HomeView {}
''');
      expect(d.get<String>('path'), equals('/home'));
    },
  );

  test('bool literal named arg scans to typed bool', () async {
    final d = await scanFirst('''
@ZfaRoute(path: '/home', deepLinkAware: true)
class HomeView {}
''');
    expect(d.get<bool>('deepLinkAware'), isTrue);
  });

  test('int and double literal named args scan to typed numbers', () async {
    final d = await scanFirst('''
@ZfaRoute(path: '/home', someInt: 42, someDouble: 3.14)
class HomeView {}
''');
    expect(d.get<int>('someInt'), equals(42));
    expect(d.get<double>('someDouble'), equals(3.14));
  });

  test('null literal named arg scans to null', () async {
    final d = await scanFirst('''
@ZfaRoute(path: '/home', parentPath: null)
class HomeView {}
''');
    expect(d.namedArgs['parentPath'], isNull);
  });

  test('list literal named arg scans to raw element sources', () async {
    final d = await scanFirst('''
@ZfaRoute(path: '/home', middleware: [AuthGuard, LogGuard])
class HomeView {}
''');
    final raw = d.namedArgs['middleware'];
    expect(raw, isA<List>());
    expect(raw as List, equals(['AuthGuard', 'LogGuard']));
  });

  test(
    'map literal named arg scans to a parseable raw source string',
    () async {
      final d = await scanFirst('''
@ZfaRoute(path: '/search', queryParameters: {'q': 'String', 'page': 'int'})
class SearchView {}
''');
      final raw = d.namedArgs['queryParameters'];
      expect(raw, isA<String>());
      // The plugin parses this raw source into {q: String, page: int}.
      expect(raw as String, contains("'q'"));
      expect(raw, contains("'String'"));
      expect(raw, contains("'int'"));
    },
  );

  test('ZfaRoute spelling reports decorator name ZfaRoute', () async {
    final d = await scanFirst('''
@ZfaRoute(path: '/home')
class HomeView {}
''');
    expect(d.name, equals('ZfaRoute'));
  });
}
