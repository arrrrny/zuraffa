/// Issue #1190 — generated code imports packages the target's pubspec
/// doesn't declare.
///
/// After the canonical `zfa make <Entity> --preset=crud ... --with=vpc
/// --skin --state --di --test` run, the generated files import packages
/// (`package:zuraffa`, `package:get_it`, skin/framework views, ...) that a
/// fresh target app's pubspec.yaml does not declare. The analyzer then
/// floods the first run with `depend_on_referenced_packages` infos and a
/// strict CI (fatal-infos or pub-check) fails — exactly where AGENTS.md's
/// canonical workflow claims end-to-end success.
///
/// This module is the shared core of both remediation surfaces:
///
/// - `zfa make` diffs the packages the files THIS RUN wrote actually
///   import against the target pubspec and prints the exact `pub add`
///   one-liner on completion (json mode reports it structurally);
/// - `zfa doctor` grew a `generated-imports` named check that scans
///   `lib/` + `test/`, fails with the one-liner as `suggestedFix`, and
///   heals it under `--fix`.
///
/// The extraction is line/statement-anchored: a package URI only counts
/// when it sits inside an `import`/`export` statement, and generated
/// output is dart_style-formatted (statements open at the start of a
/// line). Conditional-import arms (`import 'stub.dart' if
/// (dart.library.io) 'package:x/y.dart';`) span multiple lines and are
/// still real imports, so statements are accumulated until their
/// terminating `;` before extraction.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'dependency_wirer.dart';

/// Packages the Dart SDK / Flutter SDK provide — they are never hosted
/// packages and `pub add <name>` would be the wrong remediation for them.
const sdkProvidedPackages = <String>{
  'flutter',
  'flutter_test',
  'flutter_driver',
  'flutter_localizations',
  'integration_test',
};

/// The diff between the `package:` imports Dart sources use and the
/// dependencies a pubspec.yaml declares.
class PubspecDependencyGap {
  const PubspecDependencyGap({
    required this.importedPackages,
    required this.missing,
    required this.isFlutterProject,
  });

  /// Every external package imported by the scanned sources, sorted.
  final List<String> importedPackages;

  /// The subset of [importedPackages] that pubspec.yaml does not declare
  /// (neither dependencies nor dev_dependencies), sorted.
  final List<String> missing;

  /// Whether the target pubspec declares a Flutter SDK dependency.
  final bool isFlutterProject;

  bool get hasMissing => missing.isNotEmpty;

  /// The missing packages that `pub add <name>` can heal (SDK-provided
  /// packages excluded — they come from the SDK, not pub.dev).
  List<String> get pubAddPackages =>
      missing.where((name) => !sdkProvidedPackages.contains(name)).toList();

  /// The missing packages only the SDK itself provides.
  List<String> get sdkMissingPackages =>
      missing.where(sdkProvidedPackages.contains).toList();

  /// The exact one-liner that heals the hosted gap (issue #1190):
  /// Flutter projects must use `flutter pub add` — the standalone `dart`
  /// executable cannot resolve `sdk: flutter` graphs (the same
  /// convention DependencyWirer.wire already applies). Returns null when
  /// there is nothing `pub add` can heal.
  String? get pubAddOneLiner {
    final packages = pubAddPackages;
    if (packages.isEmpty) return null;
    return '${isFlutterProject ? 'flutter' : 'dart'} pub add '
        '${packages.join(' ')}';
  }
}

/// Extracts `package:` imports from Dart sources and diffs them against a
/// pubspec.yaml's declared dependencies.
class GeneratedImportScanner {
  /// A Dart file's import/export statements open at the start of a line
  /// (generated output is dart_style-formatted; prose mentioning the word
  /// "import" or template strings in generator sources embed it after a
  /// quote and never match).
  static final RegExp _directiveStart = RegExp(r'^\s*(?:import|export)\b');

  /// Quoted package URIs inside an accumulated import/export statement.
  static final RegExp _packageUri = RegExp(
    r'''['"]package:([a-zA-Z_][a-zA-Z0-9_]*)/''',
  );

  /// Packages imported by [dartSources] (whole-file contents), excluding
  /// [hostPackage] (the target's own package name — always declared).
  ///
  /// Pure function — no I/O.
  static Set<String> extractPackageImports(
    Iterable<String> dartSources, {
    String? hostPackage,
  }) {
    final packages = <String>{};
    for (final source in dartSources) {
      final lines = source.split('\n');
      var inStatement = false;
      var statement = StringBuffer();
      for (final line in lines) {
        if (!inStatement && _directiveStart.hasMatch(line)) {
          inStatement = true;
          statement = StringBuffer(line);
        } else if (inStatement) {
          statement.write(' ');
          statement.write(line);
        }
        if (!inStatement) continue;
        // A statement ends at its terminating `;` (conditional-import
        // arms contain no semicolons, so this is unambiguous here).
        final text = statement.toString();
        final semicolon = text.lastIndexOf(';');
        if (semicolon >= 0 && semicolon == text.trim().length - 1) {
          for (final match in _packageUri.allMatches(text)) {
            final name = match.group(1)!;
            if (hostPackage == null || name != hostPackage) {
              packages.add(name);
            }
          }
          inStatement = false;
          statement = StringBuffer();
        }
      }
      // An unterminated statement at EOF (truncated file) — still scan
      // what accumulated so a truncated import is not silently dropped.
      if (inStatement) {
        for (final match in _packageUri.allMatches(statement.toString())) {
          final name = match.group(1)!;
          if (hostPackage == null || name != hostPackage) {
            packages.add(name);
          }
        }
      }
    }
    return packages;
  }

