// Regression tests for issue #320 — zfa entity create: autoId + ValueObject
// end-to-end (the CREATE step).
//
// The framework gaps from #320 (auto-generated uuid id, ValueObject third
// kind, loud no-id error) were implemented across the zorphy annotation +
// builder (zorphy repo commits 63510ea + 727a8c6) and the zuraffa zfa CLI
// (PR #322 → commit 87fc008). The `zfa make` half is already locked in by
// `test/commands/make_command_test.dart` (#307 identity-contract group) and
// `test/regression/issue_321_no_first_field_id_fallback_enum_import_test.dart`.
//
// What was NOT covered end-to-end was the `zfa entity create` step itself —
// the flags `--auto-id` and `--kind=value_object` and the entity file they
// generate. #320 explicitly lists "zfa entity create --kind=value_object
// works end to end" as a verification item. These tests close that gap:
//
//   - `--kind=value_object` → the generated entity file carries
//     `@Zorphy(kind: ZorphyKind.valueObject, ...)`, declares NO `id` field,
//     and does NOT import `package:uuid/uuid.dart` (value objects have no
//     identity).
//   - `--auto-id` → the generated entity file carries `autoId: true` in the
//     `@Zorphy(...)` annotation, prepends a `String get id;` declaration
//     (the zorphy builder defaults the concrete constructor's `id` to
//     `Uuid().v4()`), and imports `package:uuid/uuid.dart`.
//   - A plain entity create (no `--auto-id`, no id field, no value-object
//     kind) still writes the entity file — the identity contract is enforced
//     at `zfa make` time (loud error, covered by make_command_test), NOT at
//     `zfa entity create` time. This documents the create-vs-make contract.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import '../helpers/project_root.dart';

void main() {
  group('#320 — zfa entity create: --kind=value_object + --auto-id e2e', () {
    late Directory workspace;
    late String outputDir;
    late String zfaSourceBin;

    // Runs zfa from SOURCE (never a stale compiled ~/.local/bin/zfa) as a
    // subprocess with an explicit workingDirectory — mirrors the
    // make_command_test #307 group so these tests cannot race with other
    // test files that capture Directory.current at load time (#296).
    Future<ProcessResult> runZfaSource(List<String> args) {
      return Process.run(
        'dart',
        [zfaSourceBin, ...args],
        workingDirectory: workspace.path,
      );
    }

    setUpAll(() async {
      final projectRoot = await findProjectRoot();
      zfaSourceBin = path.join(projectRoot, 'bin', 'zfa.dart');
    });

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_entity_create_320_');
      outputDir = path.join(workspace.path, 'lib', 'src', 'domain', 'entities');
      await Directory(outputDir).create(recursive: true);
      // `zfa entity create` runs a pubspec dependency check that greps for
      // `zorphy_annotation:` and `build_runner:` (it does NOT resolve them —
      // the create step only writes the entity template; the zorphy builder
      // runs later via `zfa build`). The test workspace mirrors the real
      // app pubspec: uuid (the autoId dep) + the two zfa-required names so
      // the dependency gate passes and the entity file is actually written.
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_entity_create_320_test
environment:
  sdk: ^3.11.0
dependencies:
  uuid: ^4.6.0
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
      '--kind=value_object generates an entity file with '
      '@Zorphy(kind: ZorphyKind.valueObject), no id field, no uuid import',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity', 'create',
          '-n', 'ParserConfig',
          '--kind=value_object',
          '--field', 'separator:String',
          '--field', 'trimWhitespace:bool',
          '--output', outputDir,
        ]);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        final file = File(
          path.join(outputDir, 'parser_config', 'parser_config.dart'),
        );
        expect(file.existsSync(), isTrue, reason: 'entity file not written');
        final src = file.readAsStringSync();

        // Value-object annotation surface.
        expect(
          src,
          contains('kind: ZorphyKind.valueObject'),
          reason: 'value object must carry its kind in the annotation',
        );
        // Default-on options still emit (parity with the entity kind).
        expect(src, contains('generateJson: true'));
        expect(src, contains('generateCompareTo: true'));

        // A value object has NO identity — no autoId, no id getter, no uuid.
        expect(
          src,
          isNot(contains('autoId')),
          reason: 'value objects must not carry the autoId flag',
        );
        expect(
          src,
          isNot(contains('String get id;')),
          reason: 'value objects must not declare an id getter',
        );
        expect(
          src,
          isNot(contains("package:uuid/uuid.dart")),
          reason: 'value objects must not import the uuid package',
        );

        // Fields are emitted as abstract getters on $ParserConfig.
        expect(src, contains('abstract class \$ParserConfig'));
        expect(src, contains('String get separator;'));
        expect(src, contains('bool get trimWhitespace;'));
      },
    );

    test(
      '--auto-id generates an entity file with autoId: true, a prepended '
      'String get id; getter, and the uuid import',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity', 'create',
          '-n', 'ChatMessage',
          '--auto-id',
          '--field', 'content:String',
          '--field', 'timestamp:DateTime',
          '--output', outputDir,
        ]);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        final file = File(
          path.join(outputDir, 'chat_message', 'chat_message.dart'),
        );
        expect(file.existsSync(), isTrue, reason: 'entity file not written');
        final src = file.readAsStringSync();

        // autoId is carried on the @Zorphy(...) annotation; the builder
        // turns it into a constructor `id ??= const Uuid().v4()` default.
        expect(
          src,
          contains('autoId: true'),
          reason: 'autoId must be emitted on the annotation',
        );
        // The uuid import is emitted so the builder-generated default
        // (`const Uuid().v4()`) resolves.
        expect(
          src,
          contains("import 'package:uuid/uuid.dart';"),
          reason: 'autoId entities must import the uuid package',
        );
        // A synthetic `String get id;` is prepended (no id field was passed
        // on the CLI); the concrete constructor the builder emits defaults
        // it at construction time.
        expect(
          src,
          contains('String get id;'),
          reason: 'autoId entities must declare the id getter',
        );

        // autoId is an entity concept, not a value-object one.
        expect(
          src,
          isNot(contains('kind: ZorphyKind.valueObject')),
          reason: 'autoId entities must not be marked as value objects',
        );

        // The user-supplied fields are still present.
        expect(src, contains('abstract class \$ChatMessage'));
        expect(src, contains('String get content;'));
        expect(src, contains('DateTime get timestamp;'));
      },
    );

    test(
      'a plain entity create (no --auto-id, no id field) still writes the '
      'file — the identity contract is enforced at `zfa make`, not at create',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // `zfa entity create` only writes the entity definition; it does
        // not resolve identity. The loud no-id error fires in `zfa make`
        // (covered by make_command_test #307 identity-contract group).
        final result = await runZfaSource([
          'entity', 'create',
          '-n', 'Note',
          '--field', 'body:String',
          '--output', outputDir,
        ]);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        final file = File(path.join(outputDir, 'note', 'note.dart'));
        expect(file.existsSync(), isTrue, reason: 'entity file not written');
        final src = file.readAsStringSync();

        // No identity surface was requested, so none is emitted.
        expect(src, isNot(contains('autoId')));
        expect(src, isNot(contains('String get id;')));
        expect(src, isNot(contains('kind: ZorphyKind.valueObject')));
        expect(src, isNot(contains("package:uuid/uuid.dart")));
        expect(src, contains('abstract class \$Note'));
        expect(src, contains('String get body;'));
      },
    );
  });
}
