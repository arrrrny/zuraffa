// Bug 1198 (part of #908 P0) — template self-hosting harness.
//
// Shared fixture + driver for the per-template TDD-loop suites under
// `test/templates/self_hosting/`. Every generator template (usecase,
// service, repository, datasource, mock, di, view/skin, state, route) is
// driven against the SAME fixture entity (Product) through the same
// trust-tier bar as #1117 / spec 1003:
//
//   structural  — file set + key content of the emitted artifacts
//   compile     — emitted code analyzes clean inside a self-contained
//                 package (pure-Dart fixture; Flutter templates via the
//                 downstream gate)
//   behavioral  — the emitted code EXECUTES (fixture `tool/behavior_check.dart`
//                 run with the real SDK) wherever the template is pure Dart
//   diff guard  — regenerating with the same inputs is byte-stable; a
//                 determinism receipt (`template.determinism.v1`) is written
//                 into the fixture's `.zfa/` home
//
// The downstream-compile gate (minimal FLUTTER package, #1189/#1190-class
// import/dep drift) lives in `downstream_compile_gate_test.dart` and drives
// ALL templates through one Flutter fixture.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';

import 'project_root.dart' show findProjectRoot;

export 'package:zuraffa/src/core/generator_options.dart';
export 'package:zuraffa/src/models/generator_config.dart';
export 'project_root.dart' show findProjectRoot;

/// The fixture entity every template is driven against. It deliberately
/// carries a `DateTime` field: that is the field class whose generated
/// value used to leak wall-clock time into unseeded output (the exact
/// byte-stability debt the #1198 diff guard exists to catch).
const String kFixtureEntityName = 'Product';

/// The fixture entity's field map (`name: Type`), mirroring the Key
/// Entities table grammar the spec template declares.
const Map<String, String> kFixtureEntityFields = {
  'id': 'String',
  'name': 'String',
  'price': 'double',
  'createdAt': 'DateTime',
};

/// The entity stub written into every fixture project. Shape-mirrors the
/// zorphy-generated entity surface the generators reference (hand-written
/// because build_runner/zorphy is out of scope for a template fixture):
/// the entity itself plus the `ProductFields` descriptor class generated
/// presenters reference (`Eq(ProductFields.id, ...)`).
const String fixtureEntitySource = '''
import 'package:zuraffa/zuraffa.dart';

class Product {
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double price;
  final DateTime createdAt;

  Product copyWith({String? id, String? name, double? price, DateTime? createdAt}) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ProductFields {
  const ProductFields._();

  static const Field<Product, String> id = Field<Product, String>('id');
  static const Field<Product, String> name = Field<Product, String>('name');
  static const Field<Product, double> price = Field<Product, double>('price');
}
''';

/// Repository interface stub for the fixture entity (the shape the
/// repository/usecase templates import and call).
const String fixtureRepositorySource = '''
import 'package:zuraffa/zuraffa.dart';

import '../entities/product/product.dart';

abstract class ProductRepository {
  Future<Product> get(QueryParams<Product> params);
  Future<Product> create(Product product);
  Future<List<Product>> getList(ListQueryParams<Product> params);
  Future<Product> update(UpdateParams<String, Product> params);
  Future<void> delete(DeleteParams<String> params);
}
''';

/// Writes the fixture entity (and optional repository stub) into [root]'s
/// `lib/src/domain/` tree. Returns the entity file path.
Future<String> writeFixtureEntity(
  Directory root, {
  bool withRepository = false,
  String libDir = 'lib/src',
}) async {
  final entityPath = p.join(
    root.path,
    libDir,
    'domain',
    'entities',
    'product',
    'product.dart',
  );
  final entityFile = File(entityPath);
  await entityFile.create(recursive: true);
  await entityFile.writeAsString(fixtureEntitySource);
  if (withRepository) {
    final repoPath = p.join(
      root.path,
      libDir,
      'domain',
      'repositories',
      'product_repository.dart',
    );
    final repoFile = File(repoPath);
    await repoFile.create(recursive: true);
    await repoFile.writeAsString(fixtureRepositorySource);
  }
  return entityPath;
}

/// Pubspec for a pure-Dart fixture package that depends on THIS checkout
/// (path dep) — so the gate exercises the working tree, not the last
/// published package.
String pureDartPubspec(String repoRoot, String name) =>
    '''
name: $name
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''';

/// Creates a unique temp dir (no pub resolution — cheap, for
/// structural/diff-guard suites that never run the SDK).
Future<Directory> createTempFixture(String tag) =>
    Directory.systemTemp.createTemp('zfa1198_${tag}_');

