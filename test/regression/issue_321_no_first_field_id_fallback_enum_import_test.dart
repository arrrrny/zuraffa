// Regression tests for issue #321.
//
// `zfa make` on entities WITHOUT an id field (ChatMessage, TelemetryEvent —
// verified id-less in the real zik_zak codebase) previously fell back to
// the FIRST declared field as the id. When that field was an enum (e.g.
// `role: ChatMessageRole`), the generators emitted enum-typed ids
// (`UpdateParams<ChatMessageRole, ...>`, `ToggleParams<ChatMessageRole,
// ...>`) in presenter/controller/usecase-test files WITHOUT importing
// the enum barrel → 48+ `Undefined class 'ChatMessageRole'` analyze
// errors (issue #307). Control case: `Authentication` (has real
// `id: String`) compiles clean.
//
// The fix (issue #321, supersedes #307; merged with #322's identity
// contract — EntityIdResolution + value objects, already in development):
//   1. Kill the silent first-field fallback in `EntityFieldResolver`.
//      The resolver returns an `EntityIdResolution` (entity kind, autoId
//      flag, resolved id-like field). Resolution order: value object →
//      no identity; literal `id` → found; first `*Id` → found;
//      `@Zorphy(autoId: true)` → synthetic `id: String`; otherwise the
//      entity is id-less (`hasId == false`) and `zfa make` fails loudly
//      (throws MakeCommandException → exit 1).
//   2. `MakeCommand` never silently falls back to the first field: an
//      id-less entity (no id-like field, no autoId marker, not a value
//      object) errors loudly with a diagnostic naming the three valid
//      resolutions.
//   3. Emit enum imports for method-signature types: when a generated
//      method signature references an enum type (id, params, returns),
//      the enum barrel import (`enums/index.dart`) is emitted in every
//      generated file that uses it (presenter, controller, usecase,
//      usecase tests). Primitive id types (String/int/...) are filtered
//      out by `KnownTypes.isExcluded` so they add no spurious imports.
//
// These tests exercise both halves:
//   - The loud-error path: `zfa make` on a ChatMessage-shaped entity
//     (no id, no autoId) fails with a clear diagnostic and exits 1.
//   - The autoId path: the same entity annotated with `@Zorphy(autoId:
//     true)` resolves to a synthetic `id: String` and generates clean
//     (no enum-typed ids, no missing enum imports — none needed since
//     the id is a plain String).
//   - The enum-id import path: an entity with a real `*Id` field whose
//     type is an enum (e.g. `messageTypeId: MessageType`) generates
//     `UpdateParams<MessageType, ...>` in presenter/controller/test
//     files WITH the enum barrel import emitted.
//   - The control case: `Authentication` with real `id: String`
//     generates clean (no enum imports, no loud error).

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/utils/entity_field_resolver.dart';

/// Resolve package root at discovery time, before any test changes CWD.
final _zfaRoot = Directory.current.path;

