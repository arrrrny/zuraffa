// Regression tests for issue #416 — zfa entity sealed: generates subtypes as
// separate libraries implementing sealed class → invalid_use_of_type_outside_library.
//
// When `zfa entity create --sealed --generate-subs --subtypes A,B,C` is run,
// Zorphy's `EntityCreator.create()` writes each subtype to its OWN library
// (e.g. `lib/src/domain/entities/a/a.dart`, `.../b/b.dart`, ...). Each
// subtype file declares `class $A implements $$Parent { ... }`. Once `zfa
// build` runs, the zorphy builder rewrites `$$Parent` into a `sealed class
// Parent` — Dart then rejects every cross-library `implements Sealed` with
// `invalid_use_of_type_outside_library` (9 errors for the issue's repro).
//
// The fix in `EntityCommand._handleCreate` post-processes the generated
// output when `isSealed && generateSubtypes && explicitSubtypes.isNotEmpty`:
// the subtype class declarations are inlined into the sealed base's source
// file (same library), the now-redundant subtype files + directories are
// deleted, the cross-library subtype imports are dropped, and the base
// file gains the `part '<base>.g.dart';` directive so `json_serializable`
// has somewhere to write the `_$XFromJson`/`_$XToJson` helpers for the
// inlined subtypes.
//
// These tests lock in the three observable contracts:
//   1. Sealed + --generate-subs → ONE source file with all subtypes
//      inlined, NO subtype files, NO subtype imports, BOTH part directives.
//   2. Sealed + NO --generate-subs → existing behavior preserved (no
//      subtype files were ever generated; base file untouched by the
//      inlining path).
//   3. Non-sealed + --generate-subs → existing behavior preserved (subtype
//      files exist; base file carries per-subtype imports).

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import '../helpers/project_root.dart';

