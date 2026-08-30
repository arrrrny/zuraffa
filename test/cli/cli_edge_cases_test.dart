@Tags(['slow'])

import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../helpers/run_zfa_source.dart';

void main() {
  setUpAll(() async {
    // Resolves the zfa binary path via the CWD-independent package resolver
    // (Isolate.resolvePackageUri). This avoids the fragile Directory.current
    // capture that breaks under parallel `dart test` when another file mutates
    // the process working directory (issue #506).
    await initZfaSourceBin();
  });

  group('CLI Edge Cases', () {
    late Directory workspace;
    late String outputDir;

    Future<ProcessResult> runZfa(List<String> args) {
      return runZfaSource(args, workingDirectory: zfaProjectRoot);
    }

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_edge_');
      outputDir = p.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_edge_test
environment:
  sdk: ^3.11.0
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      'make handles missing JSON config file',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'make',
          'Product',
          '--from-json=/nonexistent/config.json',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, isNot(equals(0)));
        final output = combinedOutput(result);
        expect(output.toLowerCase(), contains('json file not found'));
      },
    );

    test(
      'make handles invalid JSON structure from file',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final configFile = File(p.join(workspace.path, 'config.json'));
        await configFile.writeAsString('{invalid json}');

        final result = await runZfa([
          'make',
          'Product',
          '--from-json',
          configFile.path,
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, isNot(equals(0)));
        final output = combinedOutput(result);
        expect(output, contains('Error parsing JSON input'));
      },
    );

    test(
      'make shows usage when name and JSON input are missing',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa(['make']);

        expect(result.exitCode, isNot(equals(0)));
        final output = combinedOutput(result);
        expect(output, contains('Usage: zfa make'));
      },
    );

    test(
      'removed generate command fails fast with migration guidance',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa(['generate', 'Product']);

        expect(result.exitCode, isNot(equals(0)));
        final output = combinedOutput(result);
        expect(
          output,
          contains("The 'generate' command was removed in Zuraffa v5"),
        );
        expect(output, contains('zfa make <Name>'));
      },
    );
  });
}
