@Tags(['slow', 'regression'])
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/transaction/smart_merge/ast_diff.dart';
import 'package:zuraffa/src/core/transaction/smart_merge/declaration_scanner.dart';
import 'package:zuraffa/src/core/transaction/smart_merge/merge_orchestrator.dart';
import 'package:zuraffa/src/core/transaction/smart_merge/region_parser.dart';
import 'package:zuraffa/src/core/transaction/smart_merge_writer.dart';
import 'package:zuraffa/src/core/context/file_system.dart';

void main() {
  group('SmartMergeWriter', () {
    late Directory tempDir;
    late FileSystem fs;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('smart_merge_test_');
      fs = FileSystem.create(root: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates file when no existing content', () async {
      const newContent = 'class Foo { final int x; }';
      await SmartMergeWriter.writeMerged(
        fileSystem: fs,
        path: 'test.dart',
        newContent: newContent,
      );
      final result = await fs.read('test.dart');
      expect(result, contains('class Foo'));
    });

    test('merges when file exists with GENERATED markers', () async {
      final existing = '''// GENERATED - DO NOT EDIT
class \$Todo {
  final String title;
}
// END GENERATED

class TodoHelper { static String hi() => "hi"; }
''';
      await fs.write('test.dart', existing);

      final generated = '''// GENERATED - DO NOT EDIT
class \$Todo {
  final String title;
  final bool done;
}
// END GENERATED
''';

      await SmartMergeWriter.writeMerged(
        fileSystem: fs,
        path: 'test.dart',
        newContent: generated,
      );

      final result = await fs.read('test.dart');
      expect(result, contains('done'));
      expect(result, contains('TodoHelper'));
    });

    test('rethrows permission denied errors without overwriting', () async {
      // Regression test for Finding 2: permission errors should propagate
      final testFile = File('${tempDir.path}/readonly.dart');
      const originalContent = 'class Original {}';
      await testFile.writeAsString(originalContent);

      // Make file read-only (Platform-dependent, but works on Linux/Mac)
      if (!Platform.isWindows) {
        await Process.run('chmod', ['444', testFile.path]);

        await expectLater(
          () async => await SmartMergeWriter.writeMerged(
            fileSystem: fs,
            path: 'readonly.dart',
            newContent: 'class Modified {}',
          ),
          throwsA(isA<FileSystemException>()),
          reason: 'Permission errors should propagate, not be swallowed',
        );

        // Verify original file was not overwritten
        final content = await testFile.readAsString();
        expect(content, equals(originalContent));

        // Restore permissions for cleanup
        await Process.run('chmod', ['644', testFile.path]);
      }
    });
  });

  group('smart_merge review findings', () {
    test('scanner ignores braces inside string literals', () {
      const src = "class A {\n  String brace = '}';\n  int x = 0;\n}\n";
      final decls = extractDeclarationsFromSource(src);
      expect(decls, hasLength(1));
      expect(decls.first.name, 'A');
      // The class spans all four lines; the `'}'` on line 1 must not
      // terminate it early.
      expect(decls.first.endLine, 4);
    });

    test('scanner does not treat named-parameter braces as the body', () {
      const src =
          'String helper({\n'
          '  required String value,\n'
          '}) =>\n'
          '    value.trim();\n';
      final decls = extractDeclarationsFromSource(src);
      expect(decls, hasLength(1));
      expect(decls.first.name, 'helper');
      // The expression body ends at the `;` on line 3 (endLine 4).
      expect(decls.first.endLine, 4);
    });

    test('extractPreservedBlocks emits only the outermost block', () {
      const block =
          '// @preserve\n'
          'class A {\n'
          '  // @preserve\n'
          '  void inner() {}\n'
          '  // @end-preserve\n'
          '}\n'
          '// @end-preserve\n';
      final blocks = RegionParser.extractPreservedBlocks(block);
      expect(blocks, hasLength(1));
    });

    test('ast diff detects a top-level const change', () {
      const existing = 'class A {}\nconst schemaVersion = 1;\n';
      const generated = 'class A {}\nconst schemaVersion = 2;\n';
      final entries = AstDiff.diff(
        existingSource: existing,
        generatedSource: generated,
      );
      expect(entries, isNotEmpty);
    });

    test('merge writes a newline after a preserved region', () {
      const existing =
          '// @preserve\n'
          'int kept = 1;\n'
          '// @end-preserve\n'
          'class A {}\n';
      final result = MergeOrchestrator.merge(
        existingContent: existing,
        generatedContent: existing,
      );
      expect(result.content, isNot(contains('@end-preserveclass')));
      expect(result.content, contains('class A'));
      expect(result.content, contains('int kept = 1;'));
    });

    test('structural merge preserves user imports and top-level variables', () {
      const existing =
          "import 'dart:async';\n"
          '\n'
          'final customFlag = true;\n'
          '\n'
          'class \$Todo {\n'
          '  final String title;\n'
          '}\n';
      const generated =
          'class \$Todo {\n'
          '  final String title;\n'
          '  final bool done;\n'
          '}\n';
      final result = MergeOrchestrator.merge(
        existingContent: existing,
        generatedContent: generated,
      );
      expect(result.content, contains("import 'dart:async';"));
      expect(result.content, contains('customFlag'));
      expect(result.content, contains('done'));
    });

    test(
      'ast diff detects indentation change inside a triple-quoted string',
      () {
        // Two vs four leading spaces on a triple-quoted payload line must
        // register as a change (CodeRabbit ast_diff.dart:157).
        const existing =
            'class A {}\n'
            'const banner = """\n'
            '  hello\n'
            '""";\n';
        const generated =
            'class A {}\n'
            'const banner = """\n'
            '    hello\n'
            '""";\n';
        final entries = AstDiff.diff(
          existingSource: existing,
          generatedSource: generated,
        );
        expect(entries, isNotEmpty);
      },
    );

    test('scanner flags a declaration sharing its line with another', () {
      const src = 'class A {} class User {}\n';
      final decls = extractDeclarationsFromSource(src);
      expect(decls, hasLength(1));
      expect(decls.first.name, 'A');
      expect(decls.first.unsafeLineReplace, isTrue);
    });

    test(
      'scanner scans an arrow body through to its terminating semicolon',
      () {
        // The set literal braces belong to the expression body, not a block
        // body (CodeRabbit declaration_scanner.dart:258).
        const src =
            'Set<int> values() => <int>{\n'
            '  1,\n'
            '  2,\n'
            '}.union({2});\n';
        final decls = extractDeclarationsFromSource(src);
        expect(decls, hasLength(1));
        expect(decls.first.name, 'values');
        // Ends at the `;` on line 3 (endLine 4).
        expect(decls.first.endLine, 4);
      },
    );

    test(
      'structural merge reports a conflict for a shared-line declaration',
      () {
        const existing = 'class A {} class User {}\n';
        const generated = 'class A {\n  int x = 0;\n}\n';
        final result = MergeOrchestrator.merge(
          existingContent: existing,
          generatedContent: generated,
        );
        // The neighbour `User` must survive, and a conflict is reported.
        expect(result.conflicts, isNotEmpty);
        expect(result.content, contains('class User'));
      },
    );

    test(
      'structural merge injects a generated import the existing file lacks',
      () {
        const existing =
            'class \$Todo {\n'
            '  final String title;\n'
            '}\n';
        const generated =
            "import 'support.dart';\n"
            '\n'
            'class \$Todo {\n'
            '  final Helper? helper;\n'
            '}\n';
        final result = MergeOrchestrator.merge(
          existingContent: existing,
          generatedContent: generated,
        );
        expect(result.content, contains("import 'support.dart';"));
        expect(result.content, contains('helper'));
      },
    );

    test('region parser ignores markers inside a triple-quoted string', () {
      // A marker-looking line inside a string is not a region
      // (CodeRabbit region_parser.dart:50).
      const src =
          'const doc = """\n'
          '// GENERATED - DO NOT EDIT\n'
          'class Fake {}\n'
          '// END GENERATED\n'
          '""";\n';
      final regions = RegionParser.parse(src);
      expect(regions, isEmpty);
    });

    test('malformed crossing markers are detected', () {
      // preserve opens and closes across a generated boundary without
      // proper nesting (CodeRabbit region_parser.dart:65).
      const src =
          '// GENERATED - DO NOT EDIT\n'
          '// @preserve\n'
          '// END GENERATED\n'
          '// @end-preserve\n';
      expect(RegionParser.hasMalformedMarkers(src), isTrue);
      final result = MergeOrchestrator.merge(
        existingContent: src,
        generatedContent: '// GENERATED - DO NOT EDIT\nclass A {}\n',
      );
      expect(result.conflicts, isNotEmpty);
      expect(result.hasChanges, isFalse);
    });

    test('merge strategy does not duplicate a sole generated block', () {
      // Two existing generated regions for A and B, but the generator
      // returns only A: B keeps its region and a conflict is reported
      // (CodeRabbit merge_strategy.dart:169).
      const existing =
          '// GENERATED - DO NOT EDIT\n'
          'class A {}\n'
          '// END GENERATED\n'
          '// GENERATED - DO NOT EDIT\n'
          'class B {}\n'
          '// END GENERATED\n';
      const generated =
          '// GENERATED - DO NOT EDIT\n'
          'class A {\n  int x = 0;\n}\n'
          '// END GENERATED\n';
      final result = MergeOrchestrator.merge(
        existingContent: existing,
        generatedContent: generated,
      );
      // A is updated, B survives, no duplicate A.
      final aCount = 'class A'.allMatches(result.content).length;
      expect(aCount, 1);
      expect(result.content, contains('class B'));
    });
  });
}