void main() {
  group('#416 — zfa entity sealed subtypes inlined into base library', () {
    late Directory workspace;
    late String outputDir;
    late String zfaSourceBin;

    Future<ProcessResult> runZfaSource(List<String> args) {
      return Process.run('dart', [
        zfaSourceBin,
        ...args,
      ], workingDirectory: workspace.path);
    }

    setUpAll(() async {
      final projectRoot = await findProjectRoot();
      zfaSourceBin = path.join(projectRoot, 'bin', 'zfa.dart');
    });

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp(
        'zfa_entity_sealed_416_',
      );
      outputDir = path.join(workspace.path, 'lib', 'src', 'domain', 'entities');
      await Directory(outputDir).create(recursive: true);
      // Mirror the dependency gate `zfa entity create` requires:
      // `zorphy_annotation:` + `build_runner:`. `uuid:` mirrors the real
      // app pubspec for autoId entities (harmless when --auto-id is absent).
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_entity_sealed_416_test
environment:
  sdk: ^3.11.0
dependencies:
  uuid: ^4.6.0
  zorphy_annotation: any
  json_annotation: ^4.12.0
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
      '--sealed --generate-subs inlines subtypes into the base library '
      '(no subtype files, no subtype imports, both part directives)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'EngineEvent',
          '--sealed',
          '--fields',
          'id:String,missionId:String',
          '--subtypes',
          'MissionStarted,MissionCompleted,TurnStarted,TurnCompleted,'
              'ThinkingDelta,ToolCallStarted,ToolCallCompleted,ProviderError,'
              'SteeringInjected',
          '--generate-subs',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');

        // The stdout banner must announce the inlining took place.
        expect(
          result.stdout.toString(),
          contains('Inlined 9 sealed subtype(s)'),
          reason: 'expected inlining banner in stdout',
        );

        final baseFile = File(
          path.join(outputDir, 'engine_event', 'engine_event.dart'),
        );
        expect(baseFile.existsSync(), isTrue, reason: 'sealed base file');
        final src = baseFile.readAsStringSync();

        // The base file carries BOTH part directives. The .zorphy.dart one
        // was emitted by Zorphy's template; the .g.dart one is added by
        // the inlining post-processor so `json_serializable` has somewhere
        // to write the per-subtype FromJson/ToJson helpers.
        expect(
          src,
          contains("part 'engine_event.zorphy.dart';"),
          reason: 'zorphy part directive must be present',
        );
        expect(
          src,
          contains("part 'engine_event.g.dart';"),
          reason:
              '.g.dart part directive must be present so json_serializable '
              'can emit helpers for the inlined subtypes',
        );

        // All nine subtypes must be inlined as `implements $$EngineEvent`
        // in the SAME library. Each subtype class declaration travels with
        // its `@Zorphy(...)` annotation.
        const expectedSubtypes = <String>[
          'MissionStarted',
          'MissionCompleted',
          'TurnStarted',
          'TurnCompleted',
          'ThinkingDelta',
          'ToolCallStarted',
          'ToolCallCompleted',
          'ProviderError',
          'SteeringInjected',
        ];
        for (final sub in expectedSubtypes) {
          expect(
            src,
            contains('abstract class \$$sub implements \$\$EngineEvent'),
            reason: 'subtype $sub must be inlined into the base library',
          );
        }

        // NO subtype files may remain on disk — the inlining post-processor
        // deletes the subtype file + its directory.
        for (final sub in expectedSubtypes) {
          // Reuse the same snake-case transform the CLI uses.
          final snake = _camelToSnake(sub);
          final subFile = File(path.join(outputDir, snake, '$snake.dart'));
          expect(
            subFile.existsSync(),
            isFalse,
            reason: 'subtype file for $sub must NOT exist (inlined)',
          );
          final subDir = Directory(path.join(outputDir, snake));
          expect(
            subDir.existsSync(),
            isFalse,
            reason: 'subtype directory for $sub must NOT exist',
          );
        }

        // No cross-library subtype imports in the base file — they would
        // be both redundant and illegal once the subtypes are co-located.
        expect(
          src,
          isNot(contains("import '../mission_started/mission_started.dart';")),
          reason: 'no subtype import for MissionStarted',
        );
        expect(
          src,
          isNot(
            contains("import '../steering_injected/steering_injected.dart';"),
          ),
          reason: 'no subtype import for SteeringInjected',
        );
      },
    );

    test(
      '--sealed WITHOUT --generate-subs leaves the base file untouched '
      '(no subtype files were ever generated)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Shape',
          '--sealed',
          '--fields',
          'id:String',
          '--subtypes',
          'Circle,Square',
          // NOTE: --generate-subs is intentionally absent.
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');

        // No inlining banner — the post-processor only fires when
        // generateSubtypes is true.
        expect(
          result.stdout.toString(),
          isNot(contains('Inlined')),
          reason: 'inlining must not run when --generate-subs is absent',
        );

        final baseFile = File(path.join(outputDir, 'shape', 'shape.dart'));
        expect(baseFile.existsSync(), isTrue);
        final src = baseFile.readAsStringSync();

        // No subtype class declarations inlined — the user did not ask for
        // subtype files, so none were generated and none were inlined.
        expect(
          src,
          isNot(contains('implements \$\$Shape')),
          reason: 'no inlined subtypes when --generate-subs absent',
        );

        // No subtype files on disk either.
        for (final sub in ['Circle', 'Square']) {
          final snake = _camelToSnake(sub);
          final subFile = File(path.join(outputDir, snake, '$snake.dart'));
          expect(
            subFile.existsSync(),
            isFalse,
            reason: 'no $sub file when --generate-subs absent',
          );
        }
      },
    );

    test(
      'NON-sealed --generate-subs preserves the existing behavior '
      '(subtype files exist + base carries per-subtype imports)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Notification',
          '--fields',
          'id:String',
          '--subtypes',
          'EmailNotification,SmsNotification',
          '--generate-subs',
          // NOTE: --sealed is intentionally absent → non-sealed base.
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');

        // No inlining banner — the post-processor only fires when
        // isSealed is true.
        expect(
          result.stdout.toString(),
          isNot(contains('Inlined')),
          reason: 'inlining must NOT run for non-sealed bases',
        );

        final baseFile = File(
          path.join(outputDir, 'notification', 'notification.dart'),
        );
        expect(baseFile.existsSync(), isTrue);
        final src = baseFile.readAsStringSync();

        // Per-subtype imports MUST be present (existing behavior —
        // _addSubtypeImports runs for non-sealed generate-subs).
        expect(
          src,
          contains("import '../email_notification/email_notification.dart';"),
          reason: 'non-sealed base must carry per-subtype imports',
        );
        expect(
          src,
          contains("import '../sms_notification/sms_notification.dart';"),
        );

        // Subtype files MUST exist on disk (existing behavior —
        // Zorphy writes them; inlining never runs for non-sealed).
        for (final sub in ['EmailNotification', 'SmsNotification']) {
          final snake = _camelToSnake(sub);
          final subFile = File(path.join(outputDir, snake, '$snake.dart'));
          expect(
            subFile.existsSync(),
            isTrue,
            reason: 'subtype file for $sub must exist (non-sealed path)',
          );
        }
      },
    );
  });
}

/// Mirror of `StringUtils.camelToSnake` to avoid pulling the helper into
/// the test fixture. Used only to compute the expected on-disk paths.
String _camelToSnake(String camel) {
  if (camel.isEmpty) return camel;
  final sb = StringBuffer();
  for (var i = 0; i < camel.length; i++) {
    final ch = camel[i];
    if (ch.toUpperCase() == ch && ch.toLowerCase() != ch) {
      if (i > 0) sb.write('_');
      sb.write(ch.toLowerCase());
    } else {
      sb.write(ch);
    }
  }
  return sb.toString();
}
