// Regression test for issue #313.
//
// `zfa entity create -n Facet --field values:List<FacetValue>?` generated
// `enum Facet$ { ..., values }` — illegal in Dart because `values` collides
// with the implicit `Enum.values` static member. The generated
// `facet.zorphy.dart` failed at `zfa build` time with:
//
//   E facet.zorphy.dart: A member named 'values' can't be declared in an enum.
//
// Root cause: zorphy's patch generator emitted field names verbatim as
// enum members in the field-list enum (`Entity$`) used by the Patch
// machinery. There was no escape for names reserved by `Enum` (`values`,
// `index`, `name`).
//
// The fix lives in zorphy (commit c4704f1, merged via zorphy/development):
//   - `zorphy/lib/src/helpers.dart` adds `enumMemberName(fieldName)` which
//     appends `_` to reserved names (`values` -> `values_`, also `index`
//     and `name`).
//   - `zorphy/lib/src/generators/patch_generator.dart` uses
//     `enumMemberName(f.name)` consistently in:
//       * the field-list enum declaration,
//       * every `_patchMap.containsKey(Entity$.<member>)` reference,
//       * every `_patchMap[Entity$.<member>]` lookup,
//       * every `patchMap[Entity$.<member>] = ...` setter in the Patch
//         builder.
//
// This test exercises the fix end-to-end via the real `zfa` CLI binary
// (Process.run on `bin/zfa.dart`), running the full
// `zfa entity create` -> `dart pub get` -> `dart run build_runner build`
// pipeline so a future zorphy rollback or zuraffa-side wiring change
// cannot silently reintroduce the bug.
//
// Coverage:
//   1. The exact reproduction from the issue (Facet with `values` field).
//   2. The field-list enum escapes `values` -> `values_`.
//   3. Every `Facet$.values_` reference site (containsKey, lookup, setter)
//      uses the escaped name consistently.
//   4. The property helper uses `this.values` (not the bare `values`
//      which would resolve to the meta const when the field is named
//      `internal` — same fix commit c4704f1, issue #312).
//   5. `dart analyze` on the generated source reports no issues.
//   6. Sanity: the generated source does NOT contain a raw `Facet$.values`
//      token (non-escaped) — the original bug.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart';

/// Resolve package root at discovery time, before any test changes CWD.
late final String _zfaRoot;

/// Zorphy checkout path, computed from the zuraffa root
/// (`<zfaRoot>/../zorphy`). Zuraffa's own `pubspec.yaml` has a path
/// override pointing at `../zorphy/zorphy`, so the zorphy checkout is
/// expected to live alongside the zuraffa checkout. This matches the
/// layout in CI and in agent sandboxes.
String get _zorphyRoot => p.normalize(p.join(_zfaRoot, '..', 'zorphy'));

