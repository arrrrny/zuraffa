import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/method_append/capabilities/method_capability.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

/// Regression test for issue #414:
/// `zfa service method` was silent on success — it produced no console output
/// even though the sibling `provider create` / `usecase create` commands print
/// `✅ Success! Created/Modified: ...`.
///
/// Root cause: append-family capabilities (like `service method`) mutate an
/// existing host file in place and emit `GeneratedFile`s with the `updated`
/// action. `CapabilityCommand.run` only printed the success summary for
/// `created` / `overwritten` / `deleted` actions, so `updated` files were
/// silently dropped and the command produced no output.
///
/// This test exercises the real `ServicePlugin` + `MethodCapability` (service
/// targetType) and asserts both that `execute` populates `generatedFiles` with
/// a handled action and that the `CapabilityCommand` success printer emits the
/// `✅ Success! Created/Modified:` message.
const String _servicesRelPath = 'domain/services';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_414_test_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    final servicesDir = Directory('$outputDir/$_servicesRelPath');
    await servicesDir.create(recursive: true);
    await File('${servicesDir.path}/my_service.dart').writeAsString('''
abstract class MyService {
  Future<void> existingMethod();
}
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  MethodCapability serviceMethodCapability() {
    final plugin = ServicePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true, verbose: false),
    );
    return plugin.capabilities.firstWhere((c) => c is MethodCapability)
        as MethodCapability;
  }

  test(
    'service method: execute populates generatedFiles with a handled action',
    () async {
      final capability = serviceMethodCapability();

      final result = await capability.execute({
        'target': 'MyService',
        'name': 'doThing',
        'returns': 'void',
        'params': 'String',
        'type': 'sync',
      });

      expect(result.success, isTrue);
      final files = result.data?['generatedFiles'] as List?;
      expect(files, isNotNull);
      expect(files!, isNotEmpty);

      final serviceFile = files.firstWhere(
        (f) => f.path.contains('my_service.dart'),
      );
      // The action must be one the success printer handles, otherwise the
      // command prints nothing (issue #414).
      expect(serviceFile.action, equals('updated'));
    },
  );

  test(
    'service method: CapabilityCommand emits success output (issue #414)',
    () async {
      final capability = serviceMethodCapability();
      final command = CapabilityCommand(capability);
      final runner = CommandRunner<void>('test', 'test')..addCommand(command);

      await expectLater(
        () => runner.run([
          'method',
          '--target',
          'MyService',
          '--name',
          'doThing',
          '--returns',
          'void',
          '--params',
          'String',
          '--type',
          'sync',
        ]),
        prints(
          allOf(
            contains('✅ Success! Created/Modified:'),
            contains('my_service.dart'),
          ),
        ),
      );

      // Sanity: the method was actually appended to the host file.
      final content = await File(
        '$outputDir/$_servicesRelPath/my_service.dart',
      ).readAsString();
      expect(content, contains('doThing'));
    },
  );
}
