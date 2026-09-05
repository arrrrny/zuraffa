/// Shared models for the engine-slice tooling (spec 1002).
///
/// `zfa make engine <Entity>` chains entity → usecase → service →
/// repository → datasource → provider → mock (certified) → di → engine
/// check, and `zfa engine check <Entity>` verifies the wiring afterwards.
/// The models here are shared by the checker, the certifier, the receipt
/// writer, and the CLI commands.
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../core/ast/file_parser.dart';
import '../utils/string_utils.dart';

/// Classification of an `engine check` failure.
enum EngineFindingCode {
  /// The entity source file itself is missing.
  missingEntity,

  /// A `getIt<T>()` lookup resolves to neither a generated class nor a
  /// DI registration file.
  danglingGetIt,

  /// A generated engine file (lib or test) imports `package:flutter`.
  flutterImport,

  /// A requested method is not certified on the generated mock.
  uncertifiedMock,
}

/// One engine-check failure, always carrying an actionable `--> fix:`
/// hint (issue #1002, deliverable 2).
class EngineCheckFailure {
  final EngineFindingCode code;
  final String message;

  /// The getIt type or mock method this failure is about, when applicable.
  final String? typeName;

  /// The file the failure was found in, project-root relative.
  final String? file;

  const EngineCheckFailure({
    required this.code,
    required this.message,
    this.typeName,
    this.file,
  });

  Map<String, dynamic> toJson() => {
    'code': code.name,
    'message': message,
    if (typeName != null) 'type': typeName,
    if (file != null) 'file': file,
  };
}

/// A single `getIt<T>()` lookup found in the engine's DI wiring.
class EngineGetItResolution {
  /// The looked-up type name, e.g. `LoginRepository`.
  final String typeName;

  /// The file the lookup was found in, project-root relative.
  final String sourceFile;

  /// The conventional DI registration file for [typeName], when one
  /// exists (`<snake>_di.dart` anywhere under `lib/src/di/`).
  final String? diRegistrationFile;

  /// A file under `lib/` declaring [typeName] as a top-level symbol.
  final String? declaringFile;

  const EngineGetItResolution({
    required this.typeName,
    required this.sourceFile,
    this.diRegistrationFile,
    this.declaringFile,
  });

  bool get resolved => diRegistrationFile != null || declaringFile != null;
}

/// Per-method mock certification outcome (spec 1002 deliverable 1:
/// `mock create --certify`).
class MockCertificationResult {
  /// The generated mock datasource file, project-root relative, or null
  /// when it was never generated.
  final String? mockDatasourcePath;

  /// The seeded mock data file, project-root relative, or null.
  final String? mockDataPath;

  /// Per-requested-method certification: true when the method is
  /// implemented on the mock datasource AND the seeded data fixture
  /// exists.
  final Map<String, bool> methods;

  const MockCertificationResult({
    this.mockDatasourcePath,
    this.mockDataPath,
    this.methods = const {},
  });

  /// True when every requested method is certified (and, with no methods
  /// requested, both mock artifacts exist).
  bool get certified {
    if (methods.isEmpty) {
      return mockDatasourcePath != null && mockDataPath != null;
    }
    return methods.values.every((certified) => certified);
  }
}

/// The full `engine check` outcome for one entity.
class EngineCheckResult {
  final String entity;
  final String projectRoot;

  /// Every `getIt<T>()` lookup found in the entity's engine wiring.
  final List<EngineGetItResolution> resolutions;

  final List<EngineCheckFailure> failures;

  /// Mock certification outcome, when methods were supplied to check.
  final MockCertificationResult? mockCertification;

  const EngineCheckResult({
    required this.entity,
    required this.projectRoot,
    required this.resolutions,
    required this.failures,
    this.mockCertification,
  });

  /// Names of the getIt lookups that resolved.
  List<String> get resolvedTypes =>
      resolutions.where((r) => r.resolved).map((r) => r.typeName).toList();

  bool get passed => failures.isEmpty;
}

/// Top-level declared type names in a Dart source (classes, mixins,
/// enums, extensions, typedefs, functions, top-level variables) — the
/// same shape the slice engine's barrel resolver extracts, kept local so
/// the engine module stays independent of the slice plugin.
List<String> declaredTopLevelNames(String source) {
  final result = const FileParser().parseSource(source);
  final unit = result.unit;
  if (unit == null) return const [];
  return unit.declarations
      .map((decl) {
        return switch (decl) {
          ClassDeclaration() => decl.namePart.typeName.lexeme,
          MixinDeclaration() => decl.name.lexeme,
          EnumDeclaration() => decl.namePart.typeName.lexeme,
          ExtensionDeclaration() => decl.name?.lexeme,
          TypeAlias() => decl.name.lexeme,
          FunctionDeclaration() => decl.name.lexeme,
          TopLevelVariableDeclaration() =>
            decl.variables.variables.first.name.lexeme,
          _ => null,
        };
      })
      .whereType<String>()
      .toList();
}

/// Canonical engine-slice paths for [entity] inside [projectRoot],
/// project-root relative.
class EngineSlicePaths {
  final String entity;
  final String projectRoot;

  const EngineSlicePaths({required this.entity, required this.projectRoot});

  String get snake => StringUtils.camelToSnake(entity);

  String get entityFile =>
      p.join('lib', 'src', 'domain', 'entities', snake, '$snake.dart');

  /// All `.dart` files under `lib/` whose path mentions the entity snake —
  /// the engine slice's generated surface.
  List<File> sliceLibFiles() => _filesUnder('lib');

  /// All `.dart` files under `test/` whose path mentions the entity
  /// snake — the engine slice's test tree.
  List<File> sliceTestFiles() => _filesUnder('test');

  /// DI files scoped to this entity: every registration file whose path
  /// mentions the snake, plus the composition root (`di/index.dart`,
  /// `di/service_locator.dart`).
  List<File> entityDiFiles() {
    final diRoot = Directory(p.join(projectRoot, 'lib', 'src', 'di'));
    if (!diRoot.existsSync()) return const [];
    final files =
        diRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where((file) {
              final rel = p.relative(file.path, from: projectRoot);
              return rel.contains(snake) ||
                  rel == p.join('lib', 'src', 'di', 'index.dart') ||
                  rel == p.join('lib', 'src', 'di', 'service_locator.dart');
            })
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  List<File> _filesUnder(String root) {
    final dir = Directory(p.join(projectRoot, root));
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              p.relative(file.path, from: projectRoot).contains(snake),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }
}
