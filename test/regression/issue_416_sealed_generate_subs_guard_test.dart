@Tags(['regression', 'slow'])
// Regression test for issue #416.
//
// `zfa entity create --sealed --generate-subs` used to delegate to
// package:zorphy, which wrote every subtype as its own library that
// `implements` the sealed parent. Because Dart requires all direct subtypes of
// a `sealed` class to live in the parent's library, `dart analyze` failed with
// one `invalid_use_of_type_outside_library` per subtype (9 in the reported
// case).
//
// The upstream fix (inlining sealed subtypes into the parent library) belongs
// in `arrrrny/zorphy`. Until it lands, zuraffa must refuse the unsupported
// combination up front — before writing anything — with actionable guidance.
//
// This test drives the real `zfa` CLI binary via Process.run on `bin/zfa.dart`
// and asserts that `--sealed --generate-subs` is rejected before any file is
// written.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  group('#416 — zfa entity create: reject --sealed --generate-subs', () {
    late Directory workspace;
    Future<ProcessResult> runZfa(List<String> args) =>
        runZfaSource(args, workingDirectory: workspace.path);

    setUp(() async {
      await initZfaSourceBin();
      workspace = await Directory.systemTemp.createTemp('issue_416_');
      // Minimal pubspec so the entity command's dependency check (scans for
      // `zorphy_annotation:` and `build_runner:`) succeeds without running
      // `dart pub get`. The string check is enough here.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_416_test_app
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  zorphy_annotation:
dev_dependencies:
  build_runner:
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    /// Path to the generated entity source file for [snakeName].
    File entityFile(String snakeName) => File(
      p.join(
        workspace.path,
        'lib',
        'src',
        'domain',
        'entities',
        snakeName,
        '$snakeName.dart',
      ),
    );

    test(
      '`--sealed --generate-subs` is rejected before writing files',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'EngineEvent',
          '--sealed',
          '--fields',
          'id:String,missionId:String',
          '--subtypes',
          'MissionStarted,MissionCompleted,TurnStarted',
          '--generate-subs',
        ]);

        // The fix: refuse the invalid combination up front instead of
        // emitting separate libraries that cannot compile.
        expect(
          result.exitCode,
          isNot(equals(0)),
          reason:
              '`--sealed --generate-subs` must be rejected. '
              'stderr: ${result.stdout}${result.stderr}',
        );

        // No files should have been written for the rejected entity.
        expect(
          entityFile('engine_event').existsSync(),
          isFalse,
          reason: 'no sealed entity file should exist after a rejected create',
        );
        expect(
          entityFile('mission_started').existsSync(),
          isFalse,
          reason:
              'no subtype file should exist after a rejected create '
              '(that is the #416 bug)',
        );

        final output = result.stdout + result.stderr;

        // The error must explain the sealed-library rule and point at the
        // two supported workarounds.
        expect(
          output,
          contains('sealed'),
          reason: 'error must mention `sealed`',
        );
        expect(
          output,
          contains('generate-subs'),
          reason: 'error must mention `--generate-subs`',
        );
        expect(
          output,
          contains('invalid_use_of_type_outside_library'),
          reason: 'error must name the analyzer error the bug produced',
        );
        expect(
          output,
          contains('416'),
          reason: 'error must reference the issue for follow-up',
        );
      },
    );

    test(
      '`--sealed` WITHOUT `--generate-subs` still succeeds',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // The guard must not over-trigger: a sealed entity without subtype
        // generation is valid and must be created.
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'ValidSealed',
          '--sealed',
          '--fields',
          'id:String',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason: '`--sealed` alone must succeed. stderr: ${result.stderr}',
        );
        expect(
          entityFile('valid_sealed').existsSync(),
          isTrue,
          reason: 'sealed entity file must be written',
        );
      },
    );
  });
}
