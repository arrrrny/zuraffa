@Tags(['regression', 'slow'])
// Regression test for issue #310.
//
// `zfa entity create` must emit the PLAIN type (no `$` prefix) when a field
// references a hand-written (non-Zorphy) class — e.g. a sealed union
// dispatcher like Vendure's `SearchResultPrice` (a plain `sealed class`
// with a runtimeType-dispatch `fromJson`, kept as SDK glue).
//
// Root cause: zorphy's `FieldNormalizer._determinePrefix` returned `$` for
// ANY field type whose entity directory existed, without checking whether
// the target file actually declared a Zorphy abstract (`abstract class $X`).
// For a plain/sealed hand-written class this emitted
// `$SearchResultPrice get price;` in the source. The analyzer could not
// resolve the undefined `$SearchResultPrice`, so the generated concrete
// class got `final InvalidType price;` and `zfa build` failed in
// `json_serializable`.
//
// Fix (consumed by zuraffa via the zorphy git ref
// `fix/310-determine-prefix-comment-safe` + the local
// `dependency_overrides` path): `_determinePrefix` now strips `//` and
// `/* */` comments before running the `abstract class $X` regex, and
// returns `''` (plain type) when the file declares neither `$X` nor `$$X`.
//
// This test drives the FULL user-facing flow:
//
//   1. Write a hand-written sealed `SearchResultPrice` class file (with a
//      doc comment that mentions the literal text `abstract class
//      $SearchResultPrice` — the case that broke the pre-hardening regex).
//   2. `zfa entity create -n SearchResult --field price:SearchResultPrice?
//      --allow-forward-refs` → `dart run build_runner build` →
//      `dart analyze`.
//
// It asserts:
//   - The SOURCE entity file declares the field with the PLAIN type
//     (`SearchResultPrice? get price;`, NOT `$SearchResultPrice?`).
//   - The GENERATED `.zorphy.dart` concrete class uses the resolved
//     concrete type (`final SearchResultPrice? price;`).
//   - NO `InvalidType` appears anywhere in the generated output.
//   - `dart analyze` on the generated library reports no issues.
//
// The test mirrors zuraffa's `dependency_overrides` by pointing at the
// local zorphy checkout (`<repoRoot>/../zorphy/zorphy`). It skips
// gracefully when that checkout is absent (e.g. CI without a sibling
// zorphy repo), so it never breaks environments that don't carry the dev
// override.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart';

