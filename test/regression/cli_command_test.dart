import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/project_root.dart';

void main() {
  group('CLI command regression', () {
    late Directory workspace;
    late String outputDir;
    late String previousCwd;

    Future<void> writeWorkspacePubspec() {
      return File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_cli_test
environment:
  sdk: ^3.11.0
''');
    }

    Future<void> writeProductEntity() async {
      final entityDir = Directory(
        p.join(outputDir, 'domain', 'entities', 'product'),
      );
      await entityDir.create(recursive: true);
      await File(p.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');
    }

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_cli_');
      outputDir = p.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await writeWorkspacePubspec();
      await writeProductEntity();
      previousCwd = Directory.current.path;
      Directory.current = workspace.path;
    });

    tearDown(() async {
      Directory.current = previousCwd;
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test('cli make from flags creates output', () async {
      final runner = CliRunner(exitOnCompletion: false);

      await runner.run([
        'make',
        'Product',
        '--preset=crud',
        '--output',
        outputDir,
        '--force',
      ]);

      expect(
        File(
          '$outputDir/domain/repositories/product_repository.dart',
        ).existsSync(),
        isTrue,
      );
    });

    test('cli make from json keeps config format', () async {
      final configFile = File(p.join(workspace.path, 'config.json'));
      await configFile.writeAsString(
        jsonEncode({
          'name': 'Product',
          'preset': 'crud',
          'with': ['data'],
        }),
      );

      final runner = CliRunner(exitOnCompletion: false);
      await runner.run([
        'make',
        '--from-json',
        configFile.path,
        '--output',
        outputDir,
        '--force',
      ]);

      expect(
        File(
          '$outputDir/domain/repositories/product_repository.dart',
        ).existsSync(),
        isTrue,
      );
    });

    test('cli plugin list prints available plugins', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(['plugin', 'list']);

      expect(output, contains('repository'));
      expect(output, contains('usecase'));
    });

    test('removed generate command prints migration guidance', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(['generate', 'Product']);

      expect(
        output,
        contains("The 'generate' command was removed in Zuraffa v5"),
      );
      expect(output, contains('zfa make <Name>'));
    });

    test('cli help lists make as canonical command', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([]);

      expect(output, contains('make <Name>'));
      expect(output, contains('feature <Name>'));
      expect(output, isNot(contains('generate <Name>')));
    });
  });

  group('Project root resolution regression', () {
    test(
      'find resolves project root from nested lib/src/domain/entities/product/ directory',
      () async {
        final workspace = await Directory.systemTemp.createTemp(
          'zfa_root_nested_',
        );
        try {
          await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: test_nested
environment:
  sdk: ^3.11.0
''');
          final nestedDir = Directory(
            p.join(
              workspace.path,
              'lib',
              'src',
              'domain',
              'entities',
              'product',
            ),
          );
          await nestedDir.create(recursive: true);

          final result = ProjectRoot.find(startPath: nestedDir.path);
          expect(result, equals(workspace.path));
        } finally {
          if (workspace.existsSync()) {
            await workspace.delete(recursive: true);
          }
        }
      },
    );

    test('find resolves from CWD when no startPath given', () async {
      final workspace = await Directory.systemTemp.createTemp('zfa_root_cwd_');
      final savedCwd = Directory.current.path;
      try {
        await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: test_cwd
environment:
  sdk: ^3.11.0
''');
        Directory.current = workspace.path;

        final result = ProjectRoot.find();
        final resolvedWorkspace = await Directory(
          workspace.path,
        ).resolveSymbolicLinks();
        expect(result, equals(resolvedWorkspace));
      } finally {
        Directory.current = savedCwd;
        if (workspace.existsSync()) {
          await workspace.delete(recursive: true);
        }
      }
    });

    test('find returns startPath when no pubspec.yaml found', () async {
      final emptyDir = await Directory.systemTemp.createTemp(
        'zfa_root_nopubspec_',
      );
      try {
        final result = ProjectRoot.find(startPath: emptyDir.path);
        // Should return the normalized absolute start path when no pubspec found
        expect(p.normalize(p.absolute(emptyDir.path)), equals(result));
      } finally {
        if (emptyDir.existsSync()) {
          await emptyDir.delete(recursive: true);
        }
      }
    });

    test('findOrThrow throws when root does not exist', () async {
      final nonExistent = p.join(
        Directory.systemTemp.path,
        'zfa_root_ghost_${DateTime.now().millisecondsSinceEpoch}',
      );

      expect(
        () => ProjectRoot.findOrThrow(startPath: nonExistent),
        throwsA(isA<StateError>()),
      );
    });

    test('find handles deleted CWD gracefully', () async {
      final ghostDir = await Directory.systemTemp.createTemp(
        'zfa_root_ghost_cwd_',
      );
      final savedCwd = Directory.current.path;
      try {
        Directory.current = ghostDir.path;
        await ghostDir.delete(recursive: true);

        // Directory.current itself throws when CWD is deleted;
        // ProjectRoot.find() accesses Directory.current before it can recover.
        expect(() => ProjectRoot.find(), throwsA(isA<PathNotFoundException>()));
      } finally {
        Directory.current = savedCwd;
      }
    });
  });
}
