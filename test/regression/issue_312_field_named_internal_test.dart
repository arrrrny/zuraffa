@Tags(['regression', 'slow'])
// Regression test for issue #312.
//
// `zfa entity create -n BooleanCustomFieldConfig --field internal:bool?`
// used to generate property helpers (`hasInternal`/`noInternal`/
// `internalRequired`) that referenced the field BARE:
//
//     extension _ on BooleanCustomFieldConfig {
//       bool get hasInternal => return internal != null;   // <-- bare
//       bool get internalRequired => return internal ?? (throw ...);
//     }
//
// Every Zorphy entity library imports `package:zorphy_annotation/`
// zorphy_annotation.dart`, which re-exports `package:meta/meta.dart`,
// and meta exports a top-level `internal` const (an `Internal` object).
// Inside the generated extension the bare `internal` resolved to that
// top-level const (type `Object`) instead of the instance field, so
// `internalRequired` failed to compile:
//
//     A value of type 'Object' can't be returned from the function
//     'internalRequired' because it has a return type of 'bool'.
//
// Fix (zorphy c4704f1, consumed by zuraffa via the zorphy `development`
// git ref): the property-helper generator now emits `this.<field>` so
// the instance member always wins over any library-exported top-level
// name collision.
//
// This test drives the FULL user-facing flow — `zfa entity create` →
// `dart run build_runner build` → `dart analyze` — for an entity with a
// nullable field named `internal`, and asserts:
//   1. The generated `.zorphy.dart` property helpers reference
//      `this.internal` (NOT bare `internal`).
//   2. `dart analyze` on the generated library reports no issues.
//
// The test mirrors zuraffa's `dependency_overrides` by pointing at the
// local zorphy checkout (`<repoRoot>/../zorphy/zorphy`). It skips
// gracefully when that checkout is absent (e.g. CI without a sibling
// zorphy repo), so it never breaks environments that don't carry the
// dev override.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart';
import '../helpers/run_zfa_source.dart';

