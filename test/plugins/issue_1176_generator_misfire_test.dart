// Issue #1176 — two generator defects on the full CRUD preset:
//
// 1. every di GROUP index got the #1102 `resetDependencies` hook injected
//    (fixed name), so `di/index.dart`'s re-exports collided
//    (ambiguous_export). The hook belongs to the composition root only.
// 2. the test plugin's `_ensureNativeMockInfra` wrote force:true
//    placeholders even when the same run generates the mock stack, and
//    the placeholder survived — `implements ProductDataSource` with no
//    import.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/builders/registration_builder.dart';
import 'package:code_builder/code_builder.dart';
import 'package:zuraffa/src/plugins/test/test_plugin.dart';

void main() {
  group('issue #1176-1 — reset hook is composition-root only', () {
    // The group emission path (buildIndexFile for 'registerAll*') only
    // ever emits the uniquely-named reset (resetRegisterAllUseCases);
    // the fixed-name resetDependencies is the composition root's.
    test('a group index stays reset-free of the fixed-name hook', () {
      final src = const RegistrationBuilder().buildIndexFile(
        functionName: 'registerAllUseCases',
        registrations: [refer('registerAllProductUseCases').call([refer('getIt')]).statement],
      );
      expect(src, contains('resetregisterAllUseCases'));
      expect(src, isNot(contains('void resetDependencies(')));
    });

    test('the composition root keeps resetDependencies', () {
      final src = const RegistrationBuilder().buildIndexFile(
        functionName: 'setupDependencies',
        registrations: [refer('setupProductDependencies').call([refer('getIt')]).statement],
      );
      expect(src, contains('void resetDependencies('));
    });
  });

  group('issue #1176-2 — no placeholders when the run owns the mock stack', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zfa_1176_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test(
      'generateTest + generateMock writes NO placeholder mock datasource',
      () async {
        final plugin = TestPlugin(
          outputDir: tempDir.path,
          options: const GeneratorOptions(dryRun: true),
        );
        await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get'],
            generateTest: true,
            generateMock: true,
            generateDataSource: true,
            outputDir: tempDir.path,
          ),
        );
        final placeholder = File(
          '${tempDir.path}/data/datasources/product/product_mock_datasource.dart',
        );
        expect(
          placeholder.existsSync(),
          isFalse,
          reason:
              'the mock generators own this file in this run; a '
              'force:true placeholder racing them leaves non-compiling '
              'output',
        );
      },
    );
  });
}