void main() {
  group('#313 — zfa entity create with field named `values`', () {
    late Directory workspace;
    late String zfaBin;

    Future<ProcessResult> runZfa(List<String> args) {
      return Process.run('dart', [zfaBin, ...args],
          workingDirectory: workspace.path);
    }

    Future<ProcessResult> runDart(List<String> args) {
      return Process.run('dart', args, workingDirectory: workspace.path);
    }

    setUpAll(() async {
      _zfaRoot = await findProjectRoot();
      zfaBin = p.join(_zfaRoot, 'bin', 'zfa.dart');
    });

    setUp(() async {
      // Recover CWD in case a previous test file deleted its temp dir.
      await findProjectRoot();
      workspace = await Directory.systemTemp.createTemp('issue_313_');

      // Pubspec: depend on zuraffa via path so the zorphy builder +
      // json_serializable are pulled in transitively. We also list
      // `zorphy_annotation` directly because `EntityCommand`'s dependency
      // check scans pubspec.yaml for the literal string `zorphy_annotation:`
      // before doing any work. The `dependency_overrides` section pins
      // both `zorphy` and `zorphy_annotation` to the local checkout
      // (mirroring zuraffa's own pubspec) so the fixed zorphy is what
      // actually generates the .zorphy.dart file.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_313_test_app
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  zuraffa:
    path: $_zfaRoot
  zorphy_annotation:
    path: ${p.join(_zorphyRoot, 'zorphy_annotation')}
  json_annotation: ^4.12.0
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.9.0
dependency_overrides:
  zorphy:
    path: ${p.join(_zorphyRoot, 'zorphy')}
  zorphy_annotation:
    path: ${p.join(_zorphyRoot, 'zorphy_annotation')}
''');

      // build.yaml: enable the zorphy builder for lib/src/**. This mirrors
      // zuraffa's own build.yaml so build_runner invokes zorphy on the
      // generated entity file.
      await File(p.join(workspace.path, 'build.yaml')).writeAsString('''
targets:
  \$default:
    builders:
      zorphy:zorphy:
        enabled: true
        generate_for:
          - lib/src/**
      json_serializable:
        enabled: true
        generate_for:
          - lib/src/**
        options:
          explicit_to_json: false
          include_if_null: false
          generic_argument_factories: true
      source_gen:combining_builder:
        enabled: true
''');
    });

    tearDown(() async {
      // NOTE: never call `Directory.current =` here. Tests pass
      // `workingDirectory` to Process.run, so CWD is never changed.
      if (workspace.existsSync()) {
        try {
          await workspace.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup; temp dirs are OS-reaped.
        }
      }
    });

    /// Returns the generated .zorphy.dart file (assumed to exist).
    File zorphyFile(String snakeName) {
      return File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          snakeName,
          '$snakeName.zorphy.dart',
        ),
      );
    }

    test(
      'field named `values` generates a valid escaped enum member + '
      'consistent patchMap references (exact repro from the issue)',
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        // Step 1: resolve dependencies. Must happen BEFORE zfa entity create
        // so build_runner can find the zorphy builder when invoked.
        final pubGet = await runDart(['pub', 'get']);
        expect(
          pubGet.exitCode,
          equals(0),
          reason: 'dart pub get failed: ${pubGet.stderr}',
        );

        // Step 2: create the Facet entity with a `values` field.
        // Using `List<String>?` to avoid needing a separate FacetValue
        // entity — the bug is about the field NAME, not the type.
        final create = await runZfa([
          'entity',
          'create',
          '-n',
          'Facet',
          '--field',
          'id:String',
          '--field',
          'values:List<String>?',
        ]);
        expect(
          create.exitCode,
          equals(0),
          reason: 'zfa entity create failed: ${create.stderr}',
        );
        expect(
          create.stdout.toString(),
          contains('Created entity'),
          reason: 'zfa entity create should report success',
        );

        // Step 3: run build_runner to generate the .zorphy.dart file.
        // This is the step that would fail (analyzer error) without the fix.
        final build = await runDart([
          'run',
          'build_runner',
          'build',
        ]);
        expect(
          build.exitCode,
          equals(0),
          reason:
              'build_runner failed (this is the #313 bug if it errors with '
              '"A member named \'values\' can\'t be declared in an enum").\n'
              'stdout: ${build.stdout}\nstderr: ${build.stderr}',
        );

        // Step 4: verify the .zorphy.dart file exists.
        final file = zorphyFile('facet');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'facet.zorphy.dart must be generated by build_runner',
        );
        final src = await file.readAsString();

        // --------------------------------------------------------------
        // Positive: the field-list enum escapes `values` -> `values_`.
        // --------------------------------------------------------------
        // The enum declaration line: `enum Facet$ { id, values_ }`
        // Use contains(RegExp(...)) which uses hasMatch (searches the
        // entire string), NOT a bare RegExp (which uses matchAsPrefix
        // and only matches at position 0).
        expect(
          src,
          contains('enum Facet\$ {'),
          reason: 'field-list enum Facet\$ must be emitted',
        );
        expect(
          src,
          contains(RegExp(r'enum\s+Facet\$\s*\{[^}]*\bvalues_\b[^}]*\}')),
          reason:
              'enum Facet\$ must have a `values_` member (escaped), '
              'not `values` (which collides with Enum.values)',
        );

        // Negative: the enum declaration must NOT contain a bare `values`
        // member. The original bug emitted `enum Facet$ { id, values }`.
        final enumDecl = RegExp(
          r'enum\s+Facet\$\s*\{([^}]*)\}',
        ).firstMatch(src);
        expect(
          enumDecl,
          isNotNull,
          reason: 'Could not locate enum Facet\$ { ... } declaration',
        );
        final enumBody = enumDecl!.group(1)!;
        expect(
          enumBody,
          isNot(RegExp(r'\bvalues\b(?!\w)')),
          reason:
              'enum body must NOT contain a bare `values` token — '
              'must be escaped to `values_`. Enum body: `$enumBody`',
        );

        // --------------------------------------------------------------
        // Positive: every patchMap reference site uses `Facet$.values_`.
        // --------------------------------------------------------------
        // containsKey check
        expect(
          src,
          contains('_patchMap.containsKey(Facet\$.values_)'),
          reason: 'containsKey must reference Facet\$.values_ (escaped)',
        );
        // patchMap[key] lookup (appears multiple times — function/Patch/value
        // branches).
        expect(
          src,
          contains('_patchMap[Facet\$.values_]'),
          reason: 'patchMap lookup must use Facet\$.values_ (escaped)',
        );
        // Patch setter: `patchMap[Facet$.values_] = value;`
        expect(
          src,
          contains('patchMap[Facet\$.values_] = value;'),
          reason: 'withValues setter must use Facet\$.values_ (escaped)',
        );

        // --------------------------------------------------------------
        // Negative: no raw `Facet$.values` token (non-escaped reference).
        // The pattern `Facet$.values` NOT followed by `_` is the bug.
        // --------------------------------------------------------------
        expect(
          src,
          isNot(contains(RegExp(r'Facet\$\.values(?!\w)'))),
          reason:
              'Generated source must NOT contain a raw `Facet\$.values` '
              'token (non-escaped). All references must be `Facet\$.values_`.',
        );

        // --------------------------------------------------------------
        // Positive (bonus #312 coverage): property helper uses `this.values`
        // — the same zorphy commit c4704f1 also fixed `internal` by
        // this.-qualifying property helpers.
        // --------------------------------------------------------------
        expect(
          src,
          contains('return this.values'),
          reason:
              'Property helper for `values` must use `this.values` '
              '(not bare `values` which can collide with meta.const when '
              'the field is named `internal` — same fix commit, issue #312)',
        );

        // --------------------------------------------------------------
        // Final: `dart analyze` on the generated source reports no issues.
        // This is the ultimate proof the original bug
        // ("A member named 'values' can't be declared in an enum") is gone.
        // --------------------------------------------------------------
        final analyze = await runDart([
          'analyze',
          'lib/src/domain/entities/facet',
        ]);
        expect(
          analyze.exitCode,
          equals(0),
          reason:
              'dart analyze must report no issues on the generated entity. '
              'This is the exact analyzer error from issue #313 if it fails.\n'
              'stdout: ${analyze.stdout}\nstderr: ${analyze.stderr}',
        );
      },
    );

    test(
      'field named `index` is also escaped (defense-in-depth for the '
      'Enum.index reserved member)',
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        // `index` is another implicit Enum member that must be escaped.
        // The fix's _reservedEnumMemberNames set includes `index` and `name`
        // alongside `values` — this test verifies that coverage.
        final pubGet = await runDart(['pub', 'get']);
        expect(pubGet.exitCode, equals(0),
            reason: 'dart pub get failed: ${pubGet.stderr}');

        final create = await runZfa([
          'entity',
          'create',
          '-n',
          'Page',
          '--field',
          'id:String',
          '--field',
          'index:int',
        ]);
        expect(create.exitCode, equals(0),
            reason: 'zfa entity create failed: ${create.stderr}');

        final build = await runDart(['run', 'build_runner', 'build']);
        expect(
          build.exitCode,
          equals(0),
          reason:
              'build_runner failed for `index` field — same enum-reserved '
              'escape must apply.\nstdout: ${build.stdout}\n'
              'stderr: ${build.stderr}',
        );

        final file = zorphyFile('page');
        expect(file.existsSync(), isTrue);
        final src = await file.readAsString();

        // The field-list enum must escape `index` -> `index_`.
        expect(
          src,
          contains(RegExp(r'enum\s+Page\$\s*\{[^}]*\bindex_\b[^}]*\}')),
          reason: 'enum Page\$ must have `index_` member (escaped)',
        );

        // Every Page$.index_ reference site is escaped.
        expect(src, contains('Page\$.index_'));

        // No raw `Page$.index` (non-escaped) reference.
        expect(
          src,
          isNot(contains(RegExp(r'Page\$\.index(?!\w)'))),
          reason: 'No raw `Page\$.index` token allowed',
        );

        final analyze = await runDart([
          'analyze',
          'lib/src/domain/entities/page',
        ]);
        expect(
          analyze.exitCode,
          equals(0),
          reason: 'dart analyze must pass on the generated `index` field.\n'
              'stdout: ${analyze.stdout}\nstderr: ${analyze.stderr}',
        );
      },
    );
  });
}
