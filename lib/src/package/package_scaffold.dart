import 'dart:io';

import 'package:path/path.dart' as p;

import 'package_names.dart';
import '../version.dart';

/// Thrown by [PackageScaffold] for operator-fixable problems: invalid
/// package names, existing target directories, invalid options.
class PackageScaffoldException implements Exception {
  PackageScaffoldException(this.message);

  final String message;

  @override
  String toString() => 'PackageScaffoldException: $message';
}

/// Result of a successful scaffold.
class PackageScaffoldResult {
  const PackageScaffoldResult({
    required this.packagePath,
    required this.createdFiles,
  });

  /// Absolute path of the created package directory.
  final String packagePath;

  /// Relative paths (within the package) of every file written.
  final List<String> createdFiles;
}

/// Scaffolds a Zuraffa-native reusable package (spec 025, FR-001).
///
/// `zfa package create <name>` delegates here. The scaffold is the
/// standard package layout every other package-SDK capability builds on:
///
/// ```text
/// <name>/
/// ├── pubspec.yaml                        # zuraffa + zorphy deps (v6)
/// ├── build.yaml                          # package-mode marker (FR-011)
/// ├── analysis_options.yaml
/// ├── .gitignore
/// ├── README.md
/// ├── lib/
/// │   ├── <name>.dart                     # barrel: module + registrar
/// │   └── src/
/// │       ├── domain/{entities,repositories,usecases}/
/// │       ├── data/{datasources,repositories}/
/// │       ├── module/<name>_package_module.dart   # runtime module (FR-006)
/// │       └── di/<name>_package_registrar.dart    # registrar stub (FR-004)
/// └── test/package_smoke_test.dart        # test harness
/// ```
///
/// The scaffold passes `dart analyze` and the `zfa build` codegen pipeline
/// with zero manual edits (FR-002): the registrar stub registers nothing
/// until entities are generated, and the smoke test only constructs the
/// module.
class PackageScaffold {
  static final RegExp _validName = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Scaffold dependency versions, aligned with the zuraffa repo's own
  /// resolution (pubspec.yaml) so scaffolded packages resolve the same
  /// ecosystem the CLI was built against.
  static const String _zorphyConstraint = '^2.3.0';
  static const String _buildRunnerConstraint = '^2.15.2';
  static const String _testConstraint = '^1.25.0';
  static const String _sdkConstraint = '^3.11.0';

