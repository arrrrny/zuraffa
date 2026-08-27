@Tags(['regression', 'slow'])
// Regression test for issue #351.
//
// When a Zorphy entity has a field whose declared type is the CONCRETE form
// of another Zorphy entity (e.g. `ParentThing? get parent` with no `$`
// prefix), the analyzer cannot resolve the type during `build_runner`
// (the concrete class is generated into a `.zorphy.dart` PART file that is
// not yet in the analysis session). Before the fix, `typeToString` fell
// back to `InvalidType`, which broke `json_serializable` and `zfa build`.
//
// This is the build-side half of the cross-entity reference story:
//   - #315 (forward refs): `zfa entity create` emits `$ParentThing?` (with
//     the `$`) so the abstract type resolves in the source library. The
//     build succeeds.
//   - #349 (external types): `zfa entity create` emits the plain type
//     (no `$`) for hand-written non-Zorphy classes. The build succeeds.
//   - #351 (THIS): the user HAND-FIXES the source to change `$ParentThing?`
//     → `ParentThing?` (the documented #349 workaround applied to entity
//     types), OR a migration source carries concrete sibling-entity refs.
//     The build emits `InvalidType` and fails.
//
// The fix (zorphy c09d966, consumed by zuraffa via the zorphy git ref +
// the local `dependency_overrides` path): `getAllFields` now falls back to
// `recoverTypeFromSource` when `typeToString` returns `InvalidType`, and
// the recovery's text-search fallback handles field/getter declarations
// (`Type get name` and `Type name;`), not just constructor parameters.
//
// Secondary finding: a `dynamic` field no longer emits
// `required dynamic this.x` in the constructor (dynamic is already
// nullable) or `dynamic?` in copyWith/patch methods.
//
// This test drives the FULL user-facing flow:
//   1. `zfa entity create -n ParentThing --kind=value_object --field name:String`
//   2. `zfa entity create -n ChildThing --kind=value_object --allow-forward-refs
//      --field parent:ParentThing?`
//      → source has `$ParentThing? get parent;`
//   3. HAND-FIX: `$ParentThing?` → `ParentThing?` (the #349 workaround)
//   4. `dart run build_runner build`
//   5. Assert: generated `child_thing.zorphy.dart` has `final ParentThing?
//      parent;` (NOT `InvalidType`), constructor has `ParentThing? this.parent`
//      (NOT `required InvalidType this.parent`), and a `dynamic` field has
//      `dynamic this.data` (NOT `required dynamic this.data`).
//   6. `dart analyze` on the generated library reports no `InvalidType` error.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart';

