@Tags(['regression', 'slow'])
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_409_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Issue #409: provider must not drop NoParams from override', () {
    test(
      'provider from existing service keeps NoParams param (no invalid_override)',
      () async {
        final servicesDir = Directory('${outputDir}/domain/services')
          ..createSync(recursive: true);
        File('${servicesDir.path}/my_service.dart').writeAsStringSync(r'''
import 'package:zuraffa/zuraffa.dart';

abstract class MyService {
  Future<List<Item>> list(NoParams params);
}
''');

        final plugin = ProviderPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        );
        final config = GeneratorConfig(
          name: 'MyService',
          service: 'MyService',
          domain: 'my_domain',
          outputDir: outputDir,
          generateData: true,
          force: true,
        );

        final files = await plugin.generate(config);
        expect(files.length, equals(1));
        final content = File(files.first.path).readAsStringSync();

        // Positive: the parameter must be present.
        expect(
          content.contains('Future<List<Item>> list(NoParams params)'),
          isTrue,
          reason:
              'Provider override must include the NoParams params parameter',
        );
        // Negative: the bug produced a zero-arg signature that could not
        // validly override the service interface (invalid_override).
        expect(
          content.contains('Future<List<Item>> list()'),
          isFalse,
          reason: 'Provider must not generate a zero-arg list() signature',
        );
      },
    );
  });
}
