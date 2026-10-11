@Tags(['flutter'])
/// Tests for ImportVerifier (U45, U46, U47).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U45: A slice whose imports all resolve yields a pass report
///   U46: A dangling import yields a failure naming the file, the line, and
///        the broken import path
///   U47: `dart:` SDK imports always resolve; a `package:` import absent
///        from pubspec.yaml fails verification
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/import_verifier.dart';

void main() {
  late Directory tmpDir;
  late String projectRoot;
  late String sandbox;
  late ImportVerifier verifier;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_import_verify_');
    projectRoot = (await Directory('${tmpDir.path}/project').create()).path;
    sandbox = (await Directory('${tmpDir.path}/sandbox').create()).path;
    await File('$projectRoot/pubspec.yaml').writeAsString('''
name: zik_zak
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  get_it: ^8.0.3
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    verifier = ImportVerifier();
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<File> put(String base, String rel, String content) async {
    final file = File('$base/$rel');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  group('ImportVerifier (FR-013)', () {
    test('U45: a slice whose imports all resolve passes', () async {
      await put(sandbox, 'main_slice.dart', '''
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:zik_zak/src/presentation/pages/product/product_view.dart';

import 'lib/src/di/slice_di.dart';
''');
      await put(
        sandbox,
        'lib/src/presentation/pages/product/product_view.dart',
        "import '../../widgets/primary_button.dart';\n"
            'class ProductView {}\n',
      );
      await put(
        sandbox,
        'lib/src/presentation/widgets/primary_button.dart',
        'class PrimaryButton {}\n',
      );
      await put(sandbox, 'lib/src/di/slice_di.dart', '''
import 'package:get_it/get_it.dart';
import '../presentation/pages/product/product_view.dart';
''');

      final report = verifier.verify(
        sandboxDir: sandbox,
        projectRoot: projectRoot,
      );

      expect(report.passed, isTrue, reason: report.issues.join('\n'));
      expect(report.issues, isEmpty);
      expect(report.filesChecked, equals(4));
    });

    test(
      'U46: a dangling relative import names file, line, and path',
      () async {
        // The state file is missing from the sandbox. (Dart strips the
        // leading newline of multiline literals, so a comment line pins the
        // import to line 2.)
        await put(sandbox, 'lib/product_view.dart', '''
// slice file
import 'product_state.dart';

class ProductView {}
''');

        final report = verifier.verify(
          sandboxDir: sandbox,
          projectRoot: projectRoot,
        );

        expect(report.passed, isFalse);
        expect(report.issues, hasLength(1));
        final issue = report.issues.single;
        expect(issue.file, equals('lib/product_view.dart'));
        expect(issue.line, equals(2));
        expect(issue.importPath, equals('product_state.dart'));
        expect(issue.reason, contains('missing'));
      },
    );

    test('U47: dart: imports resolve; unknown packages fail', () async {
      await put(sandbox, 'lib/odd.dart', '''
import 'dart:io';
import 'package:not_in_pubspec/thing.dart';
''');

      final report = verifier.verify(
        sandboxDir: sandbox,
        projectRoot: projectRoot,
      );

      expect(report.passed, isFalse);
      expect(report.issues, hasLength(1));
      expect(
        report.issues.single.importPath,
        equals('package:not_in_pubspec/thing.dart'),
      );
      expect(report.issues.single.reason, contains('pubspec.yaml'));
    });

    test('U47: dev_dependencies satisfy external package imports', () async {
      await put(sandbox, 'lib/test_util.dart', '''
import 'package:flutter_test/flutter_test.dart';
''');

      final report = verifier.verify(
        sandboxDir: sandbox,
        projectRoot: projectRoot,
      );

      expect(report.passed, isTrue, reason: report.issues.join('\n'));
    });

    test('a self-package import resolves against the sandbox tree', () async {
      await put(sandbox, 'lib/app.dart', '''
import 'package:zik_zak/src/thing.dart';
''');
      await put(sandbox, 'lib/src/thing.dart', 'class Thing {}\n');

      final report = verifier.verify(
        sandboxDir: sandbox,
        projectRoot: projectRoot,
      );

      expect(report.passed, isTrue, reason: report.issues.join('\n'));
    });
  });
}
