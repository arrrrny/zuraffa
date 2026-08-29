import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

// U8–U9: the syntactic fast path (`resolve: false`) lets the route build
// stage scan a project without an analysis context (no pubspec resolution,
// no per-file resolve) — the SC-002 <2s budget depends on it.

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('zfa_scan_fast_');
    // NOTE: deliberately NO pubspec.yaml — the fast path must not need one.
    Directory('${sandbox.path}/lib/views').createSync(recursive: true);
    File('${sandbox.path}/lib/views/home_view.dart').writeAsStringSync('''
@ZfaRoute(path: '/home', deepLinkAware: true)
class HomeView {}
''');
    File('${sandbox.path}/lib/views/other_view.dart').writeAsStringSync('''
@Route(path: '/other')
class OtherView {}
''');
  });

  tearDown(() async {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test('fast path scans a project with no pubspec.yaml', () async {
    final scanner = ASTScanner(
      projectRoot: '${sandbox.path}/lib',
      resolve: false,
    );
    final results = await scanner.scan();

    expect(results, hasLength(2));
    final paths = results.map((r) => r.decorator.get<String>('path')).toSet();
    expect(paths, equals({'/home', '/other'}));
    // Typed values work identically on the fast path.
    final home = results.firstWhere(
      (r) => r.decorator.get<String>('path') == '/home',
    );
    expect(home.decorator.get<bool>('deepLinkAware'), isTrue);
  });

  test(
    'fast path excludes generated .g.dart and .freezed.dart files',
    () async {
      File(
        '${sandbox.path}/lib/views/generated_routes.g.dart',
      ).writeAsStringSync('''
@ZfaRoute(path: '/generated')
class GeneratedView {}
''');

      final scanner = ASTScanner(
        projectRoot: '${sandbox.path}/lib',
        resolve: false,
      );
      final results = await scanner.scan();

      final paths = results.map((r) => r.decorator.get<String>('path')).toSet();
      expect(paths, isNot(contains('/generated')));
    },
  );
}
