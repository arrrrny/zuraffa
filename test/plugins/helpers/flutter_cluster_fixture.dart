/// Spec 1003 — shared fixture for trust-tier Flutter-generator compile
/// tests (view / controller / presenter).
///
/// Builds a minimal self-contained Flutter project in a temp dir that can
/// resolve the imports emitted by the presentation-layer plugins:
///
/// - `package:flutter/material.dart` → Flutter SDK
/// - `package:zuraffa_flutter/zuraffa_flutter.dart` → hosted (pub.dev)
/// - relative entity / repository / usecase imports → hand-written stubs
///   that mirror the shape the entity/repository/usecase generators emit
///   (the entity pipeline itself needs build_runner + zorphy, which is out
///   of scope for a generator compile gate).
///
/// The generated cluster (view + controller + presenter) is produced by the
/// real plugins; `flutter analyze` on the project must exit 0 (compile gate,
/// spec 1003 acceptance).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves the `flutter` executable the same way
/// `test/state/widgets/sc_003_generated_view_compiles_test.dart` resolves
/// `dart`: never from `Platform.resolvedExecutable` (which is the engine's
/// `flutter_tester` under `flutter test`), but from `FLUTTER_ROOT` first and
/// `PATH` second.
Future<String> resolveFlutterExe() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final candidate = File('$flutterRoot/bin/flutter');
    if (candidate.existsSync()) return candidate.path;
  }
  final which = Platform.isWindows ? 'where' : 'which';
  final result = await Process.run(which, ['flutter']);
  if (result.exitCode == 0) {
    final first = result.stdout.toString().split(RegExp(r'\r?\n')).first.trim();
    if (first.isNotEmpty) return first;
  }
  return 'flutter';
}

/// Resolves the real Dart SDK `dart` executable (same strategy as
/// sc_003: `FLUTTER_ROOT/bin/dart` under `flutter test`, else `PATH`).
Future<String> resolveDartExe() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final candidate = File('$flutterRoot/bin/dart');
    if (candidate.existsSync()) return candidate.path;
  }
  final which = Platform.isWindows ? 'where' : 'which';
  final result = await Process.run(which, ['dart']);
  if (result.exitCode == 0) {
    final first = result.stdout.toString().split(RegExp(r'\r?\n')).first.trim();
    if (first.isNotEmpty) return first;
  }
  return 'dart';
}

/// The zuraffa checkout this fixture's generated code must compile against:
/// four levels up from `test/plugins/helpers/`.
String _findRepoRoot() {
  var dir = Directory.current.path;
  while (true) {
    if (File(p.join(dir, 'pubspec.yaml')).existsSync() &&
        File(p.join(dir, 'lib', 'zuraffa.dart')).existsSync()) {
      return dir;
    }
    final parent = p.dirname(dir);
    if (parent == dir) {
      throw StateError(
        'cannot locate the zuraffa checkout from ${Directory.current}',
      );
    }
    dir = parent;
  }
}

/// Writes the Flutter project skeleton (pubspec + domain stubs) into [root].
Future<Directory> writeFlutterClusterStubs(Directory root) async {
  await File(p.join(root.path, 'pubspec.yaml')).create(recursive: true);
  await File(p.join(root.path, 'pubspec.yaml')).writeAsString(
    flutterClusterPubspec(_findRepoRoot(), _writeZuraffaUiStub(root).path),
  );
  await File(
    p.join(root.path, 'domain', 'entities', 'product', 'product.dart'),
  ).create(recursive: true);
  await File(
    p.join(root.path, 'domain', 'entities', 'product', 'product.dart'),
  ).writeAsString(_entityStub);
  await File(
    p.join(root.path, 'domain', 'repositories', 'product_repository.dart'),
  ).create(recursive: true);
  await File(
    p.join(root.path, 'domain', 'repositories', 'product_repository.dart'),
  ).writeAsString(_repositoryStub);
  await File(
    p.join(
      root.path,
      'domain',
      'usecases',
      'product',
      'get_product_usecase.dart',
    ),
  ).create(recursive: true);
  await File(
    p.join(
      root.path,
      'domain',
      'usecases',
      'product',
      'get_product_usecase.dart',
    ),
  ).writeAsString(_useCaseStub);
  return root;
}

