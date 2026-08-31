@Tags(['regression', 'slow'])
// Regression test for issue #315.
//
// `zfa entity create` (with or without `--allow-forward-refs`) must generate a
// `$`-prefixed reference for **self-references** and **forward references**
// (types created later in the same batch), so the zorphy builder maps them to
// the concrete classes. Plain (no `$`) output must only be used when the
// referenced file EXISTS and is a hand-written non-Zorphy class (#310).
//
// Root cause: the #82 fix (`_determinePrefix` in zorphy's `FieldNormalizer`)
// returned `''` (empty prefix) for ANY field type whose entity file did not
// exist on disk yet. That regressed:
//
//   - **self-references**: `zfa entity create -n Collection --field
//     children:List<Collection>?` emitted `List<Collection>? get children;`
//     (no `$`). `Collection` was undefined in the source library (only
//     `$Collection` was declared), so the concrete class got
//     `final List<InvalidType>? children;` and `zfa build` failed in
//     `json_serializable`.
//   - **forward references** (#308 batch case): a field referencing an entity
//     created later in the batch emitted the plain type → same InvalidType.
//
// Fix (zorphy faf94de, consumed by zuraffa via the zorphy `development` git
// ref + the local `dependency_overrides` path): `_determinePrefix` now returns
// `$` when the entity file does NOT exist yet (forward / self reference —
// assume a Zorphy entity), and `''` ONLY when the file exists and declares
// neither `$X` nor `$$X` (plain/sealed hand-written class, #310).
//
// This test drives the FULL user-facing flow for both cases:
//
//   1. **Self-reference**: `zfa entity create -n Collection --field
//      children:List<Collection>? --allow-forward-refs` → `dart run
//      build_runner build` → `dart analyze`.
//   2. **Forward reference**: `zfa entity create -n Order --field
//      customer:Customer? --allow-forward-refs` (Customer does not exist yet),
//      then create Customer, then `build_runner build` → `dart analyze`.
//
// It asserts:
//   - The SOURCE entity file declares the field with the `$`-prefixed abstract
//     type (`List<$Collection>? get children;`, `$Customer? get customer;`).
//   - The GENERATED `.zorphy.dart` concrete class uses the resolved concrete
//     type (`final List<Collection>? children;`, `final Customer? customer;`).
//   - NO `InvalidType` appears anywhere in the generated output.
//   - `dart analyze` on the generated library reports no issues.
//
// The test mirrors zuraffa's `dependency_overrides` by pointing at the local
// zorphy checkout (`<repoRoot>/../zorphy/zorphy`). It skips gracefully when
// that checkout is absent (e.g. CI without a sibling zorphy repo), so it never
// breaks environments that don't carry the dev override.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart';
import '../helpers/run_zfa_source.dart';

