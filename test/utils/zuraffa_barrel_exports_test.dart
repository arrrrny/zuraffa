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
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'a.dart'),
      ).writeAsStringSync('class Alpha {}\nclass Extra {}\n');
      // b.dart declares Beta; the barrel line HIDES it.
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'b.dart'),
      ).writeAsStringSync('class Beta {}\n');
      // c.dart declares Gamma with a plain (unqualified) export line.
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'c.dart'),
      ).writeAsStringSync('class Gamma {}\n');
      // d.dart declares Delta AND WrappedSecret; the statement shows
      // Delta only and dart_style wraps the tail onto its own line.
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'd.dart'),
      ).writeAsStringSync('class Delta {}\nclass WrappedSecret {}\n');
      // e.dart declares Epsilon and Zeta; ONE statement carries both
      // combinators (`show Epsilon hide Zeta`).
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'e.dart'),
      ).writeAsStringSync('class Epsilon {}\nclass Zeta {}\n');
      // f.dart declares Eta, Theta and Iota; the shown name list itself
      // wraps across lines.
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'f.dart'),
      ).writeAsStringSync('class Eta {}\nclass Theta {}\nclass Iota {}\n');
      File(p.join(zuraffaRoot, 'lib', 'zuraffa.dart')).writeAsStringSync(
        [
          "export 'src/a.dart' show Alpha;",
          "export 'src/b.dart' hide Beta;",
          "export 'src/c.dart';",
          // The form this repository's own `lib/zuraffa.dart` ships:
          // the combinator tail lives on the line AFTER `export`.
          "export 'src/d.dart'",
          '    show Delta;',
          "export 'src/e.dart' show Epsilon hide Zeta;",
          // The wrapped shown-name list form.
          "export 'src/f.dart'",
          '    show',
          '        Eta,',
          '        Theta;',
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

    // Review of #1578: the combinator tail belongs to the STATEMENT, and
    // dart_style wraps long `export`s (this repository's own
    // `lib/zuraffa.dart` ships four of them). A line-scoped parse reads
    // an empty tail for the wrapped form, treats the statement as
    // unrestricted, and collects the target file's whole declaration
    // list — the over-collection that re-emits unverified hides.
    test('a wrapped `export … show …` restricts to the shown names', () {
      ZuraffaBarrelExports.seed(combTmp.path);
      expect(ZuraffaBarrelExports.current!.names, contains('Delta'));
      expect(
        ZuraffaBarrelExports.current!.names,
        isNot(contains('WrappedSecret')),
        reason:
            'the wrapped statement shows Delta only; collecting '
            'WrappedSecret re-emits an undefined_hidden_name hide',
      );
    });

    test('a wrapped shown-name list keeps every shown name', () {
      ZuraffaBarrelExports.seed(combTmp.path);
      expect(ZuraffaBarrelExports.current!.names, contains('Eta'));
      expect(ZuraffaBarrelExports.current!.names, contains('Theta'));
      expect(ZuraffaBarrelExports.current!.names, isNot(contains('Iota')));
    });

    // Review of #1578: `show Alpha hide Beta` is ONE legal statement; a
    // capture that runs to the `;` swallows the sibling keyword
    // (`{Epsilon hide Zeta}`), so neither name matches a declaration and
    // a name that genuinely IS exported stops verifying — the #942
    // collision protection disappears for it.
    test('a sibling `show … hide …` keeps the shown name only', () {
      ZuraffaBarrelExports.seed(combTmp.path);
      expect(ZuraffaBarrelExports.current!.names, contains('Epsilon'));
      expect(ZuraffaBarrelExports.current!.names, isNot(contains('Zeta')));
      expect(EntityUtils.barrelHideNames('Epsilon'), ['Epsilon']);
      expect(EntityUtils.barrelHideNames('Zeta'), isEmpty);
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
        p.join(
          zuraffaRoot,
          'lib',
          'src',
          'core',
          'params',
          'query_params.dart',
        ),
      ).writeAsStringSync('class QueryParams<T> {}\n');
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'core', 'params', 'index.dart'),
      ).writeAsStringSync("export 'query_params.dart';\n");
      File(
        p.join(zuraffaRoot, 'lib', 'zuraffa.dart'),
      ).writeAsStringSync("export 'src/core/params/index.dart';\n");
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
