// Plugin-level regression lock for issue #321 (enum import emission).
//
// When a generated method signature references an enum-typed id field (e.g.
// `messageTypeId: MessageType`), the presenter/controller must emit the enum
// barrel import (`domain/entities/enums/index.dart`). Previously the import was
// missing, producing `Undefined class 'MessageType'` analyzer errors. Primitive
// id types (String/int/...) must not produce a spurious enum import.
//
// This test drives the presenter plugin directly (no `zfa make` / flutter
// subprocess) and asserts the generated import set reacts to the id-field type.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_321_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> _writeMessageTypeEnum() async {
    final enumDir = Directory(
      path.join(outputDir, 'domain', 'entities', 'enums'),
    );
    await enumDir.create(recursive: true);
    await File(path.join(enumDir.path, 'message_type.dart'))
        .writeAsString('enum MessageType { a, b, c }\n');
    await File(path.join(enumDir.path, 'index.dart'))
        .writeAsString("export 'message_type.dart';\n");
  }

  group('#321 — emit enum imports for signature (id) types', () {
    test('emits enum barrel import when id field type is an enum', () async {
      await _writeMessageTypeEnum();

      final plugin = PresenterPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'MessageLog',
        methods: const ['update', 'toggle'],
        idField: 'messageTypeId',
        idFieldType: 'MessageType',
        queryField: 'messageTypeId',
        generatePresenter: true,
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);
      final content = files.first.content ?? '';

      // The enum barrel import must be emitted.
      expect(
        content,
        contains('domain/entities/enums/index.dart'),
        reason: '#321: presenter must import the enum barrel for an enum id type',
      );
      // The signature must reference the enum-typed id.
      expect(
        content,
        contains('UpdateParams<MessageType,'),
        reason: '#321: presenter must reference the enum id type in UpdateParams',
      );
      expect(
        content,
        contains('ToggleParams<MessageType,'),
        reason: '#321: presenter must reference the enum id type in ToggleParams',
      );
      expect(
        content,
        contains('MessageType messageTypeId'),
        reason: '#321: id parameter must be typed as the enum',
      );
    });

    test('does NOT emit an enum import for a primitive (String) id type', () async {
      final plugin = PresenterPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Authentication',
        methods: const ['update', 'toggle'],
        idField: 'id',
        idFieldType: 'String',
        queryField: 'id',
        generatePresenter: true,
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);
      final content = files.first.content ?? '';

      // Negative: no enum barrel import for a plain String id.
      expect(
        content,
        isNot(contains('enums/index.dart')),
        reason: '#321: primitive id type must not produce an enum import',
      );
      expect(
        content,
        contains('UpdateParams<String,'),
        reason: 'control case uses String-typed ids',
      );
    });
  });
}
