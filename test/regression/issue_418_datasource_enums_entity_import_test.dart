@Tags(['regression', 'slow'])
// Regression test for issue #418:
// https://github.com/arrrrny/zuraffa/issues/418
//
// `zfa make` / `zfa datasource create` used to emit an entity import such as
// `import '../../../domain/entities/enums/enums.dart'` unconditionally for an
// entity named `Enums` (or any entity whose file does not exist yet). Because
// the `Enums` entity is never created by any entity command, that URI did not
// exist and `dart analyze` reported `uri_does_not_exist` for every generated
// datasource / use case file.
//
// The fix only emits the entity import when the referenced entity file
// actually exists, so generation no longer produces dangling references to
// non-existent entities.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_issue_418_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('issue #418 — datasource generation must not reference non-existent '
      'Enums entity', () {
    test(
      'no entity import is emitted when the Enums entity file does not exist',
      () async {
        final plugin = DataSourcePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
        );

        // Entity-based config for a name that collides with the `enums`
        // directory (`Enums` -> snake `enums`). Crucially we do NOT scaffold
        // the entity file, mirroring the bug where the entity is never created.
        final config = GeneratorConfig(
          name: 'Enums',
          methods: const ['get'],
          outputDir: outputDir,
          generateDataSource: true,
          generateRemote: true,
          generateLocal: true,
        );

        final files = await plugin.generate(config);
        expect(files, isNotEmpty,
            reason: 'datasource files should still be generated');

        for (final file in files) {
          final generated = File(file.path);
          expect(generated.existsSync(), isTrue);
          final content = generated.readAsStringSync();
          expect(
            content.contains('domain/entities/enums/enums.dart'),
            isFalse,
            reason: 'generated ${file.path} must not reference a '
                'non-existent enums/enums.dart entity',
          );
        }
      },
    );

    test(
      'entity import is still emitted when the entity file exists',
      () async {
        // Scaffold the real entity file so the import should resolve.
        final entityDir =
            Directory('$outputDir/domain/entities/enums')..createSync(recursive: true);
        File('${entityDir.path}/enums.dart')
            .writeAsStringSync('class Enums {}');

        final plugin = DataSourcePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
        );

        final config = GeneratorConfig(
          name: 'Enums',
          methods: const ['get'],
          outputDir: outputDir,
          generateDataSource: true,
          generateRemote: true,
          generateLocal: true,
        );

        final files = await plugin.generate(config);
        expect(files, isNotEmpty);

        final anyHasImport = files.any((file) {
          final content = File(file.path).readAsStringSync();
          return content.contains('domain/entities/enums/enums.dart');
        });
        expect(anyHasImport, isTrue,
            reason: 'when the entity exists, the import should be emitted');
      },
    );
  });
}