void main() {
  group('#321 — zfa make: no first-field id fallback + emit enum imports', () {
    late Directory workspace;
    late String zfaBin;
    late String outputDir;

    Future<ProcessResult> runZfa(List<String> args) {
      return Process.run('dart', [zfaBin, ...args],
          workingDirectory: workspace.path);
    }

    setUp(() async {
      zfaBin = path.join(_zfaRoot, 'bin', 'zfa.dart');
      workspace = await Directory.systemTemp.createTemp('issue_321_');
      outputDir = path.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      // Minimal pubspec — `zfa make` only needs the package to exist.
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_321_test_app
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: ${path.normalize(_zfaRoot)}
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    /// Writes the ChatMessageRole enum (mirrors `zfa entity enum` output).
    Future<void> writeChatMessageRoleEnum() async {
      final enumDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'enums'),
      );
      await enumDir.create(recursive: true);
      await File(path.join(enumDir.path, 'chat_message_role.dart'))
          .writeAsString('''
enum ChatMessageRole { user, assistant, system }
''');
      await File(path.join(enumDir.path, 'index.dart')).writeAsString('''
export 'chat_message_role.dart';
''');
    }

    /// Writes a ChatMessage entity with NO id field — the #307/#321 repro.
    Future<void> writeChatMessageEntityWithoutId() async {
      await writeChatMessageRoleEnum();
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'chat_message'),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'chat_message.dart'))
          .writeAsString('''
import '../enums/index.dart';

abstract class \$ChatMessage {
  ChatMessageRole get role;
  String get content;
  DateTime get timestamp;
}

abstract final class ChatMessageFields {
  static const Field<ChatMessage, ChatMessageRole> role =
      Field<ChatMessage, ChatMessageRole>(name: 'role');
  static const Field<ChatMessage, String> content =
      Field<ChatMessage, String>(name: 'content');
  static const Field<ChatMessage, DateTime> timestamp =
      Field<ChatMessage, DateTime>(name: 'timestamp');
}
''');
    }

    /// Writes a ChatMessage entity annotated with `@Zorphy(autoId: true)`.
    Future<void> writeChatMessageEntityWithAutoId() async {
      await writeChatMessageRoleEnum();
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'chat_message'),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'chat_message.dart'))
          .writeAsString('''
import '../enums/index.dart';

@Zorphy(autoId: true)
abstract class \$ChatMessage {
  ChatMessageRole get role;
  String get content;
  DateTime get timestamp;
}

abstract final class ChatMessageFields {
  static const Field<ChatMessage, String> id =
      Field<ChatMessage, String>(name: 'id');
  static const Field<ChatMessage, ChatMessageRole> role =
      Field<ChatMessage, ChatMessageRole>(name: 'role');
  static const Field<ChatMessage, String> content =
      Field<ChatMessage, String>(name: 'content');
  static const Field<ChatMessage, DateTime> timestamp =
      Field<ChatMessage, DateTime>(name: 'timestamp');
}
''');
    }

    /// Writes an entity with a real `*Id` field whose type is an enum —
    /// exercises the enum-import-emission path for legitimate enum ids.
    Future<void> writeMessageLogEntityWithEnumIdField() async {
      final enumDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'enums'),
      );
      await enumDir.create(recursive: true);
      await File(path.join(enumDir.path, 'message_type.dart')).writeAsString('''
enum MessageType { incoming, outgoing, system }
''');
      await File(path.join(enumDir.path, 'index.dart')).writeAsString('''
export 'message_type.dart';
''');
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'message_log'),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'message_log.dart'))
          .writeAsString('''
import '../enums/index.dart';

abstract class \$MessageLog {
  MessageType get messageTypeId;
  String get body;
  DateTime get timestamp;
}

abstract final class MessageLogFields {
  static const Field<MessageLog, MessageType> messageTypeId =
      Field<MessageLog, MessageType>(name: 'messageTypeId');
  static const Field<MessageLog, String> body =
      Field<MessageLog, String>(name: 'body');
  static const Field<MessageLog, DateTime> timestamp =
      Field<MessageLog, DateTime>(name: 'timestamp');
}
''');
    }

    /// Writes the Authentication control-case entity (real `id: String`).
    Future<void> writeAuthenticationEntity() async {
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'authentication'),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'authentication.dart'))
          .writeAsString('''
abstract class \$Authentication {
  String get id;
  String get provider;
}

abstract final class AuthenticationFields {
  static const Field<Authentication, String> id =
      Field<Authentication, String>(name: 'id');
  static const Field<Authentication, String> provider =
      Field<Authentication, String>(name: 'provider');
}
''');
    }

    // -----------------------------------------------------------------------
    // Part A — loud error: no silent first-field fallback
    // -----------------------------------------------------------------------

    group('Part A — loud error (no silent first-field fallback)', () {
      test('resolver reports an id-less ChatMessage (no id, no *Id, no '
          'autoId) without inventing an id', () async {
        await writeChatMessageEntityWithoutId();
        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'ChatMessage',
          projectRoot: workspace.path,
        );
        expect(resolved, isNotNull);
        final resolution = resolved!;
        expect(resolution.hasId, isFalse,
            reason: '#321/#307: the resolver must NOT silently pick `role` '
                '(enum) as the id.');
        expect(resolution.idField, isNull,
            reason: '#321/#307: an id-less entity must not get a synthetic '
                'id — that is the #307 bug.');
      });

      test('`zfa make ChatMessage` (no id, no autoId) fails loudly with a '
          'clear diagnostic and exits 1', () async {
        await writeChatMessageEntityWithoutId();
        // `--no-entity` is NOT set, so the resolver runs and finds no
        // id-like field. MakeCommand must error loudly and exit 1.
        final result = await runZfa([
          'make',
          'ChatMessage',
          '--preset=crud',
          '--with=vpc,state,di,test,mock',
          '--methods=get,getList,create,update,delete,toggle',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, equals(1),
            reason: 'zfa make must exit 1 when the entity has no id-like '
                'field and no autoId marker (#321).');
        final stderr = result.stderr.toString();
        final stdout = result.stdout.toString();
        final combined = '$stderr\n$stdout';
        expect(
          combined,
          contains('ChatMessage'),
          reason: 'diagnostic must name the entity',
        );
        expect(
          combined,
          contains('id'),
          reason: 'diagnostic must mention the id field requirement',
        );
        expect(
          combined,
          anyOf([
            contains('autoId'),
            contains('autoid'),
            contains('--id-field'),
            contains('--auto-id'),
            contains('--kind=value_object'),
          ]),
          reason: 'diagnostic must point at one of the valid resolutions '
              '(add id, --auto-id, --id-field, or value object)',
        );
        // Negative: no presenter file should be generated when the
        // command exits 1 before plugin execution.
        final presenterFile = File(path.join(
          outputDir,
          'presentation',
          'pages',
          'chat_message',
          'chat_message_presenter.dart',
        ));
        expect(presenterFile.existsSync(), isFalse,
            reason: 'no files should be generated when the loud error fires');
      });

      test('loud-error diagnostic names the entity and the id requirement '
          '(merged #307/#322 diagnostic)', () async {
        await writeChatMessageEntityWithoutId();
        final result = await runZfa([
          'make',
          'ChatMessage',
          '--preset=crud',
          '--output',
          outputDir,
        ]);
        expect(result.exitCode, equals(1));
        final combined =
            '${result.stderr}\n${result.stdout}';
        expect(combined, contains('ChatMessage'),
            reason: 'diagnostic must name the entity');
        expect(combined, contains('has no id field'),
            reason: 'diagnostic must state the id requirement');
        expect(combined, contains('--auto-id'),
            reason: 'diagnostic must point at the autoId resolution');
      });

      test('`--id-field` does not resurrect an identity for a truly '
          'id-less entity — the loud error still fires (merged #307/#322 '
          'contract)', () async {
        await writeChatMessageEntityWithoutId();
        // The merged identity contract (issue #307/#322, already in
        // development) is strict: an entity with no id-like field, no
        // autoId marker and no value-object kind is an id-less entity,
        // and `zfa make` fails loudly regardless of --id-field. The
        // explicit flag overrides the *default* id choice when the entity
        // HAS an id — it does not create an identity out of nothing.
        final result = await runZfa([
          'make',
          'ChatMessage',
          '--preset=crud',
          '--with=vpc,state,di',
          '--methods=get,update,delete',
          '--id-field=content',
          '--id-field-type=String',
          '--output',
          outputDir,
        ]);
        expect(result.exitCode, equals(1),
            reason: 'an id-less entity must fail loudly even with '
                '--id-field (no first-field fallback, no invented id)');
        final combined = '${result.stderr}\n${result.stdout}';
        expect(combined, contains('has no id field'),
            reason: 'the loud id-less diagnostic must still fire');
        expect(combined, isNot(contains('Resolved id field')),
            reason: 'the enum-typed-id fallback must never happen');
      });

      test('`--no-entity` skips the resolver entirely (no loud error for '
          'non-entity flows)', () async {
        // No entity file written — `--no-entity` means the resolver is
        // skipped. The generator proceeds without an id-field resolution.
        final result = await runZfa([
          'make',
          'CustomThing',
          '--no-entity',
          '--preset=crud',
          '--output',
          outputDir,
        ]);
        // Whatever exit code, the #321 loud error must NOT fire because
        // --no-entity was passed.
        final combined =
            '${result.stderr}\n${result.stdout}';
        expect(
          combined,
          isNot(contains('has no id-like field')),
          reason: '--no-entity must skip the resolver and the loud error',
        );
      });
    });

    // -----------------------------------------------------------------------
    // Part A — autoId hook (forward-compatible with #320)
    // -----------------------------------------------------------------------

    group('Part A — @Zorphy(autoId: true) hook (#320 coordination)', () {
      test('resolver returns synthetic id: String for autoId entity', () async {
        await writeChatMessageEntityWithAutoId();
        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'ChatMessage',
          projectRoot: workspace.path,
        );
        expect(resolved, isNotNull);
        final resolution = resolved!;
        expect(resolution.hasId, isTrue,
            reason: 'autoId resolves the identity even without an id getter');
        expect(resolution.idField!.name, 'id');
        expect(resolution.idField!.type, 'String');
      });

      test('`zfa make ChatMessage` with @Zorphy(autoId: true) succeeds and '
          'generates String-typed ids (no enum-typed ids, no loud error)',
          () async {
        await writeChatMessageEntityWithAutoId();
        final result = await runZfa([
          'make',
          'ChatMessage',
          '--preset=crud',
          '--with=vpc,state,di',
          '--methods=get,update,delete,toggle',
          '--output',
          outputDir,
        ]);
        expect(result.exitCode, equals(0),
            reason: 'autoId entity must generate cleanly — stderr: '
                '${result.stderr}');
        // The generated presenter must use String-typed ids (not enum).
        final presenterFile = File(path.join(
          outputDir,
          'presentation',
          'pages',
          'chat_message',
          'chat_message_presenter.dart',
        ));
        expect(presenterFile.existsSync(), isTrue);
        final presenter = presenterFile.readAsStringSync();
        // Positive: String-typed id in the UpdateParams signature.
        expect(
          presenter,
          contains('UpdateParams<String,'),
          reason: 'autoId entity must use String as the id type',
        );
        // Negative: NO enum-typed id (the #307 bug shape).
        expect(
          presenter,
          isNot(contains('UpdateParams<ChatMessageRole')),
          reason: 'autoId entity must NOT produce enum-typed ids',
        );
      });
    });

    // -----------------------------------------------------------------------
    // Part B — emit enum imports for signature types
    // -----------------------------------------------------------------------

    group('Part B — emit enum imports for signature types', () {
      test('resolver picks `messageTypeId` (enum-typed *Id field) for '
          'MessageLog', () async {
        await writeMessageLogEntityWithEnumIdField();
        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'MessageLog',
          projectRoot: workspace.path,
        );
        expect(resolved, isNotNull);
        final resolution = resolved!;
        expect(resolution.hasId, isTrue,
            reason: 'a *Id field is a valid identity');
        expect(resolution.idField!.name, 'messageTypeId');
        expect(resolution.idField!.nonNullableType, 'MessageType');
      });

      test('generated presenter references `UpdateParams<MessageType, ...>` '
          'AND imports the enum barrel', () async {
        await writeMessageLogEntityWithEnumIdField();
        final result = await runZfa([
          'make',
          'MessageLog',
          '--preset=crud',
          '--with=vpc,state,di,test,mock',
          '--methods=get,getList,create,update,delete,toggle',
          '--output',
          outputDir,
        ]);
        expect(result.exitCode, equals(0),
            reason: 'generation must succeed — stderr: ${result.stderr}');

        final presenterFile = File(path.join(
          outputDir,
          'presentation',
          'pages',
          'message_log',
          'message_log_presenter.dart',
        ));
        expect(presenterFile.existsSync(), isTrue,
            reason: 'presenter must be generated');
        final presenter = presenterFile.readAsStringSync();
        // The signature references the enum-typed id.
        expect(
          presenter,
          contains('UpdateParams<MessageType,'),
          reason: 'presenter must reference the enum-typed id in UpdateParams',
        );
        expect(
          presenter,
          contains('ToggleParams<MessageType,'),
          reason: 'presenter must reference the enum-typed id in ToggleParams',
        );
        // The enum barrel import must be emitted.
        expect(
          presenter,
          contains('domain/entities/enums/index.dart'),
          reason: '#321: presenter must import the enum barrel when the id '
              'field is an enum (the #307 root cause was this import missing)',
        );
      });

      test('generated controller imports the enum barrel when the id field '
          'is an enum', () async {
        await writeMessageLogEntityWithEnumIdField();
        final result = await runZfa([
          'make',
          'MessageLog',
          '--preset=crud',
          '--with=vpc,state,di,test',
          '--methods=update,toggle,delete',
          '--output',
          outputDir,
        ]);
        expect(result.exitCode, equals(0),
            reason: 'stderr: ${result.stderr}');
        final controllerFile = File(path.join(
          outputDir,
          'presentation',
          'pages',
          'message_log',
          'message_log_controller.dart',
        ));
        expect(controllerFile.existsSync(), isTrue,
            reason: 'controller must be generated');
        final controller = controllerFile.readAsStringSync();
        expect(
          controller,
          contains('domain/entities/enums/index.dart'),
          reason: '#321: controller must import the enum barrel when the id '
              'field is an enum',
        );
      });

      test('generated usecase files import the enum barrel when the id '
          'field is an enum (covers the delete usecase where '
          'needsEntityImport was previously false)', () async {
        await writeMessageLogEntityWithEnumIdField();
        final result = await runZfa([
          'make',
          'MessageLog',
          '--preset=crud',
          '--with=vpc,state,di,test',
          '--methods=update,toggle,delete',
          '--output',
          outputDir,
        ]);
        expect(result.exitCode, equals(0),
            reason: 'stderr: ${result.stderr}');

        // delete usecase: DeleteParams<MessageType> — previously the
        // enum import was NOT emitted because needsEntityImport=false.
        final deleteUseCaseFile = File(path.join(
          outputDir,
          'domain',
          'usecases',
          'message_log',
          'delete_message_log_usecase.dart',
        ));
        expect(deleteUseCaseFile.existsSync(), isTrue,
            reason: 'delete usecase must be generated');
        final deleteUseCase = deleteUseCaseFile.readAsStringSync();
        expect(
          deleteUseCase,
          contains('DeleteParams<MessageType>'),
          reason: 'delete usecase signature must reference the enum id type',
        );
        expect(
          deleteUseCase,
          contains('domain/entities/enums/index.dart'),
          reason: '#321: delete usecase must import the enum barrel — '
              'previously missing because needsEntityImport=false skipped '
              'the entityImports call entirely',
        );

        // update usecase: UpdateParams<MessageType, MessageLogPatch> —
        // the enum import must also be present.
        final updateUseCaseFile = File(path.join(
          outputDir,
          'domain',
          'usecases',
          'message_log',
          'update_message_log_usecase.dart',
        ));
        expect(updateUseCaseFile.existsSync(), isTrue);
        final updateUseCase = updateUseCaseFile.readAsStringSync();
        expect(
          updateUseCase,
          contains('domain/entities/enums/index.dart'),
          reason: '#321: update usecase must import the enum barrel',
        );
      });

      test('generated usecase TEST files import the enum barrel when the '
          'id field is an enum', () async {
        await writeMessageLogEntityWithEnumIdField();
        final result = await runZfa([
          'make',
          'MessageLog',
          '--preset=crud',
          '--with=vpc,state,di,test',
          '--methods=update,toggle,delete',
          '--output',
          outputDir,
        ]);
        expect(result.exitCode, equals(0),
            reason: 'stderr: ${result.stderr}');

        // The test files live under the workspace's test/ directory.
        final toggleTestFile = File(path.join(
          workspace.path,
          'test',
          'domain',
          'usecases',
          'message_log',
          'toggle_message_log_usecase_test.dart',
        ));
        expect(toggleTestFile.existsSync(), isTrue,
            reason: 'toggle usecase test must be generated');
        final toggleTest = toggleTestFile.readAsStringSync();
        expect(
          toggleTest,
          contains('ToggleParams<MessageType,'),
          reason: 'toggle test must reference the enum-typed id',
        );
        expect(
          toggleTest,
          contains('enums/index.dart'),
          reason: '#321: toggle test must import the enum barrel',
        );

        final deleteTestFile = File(path.join(
          workspace.path,
          'test',
          'domain',
          'usecases',
          'message_log',
          'delete_message_log_usecase_test.dart',
        ));
        expect(deleteTestFile.existsSync(), isTrue,
            reason: 'delete usecase test must be generated');
        final deleteTest = deleteTestFile.readAsStringSync();
        expect(
          deleteTest,
          contains('DeleteParams<MessageType>'),
          reason: 'delete test must reference the enum-typed id',
        );
        expect(
          deleteTest,
          contains('enums/index.dart'),
          reason: '#321: delete test must import the enum barrel',
        );
      });
    });

    // -----------------------------------------------------------------------
    // Control case — Authentication (real `id: String`) stays clean
    // -----------------------------------------------------------------------

    group('Control case — Authentication (real id: String)', () {
      test('resolver finds `id` (String) for Authentication', () async {
        await writeAuthenticationEntity();
        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'Authentication',
          projectRoot: workspace.path,
        );
        expect(resolved, isNotNull);
        final resolution = resolved!;
        expect(resolution.hasId, isTrue,
            reason: 'a literal `id` field is a valid identity');
        expect(resolution.idField!.name, 'id');
        expect(resolution.idField!.type, 'String');
      });

      test('`zfa make Authentication` generates clean (String-typed ids, no '
          'enum imports, no loud error)', () async {
        await writeAuthenticationEntity();
        final result = await runZfa([
          'make',
          'Authentication',
          '--preset=crud',
          '--with=vpc,state,di,test',
          '--methods=get,update,delete,toggle',
          '--output',
          outputDir,
        ]);
        expect(result.exitCode, equals(0),
            reason: 'control case must generate cleanly — stderr: '
                '${result.stderr}');
        final presenterFile = File(path.join(
          outputDir,
          'presentation',
          'pages',
          'authentication',
          'authentication_presenter.dart',
        ));
        expect(presenterFile.existsSync(), isTrue);
        final presenter = presenterFile.readAsStringSync();
        expect(
          presenter,
          contains('UpdateParams<String,'),
          reason: 'control case uses String-typed ids',
        );
        // Negative: no enum barrel import (none needed).
        expect(
          presenter,
          isNot(contains('enums/index.dart')),
          reason: 'control case has no enum-typed signature — no enum import',
        );
        // Negative: no loud error.
        final combined =
            '${result.stderr}\n${result.stdout}';
        expect(
          combined,
          isNot(contains('has no id-like field')),
          reason: 'control case has a real id field — no loud error',
        );
      });
    });
  });
}