void main() {
  group('#351 — cross-entity concrete reference (no `\$` prefix)', () {
    late Directory workspace;
    late String repoRoot;
    late String zfaBin;
    late String zorphyPath;
    late String zorphyAnnotationPath;

    Future<ProcessResult> runDart(List<String> args) =>
        Process.run('dart', args, workingDirectory: workspace.path);

    setUp(() async {
      repoRoot = await findProjectRoot();
      zfaBin = p.join(repoRoot, 'bin', 'zfa.dart');
      zorphyPath = p.normalize(p.join(repoRoot, '..', 'zorphy', 'zorphy'));
      zorphyAnnotationPath = p.normalize(
        p.join(repoRoot, '..', 'zorphy', 'zorphy_annotation'),
      );
      workspace = await Directory.systemTemp.createTemp('issue_351_');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      'concrete cross-entity ref: ChildThing.parent resolves to ParentThing?, '
      'no InvalidType; dynamic field is NOT required',
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        final skipReason = _checkLocalZorphy(zorphyPath, zorphyAnnotationPath);
        if (skipReason != null) {
          print(skipReason);
          return;
        }

        // 1. Workspace pubspec — path deps on the local zorphy (mirrors
        //    zuraffa's dependency_overrides).
        await _writePubspec(workspace, zorphyPath, zorphyAnnotationPath);
        await _writeBuildYaml(workspace);

        // 2. Create the referenced entity: ParentThing (value object).
        final parentResult = await Process.run('dart', [
          zfaBin,
          'entity',
          'create',
          '-n',
          'ParentThing',
          '--kind=value_object',
          '--field',
          'name:String',
        ], workingDirectory: workspace.path);
        expect(
          parentResult.exitCode,
          0,
          reason:
              'entity create (ParentThing) failed: '
              '${parentResult.stdout}${parentResult.stderr}',
        );

        // 3. Create the referencing entity: ChildThing with `parent:ParentThing?`.
        //    `--allow-forward-refs` is used so the type validator doesn't
        //    abort on the entity type. The source will emit
        //    `$ParentThing? get parent;` (the #315 behavior).
        final childResult = await Process.run('dart', [
          zfaBin,
          'entity',
          'create',
          '-n',
          'ChildThing',
          '--kind=value_object',
          '--allow-forward-refs',
          '--field',
          'parent:ParentThing?',
          '--field',
          'data:dynamic',
        ], workingDirectory: workspace.path);
        expect(
          childResult.exitCode,
          0,
          reason:
              'entity create (ChildThing) failed: '
              '${childResult.stdout}${childResult.stderr}',
        );

        // 4. Read the ChildThing source and HAND-FIX it: change
        //    `$ParentThing? get parent;` → `ParentThing? get parent;`
        //    (the documented #349 workaround applied to an entity type —
        //    this is the #351 trigger).
        final childSourcePath = p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'child_thing',
          'child_thing.dart',
        );
        expect(
          File(childSourcePath).existsSync(),
          isTrue,
          reason: 'ChildThing entity source file was not written',
        );
        var childSource = File(childSourcePath).readAsStringSync();

        // Verify the source currently has the `$`-prefixed form (sanity).
        expect(
          childSource,
          contains(r'$ParentThing? get parent;'),
          reason:
              'Expected the source to declare `\$ParentThing? get parent;` '
              'before the hand-fix. If this fails, the #315 prefix logic '
              'has changed and this test needs updating.',
        );

        // Apply the #349 hand-fix: drop the `$` prefix on the entity ref.
        childSource = childSource.replaceAll(
          r'$ParentThing? get parent;',
          'ParentThing? get parent;',
        );
        File(childSourcePath).writeAsStringSync(childSource);

        // Sanity: the hand-fix took effect.
        expect(
          childSource,
          contains('ParentThing? get parent;'),
          reason: 'Hand-fix did not apply',
        );
        expect(
          childSource,
          isNot(contains(r'$ParentThing? get parent;')),
          reason: 'Hand-fix did not fully remove the `\$` prefix',
        );

        // 5. Resolve deps + run build_runner to generate the `.zorphy.dart`.
        final pubGet = await runDart(['pub', 'get']);
        expect(
          pubGet.exitCode,
          0,
          reason: 'dart pub get failed: ${pubGet.stdout}${pubGet.stderr}',
        );

        final build = await runDart([
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ]);
        expect(
          build.exitCode,
          0,
          reason:
              'build_runner failed (the #351 symptom — '
              'json_serializable: final InvalidType parent;):\n'
              '${build.stdout}${build.stderr}',
        );

        // 6. Read the generated ChildThing.zorphy.dart. The concrete class
        //    MUST use the resolved concrete type, NOT `InvalidType`.
        final zorphyFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'child_thing',
            'child_thing.zorphy.dart',
          ),
        );
        expect(
          zorphyFile.existsSync(),
          isTrue,
          reason: '.zorphy.dart was not generated by build_runner',
        );
        final generated = zorphyFile.readAsStringSync();

        // CRITICAL: no `InvalidType` may appear anywhere in the generated
        // output. Before the fix, the concrete class had
        // `final InvalidType parent;`.
        expect(
          generated,
          isNot(contains('InvalidType')),
          reason:
              '`InvalidType` in the generated output is the direct symptom '
              'of #351 — the concrete (no-`\$`) cross-entity reference '
              'could not be resolved by the analyzer.',
        );

        // The field must be `final ParentThing? parent;`.
        expect(
          generated,
          contains('final ParentThing? parent;'),
          reason:
              'The concrete ChildThing class must declare '
              '`final ParentThing? parent;` (recovered concrete type).',
        );

        // The constructor param must be `ParentThing? this.parent` (NOT
        // `required InvalidType this.parent` or `required ParentThing? this.parent`).
        expect(
          generated,
          contains('ParentThing? this.parent'),
          reason:
              'The constructor must use `ParentThing? this.parent` '
              '(recovered type, no spurious `required`).',
        );

        // Secondary: the `dynamic` field must NOT be `required dynamic this.data`.
        expect(
          generated,
          isNot(contains('required dynamic this.data')),
          reason:
              '`dynamic` is already nullable — the constructor must NOT '
              'emit `required dynamic this.data`. This is the #351 '
              'secondary finding.',
        );
        expect(
          generated,
          contains('dynamic this.data'),
          reason:
              'The constructor must use `dynamic this.data` (no `required`).',
        );

        // Secondary: no `dynamic?` in copyWith / patch methods.
        expect(
          generated,
          isNot(contains('dynamic?')),
          reason:
              '`dynamic?` is redundant (dynamic is already nullable). '
              'This is the #351 secondary finding — copyWith and patch '
              'methods must use plain `dynamic`, not `dynamic?`.',
        );

        // 7. `dart analyze` on the generated library must not report any
        //    `InvalidType` error.
        final analyze = await runDart(['analyze', 'lib']);
        final analyzeOut =
            analyze.stdout.toString() + analyze.stderr.toString();
        final invalidTypeError = RegExp(
          r'error\s*-.*InvalidType',
        ).firstMatch(analyzeOut);
        expect(
          invalidTypeError,
          isNull,
          reason:
              'dart analyze reported an `InvalidType` error — that is the '
              'direct #351 symptom:\n$analyzeOut',
        );
      },
    );
  });
}

// ----------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------

/// Returns `null` if both local zorphy package paths exist, otherwise a
/// human-readable skip reason.
String? _checkLocalZorphy(String zorphyPath, String zorphyAnnotationPath) {
  if (!Directory(zorphyPath).existsSync()) {
    return 'Skipping: local zorphy checkout not found at $zorphyPath '
        '(CI without a sibling zorphy repo). The fix is still carried by '
        'the zorphy git ref in pubspec.yaml.';
  }
  if (!Directory(zorphyAnnotationPath).existsSync()) {
    return 'Skipping: local zorphy_annotation checkout not found at '
        '$zorphyAnnotationPath.';
  }
  return null;
}

/// Writes the workspace pubspec.yaml with path deps on the local zorphy
/// (mirrors zuraffa's `dependency_overrides`).
Future<void> _writePubspec(
  Directory workspace,
  String zorphyPath,
  String zorphyAnnotationPath,
) async {
  await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_351_test_app
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
}

/// Writes a build.yaml enabling the zorphy + json_serializable builders.
Future<void> _writeBuildYaml(Directory workspace) async {
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
}