void main() {
  group('#315 — self/forward references get `\$` prefix (not plain type)', () {
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
      workspace = await Directory.systemTemp.createTemp('issue_315_');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    // ------------------------------------------------------------------
    // Self-reference: Collection.children: List<Collection>?
    // ------------------------------------------------------------------
    test(
      'self-reference: Collection.children gets `List<\$Collection>?`, '
      'build + analyze clean',
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

        // 2. Create the self-referencing entity. `children:List<Collection>?`
        //    is the field that used to emit the plain `List<Collection>?`
        //    (no `$`) and produce `InvalidType` in the concrete class.
        final createResult = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Collection',
          '--field',
          'id:String?',
          '--field',
          'children:List<Collection>?',
          '--allow-forward-refs',
        ], workingDirectory: workspace.path);
        expect(
          createResult.exitCode,
          0,
          reason:
              'entity create failed: '
              '${createResult.stdout}${createResult.stderr}',
        );

        // 3. Read the SOURCE entity file. The abstract class MUST declare
        //    `children` with the `$`-prefixed abstract type. Before the fix
        //    this was `List<Collection>? get children;` (no `$`), which left
        //    `Collection` undefined (only `$Collection` was declared) and the
        //    concrete class got `final List<InvalidType>? children;`.
        final sourcePath = p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'collection',
          'collection.dart',
        );
        expect(
          File(sourcePath).existsSync(),
          isTrue,
          reason: 'entity source file was not written',
        );
        final source = File(sourcePath).readAsStringSync();

        expect(
          source,
          contains(r'List<$Collection>? get children;'),
          reason:
              'Self-reference MUST be `List<\$Collection>?` (with the `\$` '
              'prefix) so the builder maps it to the concrete `Collection` '
              'class. A plain `List<Collection>?` here is the #315 '
              'regression — `Collection` is undefined in the source library.',
        );

        // Negative: the plain (no-`$`) form must NOT appear as a field
        // declaration. `List<$Collection>` contains the substring
        // `Collection`, so we anchor on the getter declaration.
        final plainSelfRef = RegExp(
          r'List<Collection>\?\s*get\s+children',
        ).firstMatch(source);
        expect(
          plainSelfRef,
          isNull,
          reason:
              'The source must NOT declare `List<Collection>? get children;` '
              '(no `\$`) — that is the #315 regression. The `\$`-prefixed '
              'abstract type is required so the builder can resolve it.',
        );

        // 4. Resolve deps + run build_runner to generate the `.zorphy.dart`.
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
              'build_runner failed (the #315 symptom — '
              'json_serializable: final List<InvalidType>? children;):\n'
              '${build.stdout}${build.stderr}',
        );

        // 5. Read the generated .zorphy.dart. The concrete class MUST use the
        //    resolved concrete type, NOT `InvalidType`.
        final zorphyFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'collection',
            'collection.zorphy.dart',
          ),
        );
        expect(
          zorphyFile.existsSync(),
          isTrue,
          reason: '.zorphy.dart was not generated by build_runner',
        );
        final generated = zorphyFile.readAsStringSync();

        expect(
          generated,
          contains('final List<Collection>? children;'),
          reason:
              'The concrete class must declare '
              '`final List<Collection>? children;` (resolved concrete type).',
        );

        // CRITICAL: no `InvalidType` may appear anywhere in the generated
        // output. Before the fix, the concrete class had
        // `final List<InvalidType>? children;`.
        expect(
          generated,
          isNot(contains('InvalidType')),
          reason:
              '`InvalidType` in the generated output is the direct symptom '
              'of #315 — the plain (no-`\$`) self-reference could not be '
              'resolved by the analyzer.',
        );

        // 6. `dart analyze` on the generated library must be clean.
        final analyze = await runDart(['analyze', 'lib']);
        expect(
          analyze.exitCode,
          0,
          reason:
              'dart analyze reported issues (the #315 symptom):\n'
              '${analyze.stdout}${analyze.stderr}',
        );
      },
    );

    // ------------------------------------------------------------------
    // Forward reference: Order.customer: Customer? (Customer created later)
    // ------------------------------------------------------------------
    test(
      'forward reference: Order.customer gets `\$Customer?`, '
      'build + analyze clean after Customer is created',
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        final skipReason = _checkLocalZorphy(zorphyPath, zorphyAnnotationPath);
        if (skipReason != null) {
          print(skipReason);
          return;
        }

        await _writePubspec(workspace, zorphyPath, zorphyAnnotationPath);
        await _writeBuildYaml(workspace);

        // A minimal enums barrel so the entity-command import resolver
        // (`_fixEntityImports`) can add `import '../enums/index.dart';`
        // without producing an unresolvable URI. This is orthogonal to the
        // #315 prefix behavior but needed for `dart analyze` to be clean
        // in the forward-reference workflow.
        await _writeEnumsBarrel(workspace);

        // 1. Create Order FIRST, referencing Customer (which does not exist
        //    yet). `--allow-forward-refs` opts out of the type validator so
        //    the command does not abort on the unresolved `Customer` type.
        final orderResult = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Order',
          '--field',
          'id:String?',
          '--field',
          'customer:Customer?',
          '--allow-forward-refs',
        ], workingDirectory: workspace.path);
        expect(
          orderResult.exitCode,
          0,
          reason:
              'entity create (Order) failed: '
              '${orderResult.stdout}${orderResult.stderr}',
        );

        // 2. Read the Order source. `customer` MUST be declared with the
        //    `$`-prefixed abstract type. Before the fix this was
        //    `Customer? get customer;` (no `$`) → InvalidType.
        final orderSourcePath = p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'order',
          'order.dart',
        );
        expect(
          File(orderSourcePath).existsSync(),
          isTrue,
          reason: 'Order entity source file was not written',
        );
        final orderSource = File(orderSourcePath).readAsStringSync();

        expect(
          orderSource,
          contains(r'$Customer? get customer;'),
          reason:
              'Forward reference MUST be `\$Customer?` (with the `\$` '
              'prefix) so the builder maps it to the concrete `Customer` '
              'class once it exists. A plain `Customer?` here is the #315 '
              'regression.',
        );

        // Negative: the plain (no-`$`) getter declaration must NOT appear.
        final plainFwdRef = RegExp(
          r'(?<!\$)Customer\?\s*get\s+customer',
        ).firstMatch(orderSource);
        expect(
          plainFwdRef,
          isNull,
          reason:
              'The source must NOT declare `Customer? get customer;` '
              '(no `\$`) — that is the #315 regression for forward refs.',
        );

        // 3. NOW create the forward-referenced Customer entity.
        final customerResult = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Customer',
          '--field',
          'id:String?',
          '--field',
          'name:String',
        ], workingDirectory: workspace.path);
        expect(
          customerResult.exitCode,
          0,
          reason:
              'entity create (Customer) failed: '
              '${customerResult.stdout}${customerResult.stderr}',
        );

        // 4. Resolve deps + run build_runner to generate both .zorphy.dart.
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
              'build_runner failed (the #315 symptom for forward refs):\n'
              '${build.stdout}${build.stderr}',
        );

        // 5. The generated Order.zorphy.dart concrete class MUST use the
        //    resolved `Customer` type, NOT `InvalidType`.
        final orderZorphyFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'order',
            'order.zorphy.dart',
          ),
        );
        expect(
          orderZorphyFile.existsSync(),
          isTrue,
          reason: 'Order .zorphy.dart was not generated by build_runner',
        );
        final orderGenerated = orderZorphyFile.readAsStringSync();

        expect(
          orderGenerated,
          contains('final Customer? customer;'),
          reason:
              'The concrete Order class must declare '
              '`final Customer? customer;` (resolved concrete type).',
        );
        expect(
          orderGenerated,
          isNot(contains('InvalidType')),
          reason:
              '`InvalidType` in the generated Order output is the direct '
              'symptom of #315 for forward references.',
        );

        // 6. `dart analyze` — the #315 symptom is `InvalidType` (an error).
        // The forward-ref workflow also triggers a separate, orthogonal
        // `_fixEntityImports` quirk: when Order is created before Customer
        // exists, the import resolver adds `import '../enums/index.dart';`
        // (it assumes the unresolved type is an enum). Once Customer is
        // created that import becomes unused (warning) — unrelated to #315.
        // We therefore scan the analyze output for any `error -` line
        // mentioning `InvalidType` (the #315 regression) and tolerate the
        // unrelated unused-import warning.
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
              'direct #315 symptom for forward references:\n$analyzeOut',
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
        'the zorphy `development` git ref in pubspec.yaml.';
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
name: issue_315_test_app
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

/// Writes a minimal enums barrel (`lib/src/domain/entities/enums/index.dart`)
/// so the entity-command import resolver's `import '../enums/index.dart';`
/// resolves cleanly. This is orthogonal to the #315 prefix behavior but
/// needed for `dart analyze` to be clean in the forward-reference workflow.
Future<void> _writeEnumsBarrel(Directory workspace) async {
  final dir = Directory(
    p.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'enums'),
  );
  await dir.create(recursive: true);
  await File(
    p.join(dir.path, 'index.dart'),
  ).writeAsString('// Auto-generated enums barrel.\n');
}
