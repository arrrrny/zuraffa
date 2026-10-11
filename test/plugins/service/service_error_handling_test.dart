import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/service/capabilities/create_service_capability.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';
import 'package:zuraffa/src/zfa_cli.dart' as cli;

/// SPEC 1127, order 4 — real verdicts, never uncaught exceptions.
///
/// The entire CreateServiceCapability.execute() path is wrapped in
/// try/catch (the di/repository pattern, spec 0974 order 4): a malformed
/// entity or any generation failure surfaces as
/// `ExecutionResult(success: false, ...)` — not a thrown error through the
/// MCP/capability boundary, not a stack-trace crash on the CLI.
void main() {
  late Directory workspace;
  late String outputDir;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_service_err_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_service_err_test
environment:
  sdk: ^3.11.0
''');
    exitCode = 0;
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  group('CreateServiceCapability.execute error handling', () {
    test(
      'malformed entity (non-string name) → success:false, not a throw',
      () async {
        final plugin = ServicePlugin(outputDir: outputDir);
        final capability = CreateServiceCapability(
          plugin,
          projectRoot: workspace.path,
        );

        // A JSON/MCP caller can smuggle a non-string name through the
        // capability boundary — before the fix this escaped as an uncaught
        // TypeError out of execute().
        Object? caught;
        Object? result;
        try {
          result = await capability.execute({
            'name': 12345,
            'params': 'NoParams',
          });
        } catch (e) {
          caught = e;
        }

        expect(
          caught,
          isNull,
          reason:
              'execute() must never propagate an exception (di/repository '
              'pattern) — got: $caught',
        );
        expect(result, isA<dynamic>());
        final exec = result as dynamic;
        expect(exec.success, isFalse);
        expect(
          (exec.message as String).contains('service create failed'),
          isTrue,
          reason: 'the failure must name the verb and the cause',
        );
      },
    );

    test('CLI malformed entity → structured verdict, no stack trace', () async {
      final output = await cli.runCapturing([
        '-C',
        workspace.path,
        'service',
        'create',
        '--name',
        'Bad Entity Name!!',
        '--json',
      ]);

      expect(output, isNot(contains('Unhandled exception')));
      expect(
        output,
        isNot(contains('TypeError')),
        reason: 'structured failure, not a leaked crash: $output',
      );
      // Either a usage refusal or a fail envelope — both are verdicts.
      expect(
        output.contains('--> fix:') || output.contains('zuraffa.verdict.v1'),
        isTrue,
      );
      expect(exitCode, isNot(equals(0)));
    });
  });
}
