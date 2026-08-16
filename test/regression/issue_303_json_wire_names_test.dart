// Regression test for issue #303.
//
// `zfa entity create` had no way to express a Dart field name different
// from the JSON wire name. Three concrete failures:
//
//   1. `zfa entity create -n IdOperators --field 'in_:String'` succeeded
//      but emitted JSON key `'in_'` in the generated `.g.dart` instead of
//      `'in'` — a silent wire-contract break.
//
//   2. `zfa entity create -n X --field 'in:String'` accepted the keyword
//      and wrote `String get in;` into the entity source — invalid Dart —
//      and `zfa build` then failed with
//      `'in' can't be used as an identifier because it's a keyword.`
//
//   3. `zfa entity create -n HistoryEntryFilterParameter --field and:...`
//      emitted JSON keys `'and'`/`'or'`, not the Vendure wire keys
//      `'_and'`/`'_or'`.
//
//   4. `zfa entity from-json` had the same limitation —
//      `_extractFieldsFromJson` only read names/types.
//
// The fix (zorphy#80 — `FieldDefinition.jsonName` + the
// `name:type:json=<wire>` field syntax — already merged into zorphy
// development) is consumed by zuraffa via the zorphy `development` git
// ref. This test exercises the zuraffa-side wiring:
//
//   - `entity create` / `entity add-field` accept `:json=<wire>` and the
//     emitted source carries `@JsonKey(name: '<wire>')` on the getter.
//   - Raw Dart-keyword field names (e.g. `in:String`) are rejected up
//     front with an actionable error that points to `:json=<wire>`.
//   - `entity from-json` auto-resolves Dart-keyword and `_`-prefixed
//     JSON keys to a Dart-safe name + jsonName pair (no `:json=` needed).
//   - The generated source parses (no Dart-keyword identifier break).
//
// The tests drive the real `zfa` CLI binary via Process.run on
// `bin/zfa.dart`. The full build_runner round-trip (`.g.dart` emitting
// `'in': instance.in_`) is verified in a dedicated test that mirrors
// zuraffa's `dependency_overrides` (local zorphy checkout).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart';

