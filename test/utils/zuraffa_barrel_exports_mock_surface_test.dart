// Issue #1418 (secondary): the mock lane hides names from
// `package:zuraffa/mock.dart` but verifies them against the `zuraffa.dart`
// surface only — the actually-imported library's export surface is never
// walked. These tests pin `filterMock`: a name the mock barrel does not
// export is never hidden from it, the bare re-export union keeps the #942
// protection, and an unresolved surface drops the combinator entirely
// (#1530 FR-001 carryover).
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/utils/zuraffa_barrel_exports.dart';

void main() {
  late Directory tmp;

  /// Builds a fake target project + fake zuraffa package and seeds the
  /// resolver from it. [zuraffaCore] declares the zuraffa surface;
  /// [mockBarrel]/[mockImpl] shape the mock barrel's export chain
  /// (mock.dart → src/mock.dart).
  Directory fixture({
    required String zuraffaCore,
    String? mockBarrel,
    String? mockImpl,
  }) {
    final zuraffaRoot = p.join(tmp.path, 'zuraffa');
    Directory(p.join(zuraffaRoot, 'lib', 'src')).createSync(recursive: true);
    File(
      p.join(zuraffaRoot, 'lib', 'zuraffa.dart'),
    ).writeAsStringSync("export 'src/core.dart';\n");
    File(
      p.join(zuraffaRoot, 'lib', 'src', 'core.dart'),
    ).writeAsStringSync(zuraffaCore);
    if (mockBarrel != null) {
      File(
        p.join(zuraffaRoot, 'lib', 'mock.dart'),
      ).writeAsStringSync(mockBarrel);
    }
    if (mockImpl != null) {
      File(
        p.join(zuraffaRoot, 'lib', 'src', 'mock.dart'),
      ).writeAsStringSync(mockImpl);
    }
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
    return tmp;
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('barrel_mock_surface_');
  });

  tearDown(() {
    ZuraffaBarrelExports.reset();
    tmp.deleteSync(recursive: true);
  });

  group('A5 — filterMock verifies the library the mock lane imports', () {
    test(
      '(a) diverged mock barrel: zuraffa-only names are NOT hidden from mock.dart',
      () {
        fixture(
          zuraffaCore: 'class Credentials {}\nclass CredentialsPatch {}\n',
          mockBarrel: "export 'src/mock.dart';\n",
          mockImpl: 'class MockThing {}\n',
        );
        ZuraffaBarrelExports.seed(tmp.path);

        // The zuraffa-barrel filter keeps both (they ARE exported there).
        expect(
          ZuraffaBarrelExports.filter(['Credentials', 'CredentialsPatch']),
          ['Credentials', 'CredentialsPatch'],
        );
        // The mock barrel exports neither → the mock import hides nothing.
        expect(
          ZuraffaBarrelExports.filterMock(['Credentials', 'CredentialsPatch']),
          isEmpty,
        );
        // Mock-local names stay hidden (verified against the right surface).
        expect(ZuraffaBarrelExports.filterMock(['MockThing']), ['MockThing']);
        // …and the zuraffa filter never saw MockThing.
        expect(ZuraffaBarrelExports.filter(['MockThing']), isEmpty);
      },
    );

    test('(b) bare re-export: the zuraffa union keeps the #942 protection', () {
      fixture(
        zuraffaCore: 'class Credentials {}\nclass CredentialsPatch {}\n',
        mockBarrel: "export 'src/mock.dart';\n",
        mockImpl:
            "export 'package:zuraffa/zuraffa.dart';\n"
            'const bool zuraffaMockLibrary = true;\n',
      );
      ZuraffaBarrelExports.seed(tmp.path);

      expect(
        ZuraffaBarrelExports.filterMock(['Credentials', 'CredentialsPatch']),
        ['Credentials', 'CredentialsPatch'],
        reason:
            'the bare re-export makes the zuraffa surface part of the mock '
            'surface — the collision hide survives on the mock lane',
      );
    });

    test('(c) show-combinator re-export: only the shown names union', () {
      fixture(
        zuraffaCore: 'class Credentials {}\nclass CredentialsPatch {}\n',
        mockBarrel: "export 'src/mock.dart';\n",
        mockImpl: "export 'package:zuraffa/zuraffa.dart' show Credentials;\n",
      );
      ZuraffaBarrelExports.seed(tmp.path);

      expect(
        ZuraffaBarrelExports.filterMock(['Credentials', 'CredentialsPatch']),
        ['Credentials'],
        reason:
            'a combinator-carrying re-export contributes only what it '
            'actually re-exports',
      );
    });

    test('(d) unresolved surface: both filters drop the combinator', () {
      ZuraffaBarrelExports.reset();
      expect(ZuraffaBarrelExports.filterMock(['Credentials']), isEmpty);
      expect(ZuraffaBarrelExports.filter(['Credentials']), isEmpty);
    });
  });

  group('U5 — mock-surface walk semantics', () {
    test('missing lib/mock.dart → mock surface is empty (no combinator)', () {
      // zuraffa barrel resolves, but no mock barrel exists in the package.
      fixture(zuraffaCore: 'class Credentials {}\n');
      ZuraffaBarrelExports.seed(tmp.path);

      expect(ZuraffaBarrelExports.filter(['Credentials']), ['Credentials']);
      expect(ZuraffaBarrelExports.filterMock(['Credentials']), isEmpty);
    });

    test('external package re-exports stay excluded from the mock surface', () {
      fixture(
        zuraffaCore: 'class Credentials {}\n',
        mockBarrel: "export 'src/mock.dart';\n",
        mockImpl:
            "export 'package:some_other_pkg/exports.dart';\n"
            'class MockThing {}\n',
      );
      ZuraffaBarrelExports.seed(tmp.path);

      expect(
        ZuraffaBarrelExports.filterMock(['ExternalThing']),
        isEmpty,
        reason:
            'the walker cannot see external combinators — under-'
            'collection is the safe direction (#1530 FR-003 doctrine)',
      );
      expect(ZuraffaBarrelExports.filterMock(['MockThing']), ['MockThing']);
    });

    test('combinators on the mock chain honor show/hide', () {
      fixture(
        zuraffaCore: 'class Credentials {}\n',
        mockBarrel: "export 'src/mock.dart' show MockThing hide Hidden;\n",
        mockImpl: 'class MockThing {}\nclass Hidden {}\n',
      );
      ZuraffaBarrelExports.seed(tmp.path);

      expect(ZuraffaBarrelExports.filterMock(['MockThing']), ['MockThing']);
      expect(
        ZuraffaBarrelExports.filterMock(['Hidden']),
        isEmpty,
        reason:
            'the barrel line hides it — hiding it from mock.dart would '
            'be an undefined_hidden_name warning',
      );
    });

    test('filter is unchanged by the mock-surface addition', () {
      fixture(
        zuraffaCore: 'class Credentials {}\nclass CredentialsPatch {}\n',
        mockBarrel: "export 'src/mock.dart';\n",
        mockImpl: 'class MockThing {}\n',
      );
      ZuraffaBarrelExports.seed(tmp.path);

      // filter still verifies against zuraffa.dart — the interface writer
      // and every other emission site keep their contract (FR-005).
      expect(ZuraffaBarrelExports.filter(['Credentials']), ['Credentials']);
      expect(ZuraffaBarrelExports.filter(['CredentialsPatch']), [
        'CredentialsPatch',
      ]);
      expect(ZuraffaBarrelExports.filter(['MockThing']), isEmpty);
    });
  });
}
