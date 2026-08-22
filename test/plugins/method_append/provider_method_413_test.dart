import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/method_append/builders/method_append_builder.dart';
import 'package:zuraffa/src/models/generator_config.dart';

/// Regression test for issue #413:
/// `zfa provider method` had three bugs vs. `zfa provider create`:
///   1. Double Future wrap — `--returns "Future<void>" --type usecase`
///      produced `Future<Future<void>>`.
///   2. Wrong inheritance — generated provider `extends BaseProvider` with
///      `@override` on a non-existent parent method, instead of
///      `implements <Service>`.
///   3. One-shot append — a second `provider method` call on the same target
///      was a silent no-op because `findFileImplementing` couldn't locate the
///      append-created provider (it extended BaseProvider, not the service).
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_413_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'provider method: no double Future wrap, implements service, repeatable append',
    () async {
      final builder = MethodAppendBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      // Mimics: zfa provider method --target EngineLoop \
      //   --name executeMission --returns "Future<void>" \
      //   --params MissionConfig --type usecase
      final first = GeneratorConfig(
        name: 'EngineLoop',
        service: 'EngineLoop',
        outputDir: outputDir,
        serviceMethod: 'executeMission',
        returnsType: 'Future<void>',
        paramsType: 'MissionConfig',
        useCaseType: 'usecase',
        appendToExisting: true,
        generateData: true,
      );

      final result = await builder.appendMethod(first);

      final providerFile = result.updatedFiles.firstWhere(
        (f) => f.type == 'provider' && f.action == 'created',
      );
      final content = await File(providerFile.path).readAsString();

      // Bug #1: single Future, not Future<Future<void>>.
      expect(
        content.contains('Future<Future<void>>'),
        isFalse,
        reason: 'double Future wrap detected',
      );
      expect(
        content.contains('Future<void> executeMission'),
        isTrue,
        reason: 'method should declare Future<void> return type',
      );

      // Bug #2: implements the service interface (mirrors `provider create`),
      // not `extends BaseProvider`.
      expect(
        content.contains('extends BaseProvider'),
        isFalse,
        reason: 'provider must not extend BaseProvider',
      );
      expect(
        content.contains('implements EngineLoopService'),
        isTrue,
        reason: 'provider must implement the service interface',
      );
      expect(
        content.contains('class EngineLoopProvider'),
        isTrue,
        reason: 'provider class name should match effectiveProvider',
      );

      // The service import must be emitted so `implements EngineLoopService`
      // resolves.
      expect(
        content.contains(
          "import '../../../domain/services/engine_loop_service.dart';",
        ),
        isTrue,
        reason: 'service import must be emitted',
      );

      // Bug #3: a second `provider method` call must append (not be a no-op).
      // Previously the append-created provider couldn't be found by
      // `findFileImplementing` because it extended BaseProvider.
      final second = GeneratorConfig(
        name: 'EngineLoop',
        service: 'EngineLoop',
        outputDir: outputDir,
        serviceMethod: 'abortMission',
        returnsType: 'void',
        paramsType: 'NoParams',
        useCaseType: 'usecase',
        appendToExisting: true,
        generateData: true,
      );

      final result2 = await builder.appendMethod(second);
      final providerUpdate = result2.updatedFiles.where(
        (f) => f.type == 'provider' && f.action == 'updated',
      );
      expect(
        providerUpdate,
        isNotEmpty,
        reason: 'second method append must update the existing provider',
      );

      final content2 = await File(providerFile.path).readAsString();
      expect(
        content2.contains('abortMission'),
        isTrue,
        reason: 'second method must be appended to the provider',
      );
      // The first method must still be present.
      expect(
        content2.contains('executeMission'),
        isTrue,
        reason: 'first method must survive the append',
      );
    },
  );

  test('provider method: stream return type is not double-wrapped', () async {
    final builder = MethodAppendBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final config = GeneratorConfig(
      name: 'Telemetry',
      service: 'Telemetry',
      outputDir: outputDir,
      serviceMethod: 'watchSignal',
      returnsType: 'Stream<int>',
      paramsType: 'NoParams',
      useCaseType: 'stream',
      appendToExisting: true,
      generateData: true,
    );

    final result = await builder.appendMethod(config);
    final providerFile = result.updatedFiles.firstWhere(
      (f) => f.type == 'provider' && f.action == 'created',
    );
    final content = await File(providerFile.path).readAsString();

    expect(
      content.contains('Stream<Stream<int>>'),
      isFalse,
      reason: 'double Stream wrap detected',
    );
    expect(
      content.contains('Stream<int> watchSignal'),
      isTrue,
      reason: 'method should declare Stream<int> return type',
    );
  });
}