/// Creates a pure-Dart fixture package (pubspec with a path dependency on
/// this repo) and runs `dart pub get`. Returns the project root.
Future<Directory> createPureDartFixture(
  String tag,
  String repoRoot, {
  bool withRepository = false,
}) async {
  final root = await Directory.systemTemp.createTemp('zfa1198_${tag}_');
  await File(
    p.join(root.path, 'pubspec.yaml'),
  ).writeAsString(pureDartPubspec(repoRoot, 'zfa1198_${tag}_fixture'));
  await writeFixtureEntity(root, withRepository: withRepository);
  final pub = await Process.run(dartExePath, [
    'pub',
    'get',
    '--no-example',
  ], workingDirectory: root.path);
  expect(
    pub.exitCode,
    0,
    reason:
        'dart pub get must succeed in the $tag fixture.\n'
        '${pub.stdout}\n${pub.stderr}',
  );
  return root;
}

/// The Dart SDK executable driving the test process (FLUTTER_ROOT/bin/dart
/// first under `flutter test`, else PATH — same strategy as
/// flutter_cluster_fixture.dart).
String get dartExePath {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final candidate = File('$flutterRoot/bin/dart');
    if (candidate.existsSync()) return candidate.path;
  }
  return 'dart';
}

/// `dart analyze <target>` inside [root]. Targets default to the whole
/// `lib/` tree of the fixture.
Future<ProcessResult> analyzeFixture(Directory root, {List<String>? targets}) {
  return Process.run(dartExePath, [
    'analyze',
    ...(targets ?? ['lib']),
    '--no-fatal-warnings',
  ], workingDirectory: root.path);
}

/// Expects [result] (from [analyzeFixture]) to be analyzer-clean: exit 0
/// and no ` error - ` lines.
void expectAnalyzerClean(ProcessResult result, {String? context}) {
  final output = '${result.stdout}\n${result.stderr}';
  expect(
    result.exitCode,
    0,
    reason: 'generated ${context ?? 'output'} must analyze clean:\n$output',
  );
  expect(
    output,
    isNot(contains(' error - ')),
    reason:
        'no analyzer errors allowed in generated '
        '${context ?? 'output'}:\n$output',
  );
}

/// Runs `dart run <script>` inside [root] and expects exit 0.
Future<ProcessResult> runBehaviorScript(Directory root, String scriptPath) {
  return Process.run(dartExePath, [
    'run',
    p.relative(scriptPath, from: root.path),
  ], workingDirectory: root.path);
}

// ---------------------------------------------------------------------------
// Diff guard (determinism receipt)
// ---------------------------------------------------------------------------

/// One generation run's fingerprint: relative path → SHA-256 of content.
typedef GenerationFingerprint = Map<String, String>;

/// Fingerprints every generated file of a run. [generated] is the plugin's
/// own declared output (path + content) — the emitted artifacts, NOT
/// side-channel receipts (those legitimately carry wall-clock provenance
/// and are out of the byte-stability contract's scope).
GenerationFingerprint fingerprint(
  List<({String path, String? content})> generated,
) {
  final map = <String, String>{};
  for (final file in generated) {
    final content = file.content;
    if (content == null) continue;
    map[file.path] = sha256.convert(utf8.encode(content)).toString();
  }
  return map;
}

/// Compares two fingerprints. Returns the human-readable drift report
/// (empty when byte-stable).
String driftReport(GenerationFingerprint a, GenerationFingerprint b) {
  final drift = <String>[];
  final pathsA = a.keys.toSet();
  final pathsB = b.keys.toSet();
  for (final path in pathsA.difference(pathsB)) {
    drift.add('only in run A: $path');
  }
  for (final path in pathsB.difference(pathsA)) {
    drift.add('only in run B: $path');
  }
  for (final path in pathsA.intersection(pathsB)) {
    if (a[path] != b[path]) drift.add('content differs: $path');
  }
  return drift.join('\n');
}

/// Writes the determinism receipt (`template.determinism.v1`) into [root]'s
/// `.zfa/` home — the machine-readable artifact `zfa tdd status`-class
/// tooling (and the publish gate) can read without parsing test output.
///
/// The receipt carries NO wall-clock fields: it is itself byte-stable for
/// the same comparison result, so receipts can be diffed across runs/CI.
void writeDeterminismReceipt(
  Directory root, {
  required String template,
  required bool stable,
  required GenerationFingerprint runA,
  required GenerationFingerprint runB,
}) {
  final drift = driftReport(runA, runB);
  final receipt =
      '''
{
  "schema": "template.determinism.v1",
  "refs": [
    "https://github.com/arrrrny/zuraffa/issues/1198",
    "https://github.com/arrrrny/zuraffa/issues/908"
  ],
  "template": "$template",
  "stable": $stable,
  "fileCount": ${runA.length},
  "runA": ${_jsonMap(runA)},
  "runB": ${_jsonMap(runB)},
  "drift": ${stable ? '[]' : _jsonList(drift.split('\n')..removeWhere((e) => e.isEmpty))}
}
''';
  final file = File(
    p.join(root.path, '.zfa', 'template.determinism.$template.json'),
  );
  file.createSync(recursive: true);
  file.writeAsStringSync(receipt);
}