  /// Creates a new Zuraffa-native package named [name] under
  /// [outputParent].
  ///
  /// - [description] lands in pubspec.yaml + README.
  /// - [zuraffaPath], when given, pins zuraffa as a path dependency
  ///   (local development / in-repo examples) instead of the hosted
  ///   `^<version>` constraint.
  /// - [dryRun] reports what would be written without touching the disk.
  ///
  /// Throws [PackageScaffoldException] when [name] is not a valid
  /// snake_case package name, or when the target directory already exists
  /// (FR-014 — never overwrites).
  Future<PackageScaffoldResult> create({
    required String name,
    required String outputParent,
    String? description,
    String? zuraffaPath,
    bool dryRun = false,
  }) async {
    if (!_validName.hasMatch(name)) {
      throw PackageScaffoldException(
        'Invalid package name: "$name". '
        'Use snake_case (lowercase letters, digits, underscores), '
        'starting with a letter.',
      );
    }

    final packagePath = p.join(outputParent, name);
    final targetDir = Directory(packagePath);
    if (targetDir.existsSync()) {
      throw PackageScaffoldException(
        'Cannot create package "$name": directory already exists at '
        '"${targetDir.absolute.path}". '
        'Choose a different name or remove the existing directory '
        '(the scaffold never overwrites existing content).',
      );
    }

    if (zuraffaPath != null && !Directory(zuraffaPath).existsSync()) {
      throw PackageScaffoldException(
        'Invalid --zuraffa-path: "$zuraffaPath" is not a directory.',
      );
    }

    final pascal = PackageNames.pascalFor(name);
    final files = <String, String>{
      'pubspec.yaml': _pubspec(
        name,
        description ?? 'A Zuraffa-native reusable package.',
        zuraffaPath,
      ),
      'zfa.yaml': _zfaYaml(),
      'build.yaml': _buildYaml(),
      'analysis_options.yaml': _analysisOptions(),
      '.gitignore': _gitignore(),
      'README.md': _readme(name, pascal, description),
      p.join('lib', '$name.dart'): _barrel(name, pascal),
      p.join('lib', 'src', 'module', '${name}_package_module.dart'):
          _moduleStub(name, pascal),
      p.join('lib', 'src', 'di', '${name}_package_registrar.dart'):
          _registrarStub(name, pascal),
      p.join('test', 'package_smoke_test.dart'): _smokeTest(name, pascal),
    };

    // Keep the standard domain/data layout present even though it starts
    // empty (module-only packages are valid — spec edge case).
    final dirs = <String>[
      p.join('lib', 'src', 'domain', 'entities'),
      p.join('lib', 'src', 'domain', 'repositories'),
      p.join('lib', 'src', 'domain', 'usecases'),
      p.join('lib', 'src', 'data', 'datasources'),
      p.join('lib', 'src', 'data', 'repositories'),
      p.join('lib', 'src', 'module'),
      p.join('lib', 'src', 'di'),
      p.join('test'),
    ];

    final created = <String>[];

    if (dryRun) {
      for (final rel in files.keys) {
        created.add(rel);
      }
      return PackageScaffoldResult(
        packagePath: packagePath,
        createdFiles: created,
      );
    }

    for (final dir in dirs) {
      await Directory(p.join(packagePath, dir)).create(recursive: true);
    }

    for (final entry in files.entries) {
      final file = File(p.join(packagePath, entry.key));
      await file.create(recursive: true);
      await file.writeAsString(entry.value);
      created.add(entry.key);
    }

    return PackageScaffoldResult(
      packagePath: packagePath,
      createdFiles: created,
    );
  }

  String _pubspec(String name, String description, String? zuraffaPath) {
    final zuraffaDep = zuraffaPath != null
        ? '  zuraffa:\n    path: $zuraffaPath'
        : '  zuraffa: ^$version';
    // YAML-safe: unquoted descriptions containing `:` (e.g. "Spec 025
    // reference: one entity") break pubspec parsing — always quote and
    // escape (discovered dogfooding the reference package).
    final safeDescription = description
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"');
    return '''
# Zuraffa-native package created by `zfa package create` (spec 025).
name: $name
description: "$safeDescription"
version: 0.1.0
publish_to: none

environment:
  sdk: $_sdkConstraint

dependencies:
$zuraffaDep
  zorphy: $_zorphyConstraint
  zorphy_annotation: $_zorphyConstraint

dev_dependencies:
  build_runner: $_buildRunnerConstraint
  test: $_testConstraint
''';
  }

  String _zfaYaml() {
    return '''
# Zuraffa package-mode marker (spec 025 / FR-011).
#
# `package_mode: true` is the package-shape marker the zfa pipeline reads
# to suppress app-specific codegen (routes, app service locator,
# presentation) and to emit the package registrar instead of the app
# locator (FR-004). The same `zfa make` / `zfa build` commands work here
# and in an app — only the emission shape differs.
#
# This marker lives in zfa.yaml (zfa-owned) rather than build.yaml:
# build_runner strictly validates build.yaml's schema and rejects
# unknown top-level keys, which would break every subsequent build.
package_mode: true
''';
  }

  String _buildYaml() {
    return '''
# build_runner configuration for this Zuraffa-native package (spec 025).
# Mirrors the app-context build.yaml the zfa pipeline scaffolds, so the
# codegen pipeline works identically in package and app context
# (FR-010) — the package-mode signal lives in zfa.yaml.
targets:
  \$default:
    builders:
      zorphy:zorphy:
        enabled: true
        generate_for:
          - lib/src/**
          - test/**
      json_serializable:
        enabled: true
        generate_for:
          - lib/src/**
          - test/**
        options:
          explicit_to_json: false
          include_if_null: false
          generic_argument_factories: true
      source_gen:combining_builder:
        enabled: true
''';
  }