void main() {
  group('#303 — zfa entity create: Dart-keyword field names + JSON wire names', () {
    late Directory workspace;
    late String repoRoot;
    late String zfaBin;
    late String zorphyPath;
    late String zorphyAnnotationPath;

    Future<ProcessResult> runDart(List<String> args) =>
        Process.run('dart', args, workingDirectory: workspace.path);

    Future<ProcessResult> runZfa(List<String> args) => Process.run('dart', [
      zfaBin,
      ...args,
    ], workingDirectory: workspace.path);

    setUp(() async {
      repoRoot = await findProjectRoot();
      zfaBin = p.join(repoRoot, 'bin', 'zfa.dart');
      zorphyPath = p.normalize(p.join(repoRoot, '..', 'zorphy', 'zorphy'));
      zorphyAnnotationPath = p.normalize(
        p.join(repoRoot, '..', 'zorphy', 'zorphy_annotation'),
      );
      workspace = await Directory.systemTemp.createTemp('issue_303_');
      // Minimal pubspec so the entity command's dependency check (which
      // scans for `zorphy_annotation:` and `build_runner:`) succeeds
      // without running `dart pub get`. The string check is enough for
      // entity source generation; build_runner is only invoked in the
      // dedicated end-to-end test.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_303_test_app
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
    File entityFile(String snakeName) {
      return File(
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
    }

    /// Asserts the generated file parses as valid Dart. `dart format` exits
    /// non-zero on any syntax error, so a raw keyword getter (`String get in;`)
    /// or any other break in the emitted source cannot slip through.
    Future<void> expectFormats(File file) async {
      final result = await Process.run('dart', [
        'format',
        '--output=none',
        file.path,
      ], workingDirectory: workspace.path);
      expect(
        result.exitCode,
        equals(0),
        reason:
            'generated ${file.path} must parse as valid Dart '
            '(exit ${result.exitCode}): ${result.stdout}${result.stderr}',
      );
    }

    test(
      '`in_:String:json=in` emits @JsonKey(name: \'in\') on the getter',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'IdOperators',
          '--field',
          'in_:String:json=in',
          '--field',
          'eq:String',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason:
              'zfa entity create must accept the :json= wire syntax. '
              'stderr: ${result.stderr}',
        );

        final file = entityFile('id_operators');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'entity file must be written',
        );
        final src = await file.readAsString();

        // The fix: the getter is named `in_` (Dart-safe) and carries
        // `@JsonKey(name: 'in')` so json_serializable serializes with the
        // `in` wire key (preserving the Vendure contract).
        expect(
          src,
          contains("@JsonKey(name: 'in')"),
          reason: '@JsonKey(name: \'in\') must annotate the in_ getter',
        );
        expect(
          src,
          contains('String get in_;'),
          reason: 'Dart-safe getter name `in_` must be emitted',
        );

        // Negative: the raw keyword `in` must NOT appear as a getter
        // identifier. Matches `get in;` (the broken pre-fix form).
        expect(
          src,
          isNot(RegExp(r'get\s+in\s*;')),
          reason: 'raw `get in;` must not appear — that is the #303 bug',
        );

        // The plain `eq` field carries no @JsonKey (name matches wire).
        expect(src, contains('String get eq;'));
        expect(
          src,
          isNot(contains("@JsonKey(name: 'eq')")),
          reason: 'no @JsonKey needed when Dart name == wire name',
        );

        await expectFormats(file);

        // Success message should make the wire-name remap visible.
        expect(
          result.stdout,
          contains("in_: String (json: 'in')"),
          reason: 'success message must show the json wire name',
        );
      },
    );

    test(
      'raw `--field in:String` (Dart keyword) is rejected up front',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'TestKeyword',
          '--field',
          'in:String',
        ]);

        // The fix: the CLI refuses the bare-keyword form BEFORE writing
        // anything — instead of emitting `String get in;` and failing
        // later at `zfa build` with a misleading analyzer error.
        expect(
          result.exitCode,
          isNot(equals(0)),
          reason: 'raw Dart-keyword field name must be rejected',
        );

        // No file should have been written.
        expect(
          entityFile('test_keyword').existsSync(),
          isFalse,
          reason: 'no entity file should exist after a rejected create',
        );

        // The error message must point the user at the `:json=<wire>` fix.
        expect(
          result.stdout + result.stderr,
          contains('Dart keyword'),
          reason: 'error must explain the keyword collision',
        );
        expect(
          result.stdout + result.stderr,
          contains('in_'),
          reason: 'error must suggest the Dart-safe name `in_`',
        );
        expect(
          result.stdout + result.stderr,
          contains('json=in'),
          reason: 'error must suggest the `:json=in` remap',
        );
      },
    );

    test(
      '`add-field` also enforces the keyword guard + accepts `:json=`',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // First, create a plain entity to add fields to.
        final create = await runZfa([
          'entity',
          'create',
          '-n',
          'ConfigArgDefinition',
          '--field',
          'name:String',
        ]);
        expect(create.exitCode, equals(0), reason: 'stderr: ${create.stderr}');

        // Adding a raw-keyword field must be refused with the same error.
        final badAdd = await runZfa([
          'entity',
          'add-field',
          '-n',
          'ConfigArgDefinition',
          '--field',
          'required:bool',
        ]);
        expect(
          badAdd.exitCode,
          isNot(equals(0)),
          reason: 'add-field must reject raw Dart keyword `required`',
        );
        expect(
          badAdd.stdout + badAdd.stderr,
          contains('json=required'),
          reason: 'error must suggest the `:json=required` remap',
        );

        // Adding with the explicit `:json=` remap succeeds and emits the
        // @JsonKey annotation.
        final goodAdd = await runZfa([
          'entity',
          'add-field',
          '-n',
          'ConfigArgDefinition',
          '--field',
          'required_:bool:json=required',
        ]);
        expect(
          goodAdd.exitCode,
          equals(0),
          reason:
              'add-field with :json= must succeed. stderr: ${goodAdd.stderr}',
        );

        final file = entityFile('config_arg_definition');
        final src = await file.readAsString();
        expect(
          src,
          contains("@JsonKey(name: 'required')"),
          reason:
              '@JsonKey(name: \'required\') must annotate the required_ getter',
        );
        expect(
          src,
          contains('bool get required_;'),
          reason: 'Dart-safe getter name `required_` must be emitted',
        );
        expect(
          src,
          isNot(RegExp(r'get\s+required\s*;')),
          reason: 'raw `get required;` must not appear',
        );

        await expectFormats(file);
      },
    );

    test(
      '`and:...:json=_and` + `or:...:json=_or` emit the Vendure wire keys',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Vendure `*FilterParameter` types compose nested filters with
        // `_and` / `_or` (leading-underscore wire keys). Self-references
        // need `--allow-forward-refs` (the entity's own dir does not exist
        // yet at create time).
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'ProductFilterParameter',
          '--allow-forward-refs',
          '--field',
          'and:ProductFilterParameter:json=_and',
          '--field',
          'or:ProductFilterParameter:json=_or',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason:
              'entity create with _and/_or wire names must succeed. '
              'stderr: ${result.stderr}',
        );

        final file = entityFile('product_filter_parameter');
        expect(file.existsSync(), isTrue);
        final src = await file.readAsString();

        // Both wire keys are emitted via @JsonKey, getters are the
        // Dart-safe `and` / `or` names.
        expect(src, contains("@JsonKey(name: '_and')"));
        expect(src, contains("@JsonKey(name: '_or')"));
        expect(src, contains('ProductFilterParameter get and;'));
        expect(src, contains('ProductFilterParameter get or;'));

        // Negative: no private `_and`/`_or` Dart identifiers (a leading `_`
        // would mark the getter private and break the API).
        expect(
          src,
          isNot(RegExp(r'get\s+_and\s*;')),
          reason: 'private `_and` getter must not be emitted',
        );
        expect(
          src,
          isNot(RegExp(r'get\s+_or\s*;')),
          reason: 'private `_or` getter must not be emitted',
        );

        await expectFormats(file);

        // Success message shows both wire names.
        expect(
          result.stdout,
          contains("and: ProductFilterParameter (json: '_and')"),
        );
        expect(
          result.stdout,
          contains("or: ProductFilterParameter (json: '_or')"),
        );
      },
    );

    test(
      '`entity from-json` auto-resolves Dart-keyword + `_`-prefixed JSON keys',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // A JSON payload mirroring the Vendure shape: `in` (Dart keyword),
        // `_and` / `_or` (leading-underscore wire keys), and a plain key.
        final jsonPath = p.join(workspace.path, 'payload.json');
        await File(jsonPath).writeAsString('''
{
  "in": ["abc"],
  "eq": "abc",
  "_and": [],
  "_or": []
}
''');

        final result = await runZfa([
          'entity',
          'from-json',
          'payload.json',
          '-n',
          'IdOperatorsFromJson',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason:
              'from-json must accept Dart-keyword and _-prefixed keys. '
              'stderr: ${result.stderr}',
        );

        final file = entityFile('id_operators_from_json');
        expect(file.existsSync(), isTrue);
        final src = await file.readAsString();

        // `in` (Dart keyword) -> Dart name `in_`, jsonName `in`.
        expect(src, contains("@JsonKey(name: 'in')"));
        expect(src, contains('get in_;'));

        // `_and` / `_or` -> Dart names `and` / `or`, jsonName `_and`/`_or`.
        expect(src, contains("@JsonKey(name: '_and')"));
        expect(src, contains("@JsonKey(name: '_or')"));
        expect(src, contains('get and;'));
        expect(src, contains('get or;'));

        // Plain `eq` key: no @JsonKey needed.
        expect(src, contains('get eq;'));
        expect(src, isNot(contains("@JsonKey(name: 'eq')")));

        // No raw keyword / private identifiers.
        expect(
          src,
          isNot(RegExp(r'get\s+in\s*;')),
          reason: 'raw `get in;` must not appear (from-json path)',
        );
        expect(
          src,
          isNot(RegExp(r'get\s+_and\s*;')),
          reason: 'private `_and` getter must not appear (from-json path)',
        );

        await expectFormats(file);
      },
    );

    test(
      'end-to-end: build_runner emits `.g.dart` with the correct wire keys',
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        // Skip when the local zorphy checkout (used by zuraffa's
        // dependency_overrides) is not available — e.g. CI without a
        // sibling zorphy repo. The zorphy `development` git ref in
        // pubspec.yaml still carries the fix in that case.
        final skipReason = _checkLocalZorphy(zorphyPath, zorphyAnnotationPath);
        if (skipReason != null) {
          print(skipReason);
          return;
        }

        // Workspace pubspec — path deps on local zorphy (mirrors zuraffa's
        // dependency_overrides) + build_runner + json_serializable.
        await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_303_e2e_app
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

        // Create the entity with the json= remap.
        final create = await runZfa([
          'entity',
          'create',
          '-n',
          'IdOperatorsE2E',
          '--field',
          'in_:String:json=in',
          '--field',
          'eq:String',
        ]);
        expect(
          create.exitCode,
          equals(0),
          reason: 'entity create failed: ${create.stdout}${create.stderr}',
        );

        // Resolve deps + run build_runner to generate the `.g.dart`.
        final pubGet = await runDart(['pub', 'get']);
        expect(
          pubGet.exitCode,
          equals(0),
          reason: 'dart pub get failed: ${pubGet.stdout}${pubGet.stderr}',
        );

        final build = await runDart(['run', 'build_runner', 'build']);
        expect(
          build.exitCode,
          equals(0),
          reason: 'build_runner failed: ${build.stdout}${build.stderr}',
        );

        // The generated `.g.dart` must serialize using the WIRE key `in`,
        // not the Dart name `in_`. This is the actual user-visible
        // contract: a Vendure server expects `"in": [...]`, not `"in_": [...]`.
        final gFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'id_operators_e2_e',
            'id_operators_e2_e.g.dart',
          ),
        );
        expect(
          gFile.existsSync(),
          isTrue,
          reason: '.g.dart was not generated by build_runner',
        );
        final generated = gFile.readAsStringSync();

        // Wire key `in` must be present (the contract).
        expect(
          generated,
          contains("'in':"),
          reason:
              "generated .g.dart must use the 'in' wire key "
              '(the whole point of #303)',
        );

        // The Dart name `in_` is the instance member access on the RHS
        // of the toJson entry — the wire key is `in`, the accessor is
        // `instance.in_`.
        expect(
          generated,
          contains("'in': instance.in_"),
          reason:
              "generated .g.dart toJson must map wire key 'in' to "
              '`instance.in_` (Dart name) — that is the #303 contract',
        );

        // Negative: the broken pre-fix form must NOT appear in the toJson
        // output. The bug was that json_serializable used the Dart name
        // `in_` as the wire key, producing `'in_': instance.in_`. After
        // the fix, only `'in': instance.in_` appears in the toJson map.
        // (Note: `'in_'` DOES legitimately appear in `fieldKeyMap` and as
        // a constructor parameter name — those are NOT the bug. The bug
        // signature is `'in_': instance.in_` in the toJson map literal.)
        expect(
          generated,
          isNot(contains("'in_': instance.in_")),
          reason:
              "generated .g.dart toJson must NOT use 'in_' as the wire "
              'key (that is the #303 bug — wire contract broken). The fix '
              "uses 'in' as the wire key with instance.in_ as the accessor.",
        );

        // `eq` (no remap) keeps using the Dart name as the wire key.
        expect(generated, contains("'eq':"));

        // `dart analyze` on the generated library must be clean.
        final analyze = await runDart(['analyze', 'lib']);
        expect(
          analyze.exitCode,
          equals(0),
          reason:
              'dart analyze reported issues:\n'
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