String _jsonMap(Map<String, String> map) {
  final entries = (map.keys.toList()..sort())
      .map((k) => '    "$k": "${map[k]}"')
      .join(',\n');
  return entries.isEmpty ? '{}' : '{\n$entries\n  }';
}

String _jsonList(List<String> items) =>
    items.isEmpty ? '[]' : items.map((e) => '  "$e"').join(',\n');

/// Standard group wrapper for a template's diff-guard test: generates
/// twice with identical inputs (fresh temp dirs each), asserts byte
/// stability, writes the receipt into run A's fixture.
Future<void> expectByteStable({
  required String template,
  required Future<List<({String path, String? content})>> Function(
    Directory root,
  )
  generate,

  /// Overrides the default marker pubspec (flavor gates — e.g. the view
  /// plugin's #420 Flutter-target gate — read this file).
  String Function(String name)? pubspec,

  /// Also write the repository stub (templates whose output imports it —
  /// view/skin, route).
  bool withRepository = false,
}) async {
  final repoRoot = await findProjectRoot();
  final dirA = await createTempFixture('${template}_dg_a');
  final dirB = await createTempFixture('${template}_dg_b');
  try {
    // Identical inputs: same pubspec name (templates embed the package
    // name — e.g. `package:<name>/...` imports in the generated route-table
    // test), same fixture entity, same config. Only the throwaway location
    // differs.
    await File(p.join(dirA.path, 'pubspec.yaml')).writeAsString(
      pubspec?.call('diff_guard') ??
          'name: diff_guard\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await File(p.join(dirB.path, 'pubspec.yaml')).writeAsString(
      pubspec?.call('diff_guard') ??
          'name: diff_guard\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await writeFixtureEntity(dirA, withRepository: withRepository);
    await writeFixtureEntity(dirB, withRepository: withRepository);

    // GeneratedFile.path may be absolute; normalize to root-relative so
    // two runs in different throwaway dirs are comparable.
    List<({String path, String? content})> normalize(
      List<({String path, String? content})> files,
      Directory root,
    ) => files
        .map(
          (f) => (
            path: p.normalize(
              p.isAbsolute(f.path)
                  ? p.relative(f.path, from: root.path)
                  : f.path,
            ),
            content: f.content,
          ),
        )
        .toList();

    final fpA = fingerprint(normalize(await generate(dirA), dirA));
    final fpB = fingerprint(normalize(await generate(dirB), dirB));
    final stable = fpA.isNotEmpty && _mapsEqual(fpA, fpB);

    writeDeterminismReceipt(
      dirA,
      template: template,
      stable: stable,
      runA: fpA,
      runB: fpB,
    );

    expect(
      fpA,
      isNotEmpty,
      reason: '$template template must emit at least one artifact',
    );
    expect(
      driftReport(fpA, fpB),
      isEmpty,
      reason:
          '$template template output must be byte-stable for identical '
          'inputs (diff guard, #1198). Determinism receipt written to '
          '${p.join(dirA.path, '.zfa')}.',
    );
  } finally {
    if (dirA.existsSync()) dirA.delete(recursive: true);
    if (dirB.existsSync()) dirB.delete(recursive: true);
    // repoRoot resolved eagerly to fail fast when the helper's context
    // is broken.
    expect(repoRoot, isNotEmpty);
  }
}

bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (b[key] != a[key]) return false;
  }
  return true;
}

/// Returns the content of the generated file whose path ends with
/// [suffix]. Some generators emit files by writing to disk and return a
/// null in-memory [GeneratedFile.content]; this falls back to reading the
/// file from [root].
String generatedContent(
  List<({String path, String? content})> files,
  Directory root,
  String suffix,
) {
  final file = files.firstWhere((f) => f.path.endsWith(suffix));
  final content = file.content;
  if (content != null) return content;
  return File(
    p.isAbsolute(file.path) ? file.path : p.join(root.path, file.path),
  ).readAsStringSync();
}

// ---------------------------------------------------------------------------
// Config builders (identical inputs across suites)
// ---------------------------------------------------------------------------

/// Base options every suite uses — force on, dry-run off, quiet.
const GeneratorOptions kSelfHostOptions = GeneratorOptions(
  dryRun: false,
  force: true,
  verbose: false,
);

/// Convenience: writes the marker pubspec view/skin templates need (the
/// view plugin's flavor gate #420 skips pure-Dart targets).
Future<void> writeFlutterMarkerPubspec(Directory root, String name) async {
  await File(p.join(root.path, 'pubspec.yaml')).writeAsString('''
name: $name
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''');
}