void main() {
  group('#312 — field named `internal` (meta.internal collision)', () {
    late Directory workspace;
    late String repoRoot;
    late String zorphyPath;
    late String zorphyAnnotationPath;

    Future<ProcessResult> runDart(List<String> args) =>
        Process.run('dart', args, workingDirectory: workspace.path);

    setUp(() async {
      await initZfaSourceBin();
      repoRoot = await findProjectRoot();
      zorphyPath = p.normalize(p.join(repoRoot, '..', 'zorphy', 'zorphy'));
      zorphyAnnotationPath = p.normalize(
        p.join(repoRoot, '..', 'zorphy', 'zorphy_annotation'),
      );
      workspace = await Directory.systemTemp.createTemp('issue_312_');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      'zfa entity create + build → helpers use this.internal, analyze clean',
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        // Skip when the local zorphy checkout (used by zuraffa's
        // dependency_overrides) is not available — e.g. CI that checks
        // out zuraffa without a sibling zorphy repo. The zorphy `development`
        // git ref in pubspec.yaml still carries the fix in that case.
        final skipReason = _checkLocalZorphy(zorphyPath, zorphyAnnotationPath);
        if (skipReason != null) {
          print(skipReason);
          return;
        }

        // 1. Workspace pubspec — path deps on the local zorphy (mirrors
        //    zuraffa's dependency_overrides) + build_runner + json_serializable.
        await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_312_test_app
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  zorphy:
    path: $zorphyPath
  zorphy_annotation:
    path: $zorphyAnnotationPath
  json_annotation: ^4.12.0
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.13.0
  analyzer: '14.1.0'
dependency_overrides:
  zorphy:
    path: $zorphyPath
  zorphy_annotation:
    path: $zorphyAnnotationPath
  analyzer: '14.1.0'
''');

        // 2. build.yaml — enable the zorphy + json_serializable builders
        //    for everything under lib/.
        await File(p.join(workspace.path, 'build.yaml')).writeAsString('''
targets:
  \$default:
    builders:
      zorphy:zorphy:
        enabled: true
        generate_for:
          - lib/**
      json_serializable:
        enabled: true
        generate_for:
          - lib/**
        options:
          explicit_to_json: false
          include_if_null: false
''');

        // 3. Create the entity. `internal:bool?` is the field that used
        //    to collide with `meta.internal`. `id:String` is a required
        //    non-null field so the entity is well-formed.
        final createResult = await runZfaSource([
          'entity',
          'create',
          '-n',
          'BooleanCustomFieldConfig',
          '--field',
          'id:String',
          '--field',
          'internal:bool?',
        ], workingDirectory: workspace.path);
        expect(
          createResult.exitCode,
          0,
          reason:
              'entity create failed: '
              '${createResult.stdout}${createResult.stderr}',
        );

        final entitySourcePath = p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'boolean_custom_field_config',
          'boolean_custom_field_config.dart',
        );
        expect(
          File(entitySourcePath).existsSync(),
          isTrue,
          reason: 'entity source file was not written',
        );

        // 4. Resolve deps + run build_runner to generate the
        //    `.zorphy.dart` (which carries the property helpers).
        final pubGet = await runDart(['pub', 'get']);
        expect(
          pubGet.exitCode,
          0,
          reason: 'dart pub get failed: ${pubGet.stdout}${pubGet.stderr}',
        );

        final build = await runDart(['run', 'build_runner', 'build']);
        expect(
          build.exitCode,
          0,
          reason: 'build_runner failed: ${build.stdout}${build.stderr}',
        );

        // 5. Read the generated .zorphy.dart.
        final zorphyFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'boolean_custom_field_config',
            'boolean_custom_field_config.zorphy.dart',
          ),
        );
        expect(
          zorphyFile.existsSync(),
          isTrue,
          reason: '.zorphy.dart was not generated by build_runner',
        );
        final generated = zorphyFile.readAsStringSync();

        // 6. Assert the three property helpers exist and reference
        //    `this.internal` (the instance member), NOT a bare `internal`
        //    that would resolve to the meta top-level const.
        expect(
          generated,
          contains('hasInternal'),
          reason: 'hasInternal helper missing',
        );
        expect(
          generated,
          contains('this.internal != null'),
          reason:
              'hasInternal must use `this.internal` — a bare `internal` '
              'resolves to meta\'s top-level `internal` const (Object) and '
              'fails to compile (#312).',
        );

        expect(
          generated,
          contains('noInternal'),
          reason: 'noInternal helper missing',
        );
        expect(
          generated,
          contains('this.internal == null'),
          reason: 'noInternal must use `this.internal`',
        );

        expect(
          generated,
          contains('internalRequired'),
          reason: 'internalRequired helper missing',
        );
        expect(
          generated,
          contains('this.internal ??'),
          reason:
              'internalRequired must use `this.internal` — this is the '
              'exact getter that produced "A value of type \'Object\' can\'t '
              'be returned..." before the fix.',
        );

        // Negative: no bare `return internal` (without `this.`) may
        // appear anywhere in the generated helpers. `return this.internal`
        // is fine; `return internalRequired` is fine (no word boundary
        // after `internal`); a bare `return internal != null` is the bug.
        final bareInternal = RegExp(
          r'return\s+internal\b',
        ).firstMatch(generated);
        expect(
          bareInternal,
          isNull,
          reason:
              'generated helpers must not contain a bare `return internal` — '
              'that is the #312 regression (meta.internal collision). '
              'Found: ${bareInternal?.group(0)}',
        );

        // 7. `dart analyze` on the generated library must be clean.
        //    Before the fix, this reported:
        //      error: A value of type 'Object' can't be returned from the
        //      function 'internalRequired' because it has a return type of
        //      'bool'.
        final analyze = await runDart(['analyze', 'lib']);
        expect(
          analyze.exitCode,
          0,
          reason:
              'dart analyze reported issues (the #312 symptom):\n'
              '${analyze.stdout}${analyze.stderr}',
        );
      },
    );
  });
}

/// Returns `null` if both local zorphy package paths exist, otherwise a
/// human-readable skip reason.
String? _checkLocalZorphy(String zorphyPath, String zorphyAnnotationPath) {
  if (!Directory(zorphyPath).existsSync()) {
    return 'Skipping: local zorphy checkout not found at $zorphyPath '
        '(CI without a sibling zorphy repo). The fix is still carried by '
        'the zorphy `development` git ref in pubspec.yaml.';
  }
  if (!Directory(zorphyAnnotationPath).existsSync()) {
    return 'Skipping: local zorphy_annotation checkout not found at '
        '$zorphyAnnotationPath.';
  }
  return null;
}