/// Creates a unique temp Flutter project with the spec-1003 stubs.
Future<Directory> createFlutterClusterFixture(String tag) async {
  final root = await Directory.systemTemp.createTemp('zfa1003_${tag}_');
  await writeFlutterClusterStubs(root);
  return root;
}

/// `flutter pub get --no-example` inside the temp project so the generated
/// cluster's `package:` imports resolve during `flutter analyze`.
Future<ProcessResult> flutterPubGet(Directory root, String flutterExe) async {
  return Process.run(flutterExe, [
    'pub',
    'get',
    '--no-example',
  ], workingDirectory: root.path);
}

/// The fixture consumes the CHECKOUT's own core the way a release candidate
/// is consumed: `zuraffa_flutter` supplies the Flutter-only presentation types
/// (`DualLayerPresenter`, `ControlledWidget`, …) the generated cluster imports,
/// and `dependency_overrides` pins its `zuraffa` dependency to this checkout so
/// the core symbols the generators emit (`QueryParams.fromTrusted`, the
/// `AppFailure` union root) resolve to THIS branch.
///
/// It used to pin the hosted `zuraffa_flutter: ^6.1.0` alone, so a generator
/// change that emitted a member the published core lacked compiled fine in-repo
/// and went red only in CI (#2179).
///
/// `zuraffa_ui` is overridden to an EMPTY local package: `zuraffa_flutter`
/// declares it, but none of the presentation files the generated cluster uses
/// import it — only its skin app does — and the published `zuraffa_ui` still
/// pins `zorphy_annotation ^2.5.1`, which cannot solve against a v3 core. The
/// stub is removed once zuraffa_ui/zuraffa_flutter publish on zorphy v3
/// (arrrrny/zuraffa#2183, depends on arrrrny/zorphy#291). `meta` is overridden because the Flutter SDK pins
/// `meta` while the core's `analyzer` pin needs a newer one.
String flutterClusterPubspec(String repoRoot, String uiStub) =>
    '''
name: zfa1003_cluster
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^7.6.1
dependency_overrides:
  zuraffa:
    path: $repoRoot
  zuraffa_ui:
    path: $uiStub
  meta: ^1.18.3
''';

/// Writes the empty `zuraffa_ui` stub package [flutterClusterPubspec] overrides
/// to (see its doc for why).
Directory _writeZuraffaUiStub(Directory root) {
  final stub = Directory(p.join(root.path, '.zfa_fixture', 'zuraffa_ui'))
    ..createSync(recursive: true);
  File(
    p.join(stub.path, 'pubspec.yaml'),
  ).writeAsStringSync('name: zuraffa_ui\npublish_to: none\n');
  File(p.join(stub.path, 'lib', 'zuraffa_ui.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync('');
  return stub;
}

/// Mirrors the zorphy-generated entity surface the presentation plugins
/// reference: the entity itself plus the `ProductFields` descriptors used by
/// `Eq(ProductFields.id, id)` in generated presenters (zorphy emits each
/// field as a `Field<Entity, TValue>` const for type-safe queries).
const String _entityStub = '''
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class Product {
  Product({this.id});

  final String? id;
}

class ProductFields {
  static const Field<Product, String> id = Field<Product, String>('id');
}
''';

const String _repositoryStub = '''
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../entities/product/product.dart';

abstract class ProductRepository {
  Future<Product> get(QueryParams<Product> params);
}
''';

const String _useCaseStub = '''
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../entities/product/product.dart';
import '../../repositories/product_repository.dart';

class GetProductUseCase {
  GetProductUseCase(this._repository);

  final ProductRepository _repository;

  Future<Result<Product, AppFailure>> call(
    QueryParams<Product> params, {
    CancelToken? cancelToken,
  }) {
    return _repository.get(params);
  }
}
''';
