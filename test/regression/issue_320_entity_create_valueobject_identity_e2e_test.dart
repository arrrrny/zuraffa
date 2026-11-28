@Tags(['regression', 'slow'])
library;

// Regression tests for issue #320 — `zfa entity create` end-to-end (the
// CREATE step): the value-object kind and the entity identity surface.
//
// The `zfa make` half is locked in by `test/commands/make_command_test.dart`
// (#307 identity-contract group) and
// `test/regression/issue_321_no_first_field_id_fallback_enum_import_test.dart`.
// What is covered here is the `zfa entity create` step itself — the
// `--kind=value_object` flag and the entity file it generates. #320 lists
// "zfa entity create --kind=value_object works end to end" as a
// verification item. These tests close that gap against the zorphy v3
// scaffold:
//
//   - `--kind=value_object` → the file is a `@ZorphyValue()`: abstract
//     getters, NO `id` field, no identity of any kind.
//   - a plain entity create → the file is a
//     `@ZorphyEntity(principalKey: #id)` and declares `String get id;`.
//     Identity is not a toggle in v3 (the v2 `--auto-id` flag is gone): the
//     scaffold declares the key field even when none was listed.
//   - the shared part: every scaffold declares build_runner's `_br_/` part
//     for its own library path, never a `<name>.zorphy.dart` file.
//
// The create step never runs the builder, so these tests pin the SOURCE the
// scaffold writes; `zfa build` turning it into a compiling library is the
// build suite's contract.
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  group('#320 — zfa entity create: --kind=value_object + identity e2e', () {
    late Directory workspace;
    late String outputDir;

    setUpAll(() async {
      await initZfaSourceBin();
    });

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp(
        'zfa_entity_create_320_',
      );
      outputDir = path.join(workspace.path, 'lib', 'src', 'domain', 'entities');
      await Directory(outputDir).create(recursive: true);
      // `zfa entity create` runs a pubspec dependency check that greps for
      // `zorphy_annotation:` and `build_runner:` (it does NOT resolve them —
      // the create step only writes the entity template; the zorphy builder
      // runs later via `zfa build`). The test workspace mirrors the real
      // app pubspec: the two names the dependency gate greps for, so the
      // entity file is actually written.
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_entity_create_320_test
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      '--kind=value_object generates a @ZorphyValue() with no identity',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'ParserConfig',
          '--kind=value_object',
          '--field',
          'separator:String',
          '--field',
          'trimWhitespace:bool',
          '--output',
          outputDir,
        ], workingDirectory: workspace.path);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        final file = File(
          path.join(outputDir, 'parser_config', 'parser_config.dart'),
        );
        expect(file.existsSync(), isTrue, reason: 'entity file not written');
        final src = file.readAsStringSync();

        // The v3 value-object archetype.
        expect(src, contains('@ZorphyValue()'));
        expect(src, isNot(contains('@ZorphyEntity')));
        // Fields are emitted as abstract getters on $ParserConfig.
        expect(src, contains('abstract class \$ParserConfig'));
        expect(src, contains('String get separator;'));
        expect(src, contains('bool get trimWhitespace;'));

        // A value object has NO identity.
        expect(
          src,
          isNot(contains('String get id;')),
          reason: 'value objects must not declare an id getter',
        );
        expect(
          src,
          isNot(contains('principalKey')),
          reason: 'a principalKey is an @ZorphyEntity concept',
        );
        // No uuid default — v3 has no auto-generated id.
        expect(src, isNot(contains('uuid')));
      },
    );

    test(
      'a plain entity create is a @ZorphyEntity(principalKey: #id) that '
      'declares the identity even when no id field was listed',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'ChatMessage',
          '--field',
          'content:String',
          '--field',
          'timestamp:DateTime',
          '--output',
          outputDir,
        ], workingDirectory: workspace.path);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        final file = File(
          path.join(outputDir, 'chat_message', 'chat_message.dart'),
        );
        expect(file.existsSync(), isTrue, reason: 'entity file not written');
        final src = file.readAsStringSync();

        // Identity is declared, never toggled: the scaffold names the key
        // and declares the field (zorphy v3 rejects a key naming no field).
        expect(src, contains('@ZorphyEntity(principalKey: #id)'));
        expect(
          src,
          contains('String get id;'),
          reason: 'the principalKey field must be declared',
        );
        // Not a value object.
        expect(src, isNot(contains('@ZorphyValue()')));

        // The user-supplied fields are still present.
        expect(src, contains('abstract class \$ChatMessage'));
        expect(src, contains('String get content;'));
        expect(src, contains('DateTime get timestamp;'));
      },
    );

    test(
      'every scaffold declares the build_runner shared part for its own '
      'library path, never a <name>.zorphy.dart file',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Note',
          '--field',
          'body:String',
          '--output',
          outputDir,
        ], workingDirectory: workspace.path);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        final file = File(path.join(outputDir, 'note', 'note.dart'));
        expect(file.existsSync(), isTrue, reason: 'entity file not written');
        final src = file.readAsStringSync();

        // The v2 standalone part is gone for good.
        expect(src, isNot(contains('.zorphy.dart')));
        // build_runner's reserved `_br_/` namespace, mirroring the library's
        // own path, ending in `<library>.part.dart`.
        expect(
          src,
          contains(
            "part '../../../../_br_/src/domain/entities/note/note.part.dart';",
          ),
        );
      },
    );
  });
}
