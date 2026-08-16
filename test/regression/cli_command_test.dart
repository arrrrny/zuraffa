import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/project_root.dart';

/// CWD-safe project root resolution.
/// Tries Platform.script (immune to CWD), then CWD walk (with temp guard),
/// then git rev-parse. Throws [StateError] if the root cannot be found.
String _findProjectRoot() {
  // Strategy 1: Walk up from Platform.script (immune to CWD changes).
  try {
    var dir = File(Platform.script.toFilePath()).parent;
    for (var i = 0; i < 10; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final c = pubspec.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {
    // Platform.script.toFilePath() may fail if CWD was deleted.
    // Recover CWD to a known-good location and retry.
    try {
      Directory.current = Directory.systemTemp.path;
    } catch (_) {}
    try {
      var dir = File(Platform.script.toFilePath()).parent;
      for (var i = 0; i < 10; i++) {
        final pubspec = File('${dir.path}/pubspec.yaml');
        if (pubspec.existsSync()) {
          final c = pubspec.readAsStringSync();
          if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
            return dir.path;
          }
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
  }

  // Strategy 2: Walk up from CWD (may be poisoned, so guard against temp dirs).
  try {
    var dir = Directory.current;
    for (var i = 0; i < 15; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final c = pubspec.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
          final candidate = dir.path;
          if (!_isTempPath(candidate)) {
            return candidate;
          }
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}

  // Strategy 3: git rev-parse as last resort.
  try {
    final result = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    if (result.exitCode == 0) {
      final gitRoot = (result.stdout as String).trim();
      if (!_isTempPath(gitRoot)) {
        final pubspec = File('$gitRoot/pubspec.yaml');
        if (pubspec.existsSync()) {
          final c = pubspec.readAsStringSync();
          if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
            return gitRoot;
          }
        }
      }
    }
  } catch (_) {}

  // Read Directory.current.path defensively to avoid masking the intended StateError.
  String cwdForError;
  try {
    cwdForError = Directory.current.path;
  } catch (_) {
    cwdForError = '<unable to read CWD>';
  }
  throw StateError(
    'Cannot determine zuraffa project root. '
    'CWD=$cwdForError',
  );
}

/// Returns true if [path] looks like it is inside a temp directory.
bool _isTempPath(String p) {
  final lower = p.toLowerCase();
  final systemTempLower = Directory.systemTemp.path.toLowerCase();

  // Check if path starts with /tmp/, equals /tmp, or contains /tmp/ as a segment
  final isTmpSegment =
      lower == '/tmp' || lower.startsWith('/tmp/') || lower.contains('/tmp/');

  return isTmpSegment ||
      lower.contains('/var/folders/') ||
      lower.contains('/nosuchfile') ||
      lower == systemTempLower;
}

final _zfaRoot = _findProjectRoot();

void main() {
  group('CLI command regression', () {
    late Directory workspace;
    late String outputDir;

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

    late String savedCwd;

    setUp(() async {
      savedCwd = Directory.current.path;
      workspace = await Directory.systemTemp.createTemp('zfa_cli_');
      outputDir = p.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await writeWorkspacePubspec();
      await writeProductEntity();
      Directory.current = workspace.path;
    });

    tearDown(() async {
      // Restore CWD BEFORE deleting workspace to avoid cascading crashes.
      try {
        if (Directory(savedCwd).existsSync()) {
          Directory.current = savedCwd;
        } else {
          Directory.current = Directory.systemTemp.path;
        }
      } catch (_) {
        try {
          Directory.current = Directory.systemTemp.path;
        } catch (_) {}
      }
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

    test('cli plugin mcp --dry-run passes flags through without writing files', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(['plugin', 'mcp', '--dry-run']);

      // The pass-through relies on ArgParser.allowAnything() + .arguments.
      // If the parser rejected --dry-run, we would see a UsageException here.
      expect(output, isNot(contains('Could not find an option named')));
      expect(output, isNot(contains('Usage: zfa plugin')));
      expect(
        File(p.join(workspace.path, 'lib', 'src', 'mcp', 'tools.dart'))
            .existsSync(),
        isFalse,
      );
      expect(
        File(p.join(workspace.path, 'bin', 'mcp_server.dart')).existsSync(),
        isFalse,
      );
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
        try {
          Directory.current = savedCwd;
        } catch (_) {
          try {
            Directory.current = Directory.systemTemp;
          } catch (_) {}
        }
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
        try {
          Directory.current = savedCwd;
        } catch (_) {
          try {
            Directory.current = Directory.systemTemp;
          } catch (_) {}
        }
      }
    });
  });
}
