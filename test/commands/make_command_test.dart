import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/cli/cli_runner.dart';

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
      final compiledBin = path.join(homeDir, '.pub-cache', 'bin', 'zfa');
      final compiledExists = File(compiledBin).existsSync();

      if (compiledExists) {
        zfaBin = compiledBin;
        useCompiledBinary = true;
      } else {
        zfaBin = File('bin/zfa.dart').absolute.path;
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
      Directory.current = previousCwd;
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
        final decoded = jsonDecode(stdoutOutput) as Map<String, dynamic>;
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