  String _analysisOptions() {
    return '''
# Static analysis configuration for this Zuraffa-native package (spec 025).
# The `zfa build` pipeline runs `dart analyze` as a post-build safety net,
# so the scaffold ships with the default error semantics plus core lints
# that generated code already satisfies.
linter:
  rules:
    - avoid_empty_else
    - avoid_redundant_argument_values
    - empty_statements
    - unnecessary_const
    - unnecessary_new
''';
  }

  String _gitignore() {
    return '''
.dart_tool/
.packages
build/
*.zorphy.dart
*.g.dart
coverage/
''';
  }

  String _readme(String name, String pascal, String? description) {
    return '''
# $name

${description ?? 'A Zuraffa-native reusable package.'}

Created with `zfa package create` (spec 025). See
[Writing Zuraffa packages](https://github.com/arrrrny/zuraffa/blob/master/docs/writing_zuraffa_packages.md)
for the full guide.

## Develop

```bash
dart pub get
zfa entity create -n Product --field id:String --field name:String
zfa make Product datasource repository usecase di
zfa build
dart test
```

## Consume

```dart
final engine = ZuraffaEngine();
engine.registerPackage(${pascal}PackageModule());
await engine.bootstrap();
// the app container now resolves this package's
// datasources / repositories / usecases — no manual registration.
```
''';
  }

  String _barrel(String name, String pascal) {
    return '''
/// Public surface of the `$name` package: the runtime module (lifecycle
/// entry point) and the package registrar (auto-DI registration unit).
///
/// Consuming apps import this barrel and activate the module — everything
/// else is internal architecture (spec 025).
library;

export 'src/module/${name}_package_module.dart';
export 'src/di/${name}_package_registrar.dart';
''';
  }

  String _moduleStub(String name, String pascal) {
    return '''
// Generated by `zfa package create` (spec 025, FR-006).
import 'package:zuraffa/zuraffa.dart';

import '../di/${name}_package_registrar.dart';

/// Runtime module of the `$name` package.
///
/// A consuming app activates this module to register the package's
/// contributed datasources / repositories / usecases into the app's DI
/// container (zero manual registration, FR-005) and to participate in the
/// engine lifecycle: registerDependencies -> onInit -> onReady -> onDispose.
class ${pascal}PackageModule extends PackageModule {
  /// The zuraffa constraint this package was generated against (FR-015).
  /// `ZuraffaEngine.registerPackage` validates it against the running
  /// version and rejects major mismatches with a clear error.
  @override
  String get zuraffaSdkConstraint => '^$version';

  @override
  String get pluginId => '$name';

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    register${pascal}Package(di);
  }

  @override
  Map<String, ZuraffaRouteHandler> get routes => const {};

  /// Runs after every registered module finished `onInit`.
  @override
  Future<void> onReady(ZuraffaDIContainer di) async {}

  /// Runs in reverse registration order on engine shutdown.
  @override
  Future<void> onDispose(ZuraffaDIContainer di) async {}
}
''';
  }

  String _registrarStub(String name, String pascal) {
    return '''
// Generated by `zfa package create` (spec 025, FR-004).
//
// The package registrar is the standalone registration unit a consuming
// app merges into its dependency container via the package module —
// registration is strictly import-scoped (FR-005). `zfa make <Entity>
// ... --di` regenerates this file with every contributed registration.
import 'package:zuraffa/zuraffa.dart';

/// Registers every datasource/repository/usecase contributed by the
/// `$name` package into the consuming app's [di] container.
///
/// Until entities are generated this registers nothing (a module-only
/// package is valid — spec edge case).
void register${pascal}Package(ZuraffaDIContainer di) {
  // Registrations land here as `zfa make ... di` generates architecture
  // (one registrar per package, multi-entity single pass — FR-012).
}
''';
  }

  String _smokeTest(String name, String pascal) {
    return '''
// Generated by `zfa package create` (spec 025) — the package test harness.
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:$name/$name.dart';

void main() {
  test('package exposes a registrable module', () {
    final module = ${pascal}PackageModule();
    expect(module.pluginId, '$name');
    expect(module.routes, isEmpty);
  });

  test('package registrar runs cleanly on a fresh container', () {
    // A module-only package registers nothing but must not throw.
    register${pascal}Package(ZuraffaDIContainer());
  });
}
''';
  }
}