  /// Packages in [importedPackages] that [pubspecContent] does not declare
  /// under `dependencies:` or `dev_dependencies:`.
  ///
  /// A `dependency_overrides:` entry is NOT a declaration: the
  /// `depend_on_referenced_packages` lint the issue is about still fires
  /// for override-only packages. Pure function — no I/O.
  static Set<String> missingFromPubspec(
    String pubspecContent,
    Iterable<String> importedPackages,
  ) {
    YamlMap doc;
    try {
      doc = loadYaml(pubspecContent) as YamlMap;
    } catch (_) {
      // Unparseable pubspec → treat every import as missing; the
      // suggestion is still the fastest path back to a clean analyzer.
      return importedPackages.toSet();
    }
    final deps = (doc['dependencies'] as YamlMap?) ?? YamlMap();
    final devDeps = (doc['dev_dependencies'] as YamlMap?) ?? YamlMap();
    final declared = <String>{
      ...deps.keys.map((k) => k.toString()),
      ...devDeps.keys.map((k) => k.toString()),
    };
    return importedPackages.where((name) => !declared.contains(name)).toSet();
  }

  /// The `pub add` one-liner for [missing] against a target whose Flutter
  /// status is [isFlutter]. SDK-provided packages are excluded from the
  /// line (and the line is null when that leaves nothing). Pure function.
  static String? pubAddOneLiner({
    required Iterable<String> missing,
    required bool isFlutter,
  }) {
    final gap = PubspecDependencyGap(
      importedPackages: missing.toList()..sort(),
      missing: missing.toList()..sort(),
      isFlutterProject: isFlutter,
    );
    return gap.pubAddOneLiner;
  }

  /// Whether [name] is provided by the Dart/Flutter SDK itself.
  static bool isSdkPackage(String name) => sdkProvidedPackages.contains(name);

  /// Diffs [dartFiles] against the pubspec.yaml at [projectRoot].
  ///
  /// Returns null when there is no readable pubspec (not a target project)
  /// so callers can skip silently — the generator may legitimately run
  /// outside a pubspec root in exotic setups.
  static PubspecDependencyGap? analyzeFiles({
    required Iterable<File> dartFiles,
    required String projectRoot,
  }) {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return null;
    final pubspecContent = pubspecFile.readAsStringSync();

    String? hostPackage;
    try {
      final doc = loadYaml(pubspecContent) as YamlMap;
      final name = doc['name'];
      if (name != null) hostPackage = name.toString();
    } catch (_) {
      // Unparseable pubspec: the missing-diff below treats everything as
      // missing; the host-package exclusion is best-effort only.
    }

    final sources = <String>[];
    for (final file in dartFiles) {
      try {
        if (file.existsSync()) sources.add(file.readAsStringSync());
      } catch (_) {
        // Unreadable file — skip; the doctor check re-scans the tree.
      }
    }

    final imported = extractPackageImports(
      sources,
      hostPackage: hostPackage,
    ).toList()..sort();
    final missing = missingFromPubspec(pubspecContent, imported).toList()
      ..sort();
    return PubspecDependencyGap(
      importedPackages: imported,
      missing: missing,
      isFlutterProject: DependencyWirer.isFlutterProject(pubspecContent),
    );
  }

  /// Scans every `.dart` file under [projectRoot]/lib and
  /// [projectRoot]/test and diffs their package imports against the
  /// pubspec.yaml at [projectRoot].
  ///
  /// Returns null when there is no pubspec; the gap's [PubspecDependencyGap
  /// .importedPackages] is empty when no Dart sources exist (the doctor
  /// check skips that case cleanly).
  static PubspecDependencyGap? scanProject({required String projectRoot}) {
    final dartFiles = <File>[];
    for (final dirName in const ['lib', 'test']) {
      final dir = Directory(p.join(projectRoot, dirName));
      if (!dir.existsSync()) continue;
      try {
        dartFiles.addAll(
          dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')),
        );
      } catch (_) {
        // Unreadable subtree — scan what was listed so far.
      }
    }
    return analyzeFiles(dartFiles: dartFiles, projectRoot: projectRoot);
  }
}
