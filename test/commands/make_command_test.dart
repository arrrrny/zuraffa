import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/cli/cli_runner.dart';

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
    try { Directory.current = Directory.systemTemp.path; } catch (_) {}
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
  final isTmpSegment = lower == '/tmp' ||
                       lower.startsWith('/tmp/') ||
                       lower.contains('/tmp/');

  return isTmpSegment ||
      lower.contains('/var/folders/') ||
      lower.contains('/nosuchfile') ||
      lower == systemTempLower;
}


void main() {
  group('MakeCommand', () {
    late Directory workspace;
    late String outputDir;
    late String previousCwd;
    late String zfaBin;
    late bool useCompiledBinary;

    Future<Process> startZfa(
      List<String> args, {
      required String workingDirectory,
    }) {
      if (useCompiledBinary) {
        return Process.start(zfaBin, args, workingDirectory: workingDirectory);
      }

      return Process.start('dart', [
        zfaBin,
        ...args,
      ], workingDirectory: workingDirectory);
    }

    setUpAll(() {
      final homeDir = Platform.environment['HOME'] ?? '';
      final compiledBin = path.join(homeDir, '.local', 'bin', 'zfa');
      final compiledExists = File(compiledBin).existsSync();

      if (compiledExists) {
        zfaBin = compiledBin;
        useCompiledBinary = true;
      } else {
        // Resolve bin/zfa.dart relative to the project root, NOT CWD.
        // CWD may be a temp dir from another test at setUpAll time.
        final projectRoot = _findProjectRoot();
        zfaBin = path.join(projectRoot, 'bin', 'zfa.dart');
        useCompiledBinary = false;
      }
    });

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_make_command_');
      outputDir = path.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_make_test
environment:
  sdk: ^3.11.0
''');
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'product'),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');
      previousCwd = Directory.current.path;
      Directory.current = workspace.path;
    });

    tearDown(() async {
      if (Directory(previousCwd).existsSync()) {
        Directory.current = previousCwd;
      }
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test('supports --format=json with --plan', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        'make',
        'Product',
        '--preset=crud',
        '--with=vpc',
        '--plan',
        '--format=json',
        '--output',
        outputDir,
      ]);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      final plan = decoded['plan'] as Map<String, dynamic>;
      expect(
        (plan['plugin_ids'] as List).cast<String>(),
        containsAll([
          'usecase',
          'repository',
          'datasource',
          'view',
          'presenter',
          'controller',
        ]),
      );
    });

    test('supports --from-json for plan resolution', () async {
      final configFile = File(path.join(workspace.path, 'make_config.json'));
      await configFile.writeAsString(
        jsonEncode({
          'name': 'Product',
          'preset': 'crud',
          'with': ['vpc'],
        }),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        'make',
        '--from-json',
        configFile.path,
        '--plan',
        '--format=json',
        '--output',
        outputDir,
      ]);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      final plan = decoded['plan'] as Map<String, dynamic>;
      expect(plan['preset'], 'crud');
      expect((plan['plugin_ids'] as List).cast<String>(), contains('usecase'));
    });

    test('supports explicit exclusions and negation over defaults', () async {
      await File(path.join(workspace.path, '.zfa.json')).writeAsString(
        jsonEncode({
          'plugins': {
            'defaults': {'di': true, 'route': true},
          },
        }),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        'make',
        'Product',
        '--preset=crud',
        '--with=controller',
        '--without=route',
        '--no-controller',
        '--plan',
        '--format=json',
        '--output',
        outputDir,
      ]);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      final plan = decoded['plan'] as Map<String, dynamic>;
      final pluginIds = (plan['plugin_ids'] as List).cast<String>();
      expect(pluginIds, contains('di'));
      expect(pluginIds, isNot(contains('route')));
      expect(pluginIds, isNot(contains('controller')));
    });

    test(
      'supports --from-stdin for plan resolution',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final process = await startZfa([
          'make',
          '--from-stdin',
          '--plan',
          '--format=json',
          '--output',
          outputDir,
        ], workingDirectory: previousCwd);

        process.stdin.writeln(
          jsonEncode({
            'name': 'Product',
            'preset': 'crud',
            'with': ['vpc'],
          }),
        );
        await process.stdin.close();

        final stdoutOutput = await process.stdout
            .transform(utf8.decoder)
            .join();
        final stderrOutput = await process.stderr
            .transform(utf8.decoder)
            .join();
        final exitCode = await process.exitCode;

        expect(exitCode, equals(0), reason: stderrOutput);

        final jsonMatch = RegExp(
          r'\{.*"success".*\}',
          dotAll: true,
        ).firstMatch(stdoutOutput);
        expect(
          jsonMatch,
          isNotNull,
          reason: 'No JSON found in stdout: $stdoutOutput',
        );
        final decoded =
            jsonDecode(jsonMatch!.group(0)!) as Map<String, dynamic>;
        expect(decoded['success'], isTrue);
        final plan = decoded['plan'] as Map<String, dynamic>;
        expect(plan['preset'], 'crud');
        expect(
          (plan['plugin_ids'] as List).cast<String>(),
          contains('repository'),
        );
      },
    );
  });
}