void main() {
  group('#310 — hand-written class reference gets plain type', () {
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
      workspace = await Directory.systemTemp.createTemp('issue_310_');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      'hand-written sealed SearchResultPrice + comment -> plain type, '
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

        // 2. Write the HAND-WRITTEN sealed class file. This is the
        //    Vendure-style SearchResultPrice: a plain `sealed class` with
        //    a runtimeType-dispatch `fromJson`, NOT a Zorphy entity.
        //    The doc comment deliberately mentions the literal pattern
        //    `abstract class $SearchResultPrice` — the case that broke
        //    the pre-hardening regex (it falsely matched the comment and
        //    emitted the `$` prefix).
        final srpDir = Directory(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'search_result_price',
          ),
        );
        await srpDir.create(recursive: true);
        await File(
          p.join(srpDir.path, 'search_result_price.dart'),
        ).writeAsString(_searchResultPriceSource);

        // 3. Create the SearchResult entity referencing the hand-written
        //    class. `--allow-forward-refs` opts out of the type validator
        //    so the command does not abort on the (deliberately)
        //    non-Zorphy target.
        final createResult = await Process.run('dart', [
          zfaBin,
          'entity',
          'create',
          '-n',
          'SearchResult',
          '--field',
          'id:String?',
          '--field',
          'price:SearchResultPrice?',
          '--field',
          'priceWithTax:SearchResultPrice?',
          '--allow-forward-refs',
        ], workingDirectory: workspace.path);
        expect(
          createResult.exitCode,
          0,
          reason:
              'entity create failed: '
              '${createResult.stdout}${createResult.stderr}',
        );

        // 4. Read the SOURCE entity file. The abstract class MUST declare
        //    `price` and `priceWithTax` with the PLAIN type. Before the
        //    fix this was `$SearchResultPrice? get price;` — the analyzer
        //    could not resolve `$SearchResultPrice` (only `SearchResultPrice`
        //    was declared in the imported file), so the concrete class got
        //    `final InvalidType? price;`.
        final sourcePath = p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'search_result',
          'search_result.dart',
        );
        expect(
          File(sourcePath).existsSync(),
          isTrue,
          reason: 'entity source file was not written',
        );
        final source = File(sourcePath).readAsStringSync();

        // Positive: the plain type MUST be emitted.
        expect(
          source,
          contains('SearchResultPrice? get price;'),
          reason:
              'A hand-written (non-Zorphy) class reference MUST be emitted '
              'as the PLAIN type `SearchResultPrice?` (no `\$` prefix). A '
              '`\$SearchResultPrice?` here is the #310 bug — `\$SearchResultPrice` '
              'is undefined in the imported file (only `SearchResultPrice` is '
              'declared), so the concrete class gets `final InvalidType? price;`.',
        );
        expect(
          source,
          contains('SearchResultPrice? get priceWithTax;'),
          reason: 'Both fields must use the plain type.',
        );

        // Negative: the `$`-prefixed form MUST NOT appear as a getter
        // declaration. The source contains the import
        // `import '../search_result_price/search_result_price.dart';` and
        // the doc comment of `SearchResultPrice` mentions
        // `abstract class $SearchResultPrice`, so we anchor on the getter
        // declaration.
        final prefixedDecl = RegExp(
          r'\$SearchResultPrice\?\s*get\s+(price|priceWithTax)',
        ).firstMatch(source);
        expect(
          prefixedDecl,
          isNull,
          reason:
              'The source MUST NOT declare `\$SearchResultPrice? get price;` '
              '(or `priceWithTax`) — that is the #310 bug. The hand-written '
              'class file declares only `SearchResultPrice`, so the `\$`-prefixed '
              'identifier is undefined and the concrete class gets `InvalidType`.',
        );

        // 5. Resolve deps + run build_runner to generate the .zorphy.dart.
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
              'build_runner failed (the #310 symptom — '
              'json_serializable: final InvalidType? price;):\n'
              '${build.stdout}${build.stderr}',
        );

        // 6. Read the generated .zorphy.dart. The concrete class MUST use
        //    the resolved concrete type, NOT `InvalidType`.
        final zorphyFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'search_result',
            'search_result.zorphy.dart',
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
          contains('final SearchResultPrice? price;'),
          reason:
              'The concrete class must declare '
              '`final SearchResultPrice? price;` (resolved concrete type).',
        );
        expect(
          generated,
          contains('final SearchResultPrice? priceWithTax;'),
          reason: 'Both concrete fields must use the resolved type.',
        );

        // CRITICAL: no `InvalidType` may appear anywhere in the generated
        // output. Before the fix, the concrete class had
        // `final InvalidType? price;`.
        expect(
          generated,
          isNot(contains('InvalidType')),
          reason:
              '`InvalidType` in the generated output is the direct symptom '
              'of #310 — the `\$`-prefixed reference could not be resolved '
              'by the analyzer.',
        );

        // 7. `dart analyze` on the generated library must be clean.
        final analyze = await runDart(['analyze', 'lib']);
        expect(
          analyze.exitCode,
          0,
          reason:
              'dart analyze reported issues (the #310 symptom):\n'
              '${analyze.stdout}${analyze.stderr}',
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
        'the zorphy `fix/310-determine-prefix-comment-safe` git ref in '
        'pubspec.yaml.';
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
name: issue_310_test_app
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

/// The hand-written sealed `SearchResultPrice` class — a Vendure-style
/// union dispatcher. This is NOT a Zorphy entity (no `abstract class
/// $SearchResultPrice` declaration). The doc comment deliberately mentions
/// the literal pattern that would falsely match the pre-hardening regex.
const String _searchResultPriceSource = '''
// Hand-written (non-Zorphy) sealed union dispatcher, like Vendure's
// SearchResultPrice. This is a plain class — NO `abstract class \$SearchResultPrice`
// declaration here, by design (kept as SDK glue).
import 'package:json_annotation/json_annotation.dart';

part 'search_result_price.g.dart';

sealed class SearchResultPrice {
  const SearchResultPrice();
  factory SearchResultPrice.fromJson(Map<String, dynamic> json) {
    final t = json['runtimeType'] as String;
    return switch (t) {
      'SearchResultPriceValue' => SearchResultPriceValue.fromJson(json),
      'SearchResultPriceRange' => SearchResultPriceRange.fromJson(json),
      _ => throw ArgumentError.value(t, 'runtimeType', 'Unknown'),
    };
  }
  Map<String, dynamic> toJson();
}

@JsonSerializable()
class SearchResultPriceValue extends SearchResultPrice {
  final int value;
  const SearchResultPriceValue({required this.value});
  factory SearchResultPriceValue.fromJson(Map<String, dynamic> json) =>
      _\$SearchResultPriceValueFromJson(json);
  @override
  Map<String, dynamic> toJson() => _\$SearchResultPriceValueToJson(this);
}

@JsonSerializable()
class SearchResultPriceRange extends SearchResultPrice {
  final int min;
  final int max;
  const SearchResultPriceRange({required this.min, required this.max});
  factory SearchResultPriceRange.fromJson(Map<String, dynamic> json) =>
      _\$SearchResultPriceRangeFromJson(json);
  @override
  Map<String, dynamic> toJson() => _\$SearchResultPriceRangeToJson(this);
}
''';
