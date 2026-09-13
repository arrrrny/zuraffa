// Issue #1176: emitted `hide` clauses contain only names the resolved
// zuraffa barrel actually exports — an `undefined_hidden_name` warning
// fails `zfa build`'s analyze gate.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/utils/entity_utils.dart';
import 'package:zuraffa/src/utils/zuraffa_barrel_exports.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('barrel_exports_');
    // Fixture target project with a resolved (path-style) zuraffa root.
    final zuraffaRoot = p.join(tmp.path, 'zuraffa');
    Directory(p.join(zuraffaRoot, 'lib', 'src')).createSync(recursive: true);
    File(
      p.join(zuraffaRoot, 'lib', 'zuraffa.dart'),
    ).writeAsStringSync("export 'src/core.dart';\n");
    File(p.join(zuraffaRoot, 'lib', 'src', 'core.dart')).writeAsStringSync(
      'class QueryParams<T> {}\nclass EntityNotFound implements Exception {}\n',
    );
    final dotTool = Directory(p.join(tmp.path, '.dart_tool'));
    dotTool.createSync(recursive: true);
    File(p.join(dotTool.path, 'package_config.json')).writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'zuraffa',
            'rootUri': Uri.file(zuraffaRoot).toString(),
            'packageUri': 'lib/',
          },
        ],
      }),
    );
  });

  tearDown(() {
    ZuraffaBarrelExports.reset();
    tmp.deleteSync(recursive: true);
  });

  test('hides are filtered to names the barrel actually exports', () {
    ZuraffaBarrelExports.seed(tmp.path);
    // QueryParams IS exported by the barrel — the hide STAYS (the #942
    // collision case this mechanism exists for).
    expect(EntityUtils.barrelHideNames('QueryParams'), ['QueryParams']);
  });

  test('names the barrel does not export are dropped', () {
    ZuraffaBarrelExports.seed(tmp.path);
    // Product/ProductPatch are not in the fixture barrel — the exact
    // warning that failed the sandbox's zfa build gate.
    expect(EntityUtils.barrelHideNames('Product'), isEmpty);
  });

  test('exported colliding names are kept (the #942 case)', () {
    ZuraffaBarrelExports.seed(tmp.path);
    expect(EntityUtils.barrelHideNames('EntityNotFound'), ['EntityNotFound']);
  });

  // Issue #1530: an unresolved barrel surface must DROP the hide
  // combinator entirely — emitting unverified names is exactly the
  // `undefined_hidden_name` warning class that fails `zfa build`'s own
  // analyze gate on zfa-generated code. The legacy keep-all fallback is
  // removed (spec 1530 FR-001).
  test('unresolved → the hide combinator is dropped entirely', () {
    ZuraffaBarrelExports.reset();
    expect(EntityUtils.barrelHideNames('Product'), isEmpty);
    expect(EntityUtils.barrelHideNames('Task'), isEmpty);
  });

  // Issue #1530 FR-002: `show`-restricted export lines contribute only
  // the shown names; `hide`-carrying lines subtract the hidden names.
  // Verification is against the library's REAL surface, not the target
  // files' full declaration list.
  group('combinator-aware barrel collection (#1530 FR-002)', () {
    late Directory combTmp;

    setUp(() {
      combTmp = Directory.systemTemp.createTempSync('barrel_comb_');
      final zuraffaRoot = p.join(combTmp.path, 'zuraffa');
      Directory(p.join(zuraffaRoot, 'lib', 'src')).createSync(recursive: true);
      // a.dart declares Alpha AND Extra but the barrel only SHOWs Alpha.
      File(p.join(zuraffaRoot, 'lib', 'src', 'a.dart')).writeAsStringSync(
        'class Alpha {}\nclass Extra {}\n',
      );
      // b.dart declares Beta; the barrel line HIDES it.
      File(p.join(zuraffaRoot, 'lib', 'src', 'b.dart')).writeAsStringSync(
        'class Beta {}\n',
      );
      // c.dart declares Gamma with a plain (unqualified) export line.
      File(p.join(zuraffaRoot, 'lib', 'src', 'c.dart')).writeAsStringSync(
        'class Gamma {}\n',
      );
      File(p.join(zuraffaRoot, 'lib', 'zuraffa.dart')).writeAsStringSync(
        [
          "export 'src/a.dart' show Alpha;",
          "export 'src/b.dart' hide Beta;",
          "export 'src/c.dart';",
        ].join('\n'),
      );
      final dotTool = Directory(p.join(combTmp.path, '.dart_tool'));
      dotTool.createSync(recursive: true);
      File(p.join(dotTool.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'zuraffa',
              'rootUri': Uri.file(zuraffaRoot).toString(),
              'packageUri': 'lib/',
            },
          ],
        }),
      );
    });

    tearDown(() {
      ZuraffaBarrelExports.reset();
      combTmp.deleteSync(recursive: true);
    });

    test('a shown name verifies', () {
      ZuraffaBarrelExports.seed(combTmp.path);
      expect(ZuraffaBarrelExports.current!.names, contains('Alpha'));
      expect(EntityUtils.barrelHideNames('Alpha'), ['Alpha']);
    });

    test('a declared-but-not-shown name does NOT verify', () {
      ZuraffaBarrelExports.seed(combTmp.path);
      // Extra lives in a.dart but the export line shows only Alpha —
      // hiding Extra would be an undefined_hidden_name warning.
      expect(ZuraffaBarrelExports.current!.names, isNot(contains('Extra')));
    });

    test('a hidden name does NOT verify', () {
      ZuraffaBarrelExports.seed(combTmp.path);
      expect(ZuraffaBarrelExports.current!.names, isNot(contains('Beta')));
    });

    test('an unqualified export line keeps full collection', () {
      ZuraffaBarrelExports.seed(combTmp.path);
      expect(ZuraffaBarrelExports.current!.names, contains('Gamma'));
    });
  });

  // Issue #1530 FR-003: nested barrels using directory-relative export
  // targets resolve against the EXPORTING barrel's own directory (the
  // legacy lib-root join silently dropped one-level-down names).
  group('nested directory-relative barrel resolution (#1530 FR-003)', () {
    late Directory nestedTmp;

    setUp(() {
      nestedTmp = Directory.systemTemp.createTempSync('barrel_nested_');
      final zuraffaRoot = p.join(nestedTmp.path, 'zuraffa');
      Directory(
        p.join(zuraffaRoot, 'lib', 'src', 'core', 'params'),
      ).createSync(recursive: true);
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'core', 'params',
            'query_params.dart'),
      ).writeAsStringSync('class QueryParams<T> {}\n');
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'core', 'params', 'index.dart'),
      ).writeAsStringSync("export 'query_params.dart';\n");
      File(p.join(zuraffaRoot, 'lib', 'zuraffa.dart')).writeAsStringSync(
        "export 'src/core/params/index.dart';\n",
      );
      final dotTool = Directory(p.join(nestedTmp.path, '.dart_tool'));
      dotTool.createSync(recursive: true);
      File(p.join(dotTool.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'zuraffa',
              'rootUri': Uri.file(zuraffaRoot).toString(),
              'packageUri': 'lib/',
            },
          ],
        }),
      );
    });

    tearDown(() {
      ZuraffaBarrelExports.reset();
      nestedTmp.deleteSync(recursive: true);
    });

    test('a one-level-down directory-relative name verifies', () {
      ZuraffaBarrelExports.seed(nestedTmp.path);
      expect(
        ZuraffaBarrelExports.current!.names,
        contains('QueryParams'),
        reason:
            'query_params.dart must resolve relative to src/core/params/, '
            'not lib/ — a silently dropped name loses the #942 protection',
      );
    });
  });
}
