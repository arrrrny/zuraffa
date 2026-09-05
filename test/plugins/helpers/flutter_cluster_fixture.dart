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

/// Writes the Flutter project skeleton (pubspec + domain stubs) into [root].
Future<Directory> writeFlutterClusterStubs(Directory root) async {
  await File(p.join(root.path, 'pubspec.yaml')).create(recursive: true);
  await File(p.join(root.path, 'pubspec.yaml')).writeAsString(_flutterPubspec);
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

const String _flutterPubspec = '''
name: zfa1003_cluster
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
# The Flutter SDK pins `meta` (1.17.0 at 3.41.x) while zuraffa 6.1.0's exact
# `analyzer: 14.1.0` pin requires `meta ^1.18.3`. Overriding `meta` here is
# the documented workaround for consuming zuraffa inside a Flutter app and
# only affects package resolution of the fixture, not the generated code.
dependency_overrides:
  meta: ^1.18.3
''';

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
