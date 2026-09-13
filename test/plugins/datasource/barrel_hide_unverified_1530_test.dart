// Issue #1530 (U1/FR-004): the generated datasource + mock emission
// paths must NOT attach a `hide` combinator naming symbols the imported
// framework barrel never verifiably exports. With an unresolvable barrel
// surface (the dogfood state: a target whose package config has no
// `zuraffa` entry at generation start) the combinator is dropped
// entirely — `hide Task, TaskPatch` was the exact `undefined_hidden_name`
// warning class that failed `zfa build`'s own analyze gate.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/builders/local_generator.dart';
import 'package:zuraffa/src/plugins/datasource/builders/remote_generator.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_datasource_builder.dart';
import 'package:zuraffa/src/utils/zuraffa_barrel_exports.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    // The #1530 unverified-hide precondition: NO barrel seed. The
    // filter cannot verify ANY name, so the emitted imports must carry
    // no `hide` combinator at all (FR-001 — the legacy keep-all
    // fallback is removed).
    ZuraffaBarrelExports.reset();
    tempDir = await Directory.systemTemp.createTemp('zuraffa_1530_hide_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    // Faithful dogfood precondition: the entity file exists BEFORE the
    // datasource emission runs (the datasource builders resolve the
    // entity import and then hide the entity's symbols from the barrel).
    final entityFile = File(
      '${tempDir.path}/lib/src/domain/entities/task/task.dart',
    );
    entityFile.parent.createSync(recursive: true);
    entityFile.writeAsStringSync('class Task {}\nclass TaskPatch {}\n');
  });

  tearDown(() async {
    ZuraffaBarrelExports.reset();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  GeneratorConfig taskConfig(String outputDir) => GeneratorConfig(
        name: 'Task',
        methods: const ['get', 'getList'],
        generateLocal: true,
        outputDir: outputDir,
      );

  test('local datasource emission drops the unverified hide combinator',
      () async {
    final builder = LocalDataSourceBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final file = await builder.generate(taskConfig(outputDir));
    final content = File(file.path).readAsStringSync();

    expect(
      content.contains('hide Task'),
      isFalse,
      reason:
          '#1530: Task/TaskPatch are not zuraffa exports — an unresolved '
          'barrel must drop the combinator instead of emitting '
          '`hide Task, TaskPatch` (undefined_hidden_name):\n$content',
    );
    expect(
      content.contains("import 'package:zuraffa/zuraffa.dart';"),
      isTrue,
      reason: 'the bare framework import must be emitted unchanged',
    );
  });

  test('remote datasource emission drops the unverified hide combinator',
      () async {
    final builder = RemoteDataSourceBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final file = await builder.generate(taskConfig(outputDir));
    final content = File(file.path).readAsStringSync();

    expect(content.contains('hide Task'), isFalse, reason: '#1530');
    expect(
      content.contains("import 'package:zuraffa/zuraffa.dart';"),
      isTrue,
    );
  });

  test('mock datasource emission drops the unverified hide combinator',
      () async {
    final builder = MockDataSourceBuilder(outputDir: outputDir);

    final file =
        await builder.generateMockDataSource(taskConfig(outputDir));
    final content = File(file.path).readAsStringSync();

    expect(
      content.contains('hide Task'),
      isFalse,
      reason:
          '#1530: the mock emission hid on package:zuraffa/mock.dart — '
          'the same unverified-name class',
    );
    expect(
      content.contains("import 'package:zuraffa/mock.dart';"),
      isTrue,
    );
  });
}
