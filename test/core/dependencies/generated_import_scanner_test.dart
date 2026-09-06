/// SDD-TDD suite for issue #1190 — generated code imports packages the
/// target's pubspec doesn't declare.
///
/// The scanner is the shared core of both remediation surfaces:
/// `zfa make` completion output and the `zfa doctor generated-imports`
/// check. These pins cover the pure functions only (no I/O, hermetic).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/dependencies/generated_import_scanner.dart';

void main() {
  group('GeneratedImportScanner.extractPackageImports', () {
    test('finds plain single-line imports', () {
      final imports = GeneratedImportScanner.extractPackageImports([
        '''
import 'package:zuraffa/zuraffa.dart';
import 'package:get_it/get_it.dart';

class Foo {}
''',
      ]);
      expect(imports, containsAll(<String>['zuraffa', 'get_it']));
    });

    test('finds conditional-import arms that are not at line start', () {
      // app_shell-style bridge: the default arm is a relative URI, the
      // io arm is a package URI mid-line — still an import the analyzer
      // lints on.
      final imports = GeneratedImportScanner.extractPackageImports([
        '''
import 'bridge_stub.dart'
    if (dart.library.io) 'package:zuraffa_flutter/src/presentation/xray/xray_bridge_server.dart';
''',
      ]);
      expect(imports, contains('zuraffa_flutter'));
    });

    test('finds export directives', () {
      final imports = GeneratedImportScanner.extractPackageImports([
        "export 'package:zuraffa/zuraffa.dart' show GetIt;",
      ]);
      expect(imports, contains('zuraffa'));
    });

    test('finds directives with trailing comments', () {
      final imports = GeneratedImportScanner.extractPackageImports([
        "import 'package:get_it/get_it.dart'; // generated dependency",
      ]);
      expect(imports, contains('get_it'));
    });

    test('excludes the host package itself', () {
      final imports = GeneratedImportScanner.extractPackageImports([
        "import 'package:myapp/src/domain/entities/product/product.dart';",
      ], hostPackage: 'myapp');
      expect(imports, isEmpty);
    });

    test('ignores dart: URIs and prose without a quoted package: URI', () {
      final imports = GeneratedImportScanner.extractPackageImports([
        '''
// package:zuraffa is imported by generated code (a comment, not an import)
import 'dart:async';
import 'product.dart' show Product;
''',
      ]);
      expect(imports, isEmpty);
    });

    test('dedups across files', () {
      final imports = GeneratedImportScanner.extractPackageImports([
        "import 'package:zuraffa/zuraffa.dart';",
        "import 'package:zuraffa/mock.dart';",
      ]);
      expect(imports, <String>['zuraffa']);
    });

    test('ignores multi-line strings that merely embed other content', () {
      // A doc comment line starting with the word import must not match:
      // the directive anchor requires the statement to OPEN the line, and
      // `import` followed by prose (no quoted package: URI in the same
      // statement) contributes nothing.
      final imports = GeneratedImportScanner.extractPackageImports([
        '''
/// Import the framework like `package:zuraffa/zuraffa.dart`.
class Usage {}
''',
      ]);
      expect(imports, isEmpty);
    });
  });

  group('GeneratedImportScanner.missingFromPubspec', () {
    const pubspec = '''
name: my_app
dependencies:
  flutter:
    sdk: flutter
  zuraffa: ^6.0.0
dev_dependencies:
  build_runner: ^2.4.0
''';

    test('flags imported packages the pubspec does not declare', () {
      final missing = GeneratedImportScanner.missingFromPubspec(pubspec, [
        'zuraffa',
        'get_it',
        'zuraffa_ui',
      ]);
      expect(missing, containsAll(<String>['get_it', 'zuraffa_ui']));
      expect(missing, isNot(contains('zuraffa')));
    });

    test('counts a dev_dependencies declaration as declared', () {
      const pubspecWithDevZuraffa = '''
name: my_app
dev_dependencies:
  zuraffa: ^6.0.0
''';
      final missing = GeneratedImportScanner.missingFromPubspec(
        pubspecWithDevZuraffa,
        ['zuraffa'],
      );
      expect(missing, isEmpty);
    });

    test('an override-only entry is NOT a declaration', () {
      const overrideOnly = '''
name: my_app
dependency_overrides:
  get_it: ^9.0.0
''';
      final missing = GeneratedImportScanner.missingFromPubspec(overrideOnly, [
        'get_it',
      ]);
      expect(missing, contains('get_it'));
    });
  });

  group('GeneratedImportScanner.pubAddOneLiner', () {
    test('dart for a pure-Dart project, flutter for a Flutter project', () {
      expect(
        GeneratedImportScanner.pubAddOneLiner(
          missing: const ['get_it', 'zuraffa'],
          isFlutter: false,
        ),
        'dart pub add get_it zuraffa',
      );
      expect(
        GeneratedImportScanner.pubAddOneLiner(
          missing: const ['get_it'],
          isFlutter: true,
        ),
        'flutter pub add get_it',
      );
    });

    test('sdk-provided packages are excluded from the pub add list', () {
      final line = GeneratedImportScanner.pubAddOneLiner(
        missing: const ['flutter_test', 'get_it'],
        isFlutter: true,
      );
      expect(line, 'flutter pub add get_it');
      expect(line, isNot(contains('flutter_test')));
    });

    test('returns null when only sdk-provided packages are missing', () {
      expect(
        GeneratedImportScanner.pubAddOneLiner(
          missing: const ['flutter_test'],
          isFlutter: true,
        ),
        isNull,
      );
    });

    test('returns null when nothing is missing', () {
      expect(
        GeneratedImportScanner.pubAddOneLiner(
          missing: const [],
          isFlutter: true,
        ),
        isNull,
      );
    });

    test('sdk package names are recognized exactly', () {
      expect(GeneratedImportScanner.isSdkPackage('flutter'), isTrue);
      expect(GeneratedImportScanner.isSdkPackage('flutter_test'), isTrue);
      expect(
        GeneratedImportScanner.isSdkPackage('flutter_localizations'),
        isTrue,
      );
      expect(GeneratedImportScanner.isSdkPackage('integration_test'), isTrue);
      expect(GeneratedImportScanner.isSdkPackage('get_it'), isFalse);
    });
  });
}
