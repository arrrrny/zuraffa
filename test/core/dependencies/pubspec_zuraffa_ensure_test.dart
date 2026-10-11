// SPEC 1530 — `package:zuraffa` dependency ensure (US2, FR-005/FR-006).
//
// Generated files import `package:zuraffa/...`; when the target pubspec
// declares only `zuraffa_flutter` / `zuraffa_ui` (the dogfood todo app's
// shape) the core `zuraffa` package is never declared — every generated
// import fires `depend_on_referenced_packages` and `zfa build`'s analyze
// gate goes red on zfa-generated code. The #1265 auto-add heals the gap
// only when a network `pub add` can run; the ensure is the offline-safe
// textual declaration (the `zfa tdd init --skin` patcher discipline for
// `zuraffa_ui`): parse YAML for detection only, patch textually, refuse
// exotic shapes loudly.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/dependencies/pubspec_zuraffa_ensure.dart';

void main() {
  late Directory tmp;

  Future<String> seedPubspec(String content) async {
    final file = File(p.join(tmp.path, 'pubspec.yaml'));
    await file.writeAsString(content);
    return file.path;
  }

  String readPubspec() =>
      File(p.join(tmp.path, 'pubspec.yaml')).readAsStringSync();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('zuraffa_ensure_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  group('PubspecZuraffaEnsure (#1530 FR-005)', () {
    test('A-1530-5: a pubspec without zuraffa gains the declaration at the '
        'end of the dependencies block', () async {
      await seedPubspec('''
name: repro_app
description: fixture
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: ^2.3.0
  json_annotation: ^4.12.0
dev_dependencies:
  lints: ^6.0.0
''');
      final result = await const PubspecZuraffaEnsure().ensure(tmp.path);

      expect(result.added, isTrue);
      expect(result.constraint, '^6.0.0');
      final content = readPubspec();
      expect(
        content,
        contains('  zuraffa: ^6.0.0\n'),
        reason:
            'the declaration lands inside the dependencies block:\n'
            '$content',
      );
      // RUNTIME dependency — never dev_dependencies.
      final devIndex = content.indexOf('dev_dependencies:');
      final zuraffaIndex = content.indexOf('zuraffa: ^6.0.0');
      expect(
        zuraffaIndex < devIndex,
        isTrue,
        reason: 'generated lib/ imports need a REGULAR dependency',
      );
    });

    test('A-1530-6: idempotent — an already-declared pubspec is left '
        'byte-identical', () async {
      const original = '''
name: repro_app
dependencies:
  zuraffa: ^6.2.2
''';
      await seedPubspec(original);

      final result = await const PubspecZuraffaEnsure().ensure(tmp.path);

      expect(result.added, isFalse);
      expect(readPubspec(), original);
    });

    test(
      'A-1530-7: comments, blank lines, and entry order are preserved',
      () async {
        const original = '''
name: repro_app
# A hand comment above dependencies
dependencies:
  # Comment on the first entry
  zorphy_annotation: ^2.3.0

  json_annotation: ^4.12.0
# A comment after the block
dev_dependencies:
  lints: ^6.0.0
''';
        await seedPubspec(original);

        final result = await const PubspecZuraffaEnsure().ensure(tmp.path);

        expect(result.added, isTrue);
        final content = readPubspec();
        // Every comment and blank line survives the textual patch.
        expect(content, contains('# A hand comment above dependencies'));
        expect(content, contains('# Comment on the first entry'));
        expect(content, contains('# A comment after the block'));
        expect(
          content,
          contains('  zorphy_annotation: ^2.3.0\n\n  json_annotation:'),
          reason: 'blank lines between entries are preserved',
        );
        // The insertion sits before the next top-level key.
        final insertion = content.indexOf('zuraffa: ^6.0.0');
        final dev = content.indexOf('dev_dependencies:');
        expect(insertion, greaterThan(0));
        expect(insertion, lessThan(dev));
      },
    );

    test('A-1530-8a: inline dependencies mapping needing a patch is refused '
        'loudly', () async {
      await seedPubspec('''
name: repro_app
dependencies: {path: ^1.9.0}
''');
      await expectLater(
        const PubspecZuraffaEnsure().ensure(tmp.path),
        throwsUnsupportedError,
      );
    });

    test('A-1530-8b: unparseable YAML is refused loudly', () async {
      await seedPubspec('''
name: [repro_app
  broken: :::
''');
      await expectLater(
        const PubspecZuraffaEnsure().ensure(tmp.path),
        throwsFormatException,
      );
    });

    test('A-1530-8c: an override-only declaration is NOT a declaration — '
        'the dependencies entry is still added', () async {
      await seedPubspec('''
name: repro_app
dependencies:
  path: ^1.9.0
dependency_overrides:
  zuraffa: 6.2.2
''');
      final result = await const PubspecZuraffaEnsure().ensure(tmp.path);

      expect(result.added, isTrue);
      final content = readPubspec();
      // The #1190 contract: overrides do not satisfy
      // depend_on_referenced_packages — the regular declaration lands.
      final depsIndex = content.indexOf('dependencies:');
      final zuraffaInDeps = content
          .substring(depsIndex, content.indexOf('dependency_overrides:'))
          .contains('zuraffa: ^6.0.0');
      expect(zuraffaInDeps, isTrue);
    });

    test('A-1530-9: no zuraffa entry is added when the caller did not '
        'detect a package:zuraffa import (ensureForImports no-op)', () async {
      const original = '''
name: repro_app
dependencies:
  path: ^1.9.0
''';
      await seedPubspec(original);

      final result = await const PubspecZuraffaEnsure().ensureForImports(
        tmp.path,
        const ['path', 'yaml'],
      );

      expect(result.added, isFalse);
      expect(readPubspec(), original);
    });

    test('ensureForImports adds the declaration when a written file '
        'imports package:zuraffa/', () async {
      const original = '''
name: repro_app
dependencies:
  path: ^1.9.0
''';
      await seedPubspec(original);

      final result = await const PubspecZuraffaEnsure().ensureForImports(
        tmp.path,
        const ['path', 'zuraffa'],
      );

      expect(result.added, isTrue);
      expect(readPubspec(), contains('zuraffa: ^6.0.0'));
    });

    test('a missing dependencies section gets one appended', () async {
      await seedPubspec('''
name: repro_app
environment:
  sdk: ^3.11.0
''');
      final result = await const PubspecZuraffaEnsure().ensure(tmp.path);

      expect(result.added, isTrue);
      expect(readPubspec(), contains('dependencies:\n  zuraffa: ^6.0.0\n'));
    });

    test(
      'an inline-empty dependencies mapping is expanded to block style',
      () async {
        await seedPubspec('''
name: repro_app
dependencies: {}
''');
        final result = await const PubspecZuraffaEnsure().ensure(tmp.path);

        expect(result.added, isTrue);
        expect(readPubspec(), contains('dependencies:\n  zuraffa: ^6.0.0\n'));
      },
    );
  });
}
