@Tags(['regression', 'slow'])

library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/method_append/builders/method_append_builder.dart';

/// Regression guard for issue #409 on the `method_append` path.
///
/// The provider-create path is already guarded by
/// `issue_409_provider_noparams_override_guard_test.dart`. This test covers the
/// other half of the reported reproduction — `zfa provider method ... --params
/// NoParams`, which creates both the service interface and the provider through
/// [MethodAppendBuilder]. Both signatures must carry `NoParams params`; a
/// zero-arg provider method would be an `invalid_override` of the service.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_409_append_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'provider method with NoParams emits matching service and provider signatures',
    () async {
      final builder = MethodAppendBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      // Mimics: zfa provider method --target MyService --name list \
      //   --params NoParams --returns "List<Item>"
      final result = await builder.appendMethod(
        GeneratorConfig(
          name: 'MyService',
          service: 'MyService',
          outputDir: outputDir,
          serviceMethod: 'list',
          returnsType: 'List<Item>',
          paramsType: 'NoParams',
          useCaseType: 'usecase',
          appendToExisting: true,
          generateData: true,
        ),
      );

      final serviceFile = result.updatedFiles.firstWhere(
        (f) => f.type == 'service',
        orElse: () => fail('no service file was generated'),
      );
      final serviceContent = await File(serviceFile.path).readAsString();
      expect(
        serviceContent.contains('Future<List<Item>> list(NoParams params)'),
        isTrue,
        reason: 'service interface must declare the NoParams parameter',
      );

      final providerFile = result.updatedFiles.firstWhere(
        (f) => f.type == 'provider',
        orElse: () => fail('no provider file was generated'),
      );
      final providerContent = await File(providerFile.path).readAsString();
      expect(
        providerContent.contains('Future<List<Item>> list(NoParams params)'),
        isTrue,
        reason: 'provider override must include the NoParams parameter',
      );
      // Match a zero-arg *declaration* only: a bare `list()` substring would
      // also match a delegating call inside the method body.
      expect(
        RegExp(r'Future<List<Item>>\s+list\(\s*\)').hasMatch(providerContent),
        isFalse,
        reason:
            'a zero-arg override is an invalid_override of the service method',
      );
    },
  );
}
