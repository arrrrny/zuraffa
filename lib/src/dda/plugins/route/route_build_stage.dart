import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../models/zorphy_context.dart';
import '../../compiler/ast_scanner.dart';
import 'route_plugin.dart';
import 'route_validator.dart';

/// The `zfa build` route stage (spec 033, FR-002): scans a project's `lib/`
/// for `@Route` / `@ZfaRoute` annotations, validates the collected
/// configuration (FR-006), and compiles everything into the single generated
/// router file `lib/src/routing/zfa_router.g.dart`.
///
/// Lifecycle rules (spec edge cases):
/// - Validation errors → the stage FAILS and NO file is written.
/// - No annotations + no previous file → success, nothing written.
/// - No annotations + stale previous file → regenerated as a valid EMPTY
///   configuration (removed routes never survive a rebuild).
/// - No annotations + stale file + no `go_router` dependency → the stale file
///   is deleted (it could never compile) and a warning is reported.
class RouteBuildStage {
  RouteBuildStage({
    required this.projectRoot,
    this.dryRun = false,
    this.verbose = false,
  });

  /// Absolute or relative path of the project root (the directory holding
  /// `pubspec.yaml` and `lib/`).
  final String projectRoot;

  final bool dryRun;
  final bool verbose;

  /// Annotation names this stage scans for.
  static const List<String> routeDecoratorNames = ['Route', 'ZfaRoute'];

  /// Cheap pre-filter: only files whose content mentions a route annotation
  /// are parsed. Keeps the stage inside the SC-002 budget (<2s for 100
  /// Views) even in large projects.
  static final RegExp _contentFilter = RegExp(r'@(Route|ZfaRoute)\b');

  String get routerFilePath =>
      p.join(projectRoot, 'lib', 'src', 'routing', 'zfa_router.g.dart');

  /// Run the stage. Never throws — failures are reported through
  /// [RouteBuildResult.errors].
  Future<RouteBuildResult> run() async {
    final warnings = <String>[];

    final libDir = p.join(projectRoot, 'lib');
    if (!Directory(libDir).existsSync()) {
      // No lib/ at all: nothing to scan, nothing to write.
      return RouteBuildResult.success(warnings: warnings);
    }

    // ── 1. Scan (syntactic fast path — see ASTScanner docs) ──
    final plugin = RouteDDAPlugin();
    plugin.onBuildStart({'projectRoot': projectRoot});

    final scanner = ASTScanner(
      projectRoot: libDir,
      resolve: false,
      includeGlobs: const ['**/*.dart'],
      excludeGlobs: const ['**/*.g.dart', '**/*.freezed.dart'],
      contentFilter: _contentFilter,
    );
    final scanResults = await scanner.scan();

    final routeResults = scanResults
        .where((r) => routeDecoratorNames.contains(r.decorator.name))
        .toList();

    _log(
      'Scanned ${scanResults.length} annotation(s), '
      '${routeResults.length} @Route annotation(s)',
    );

    // ── 2. Collect ──
    final processingErrors = <String>[];
    for (final scan in routeResults) {
      try {
        final ctx = ZorphyContext(
          className: scan.method.className ?? scan.method.name,
          classLibraryUri: scan.method.libraryUri ?? '',
          methodName: scan.method.isClass ? null : scan.method.name,
        );
        plugin.onApply(scan.method, scan.decorator, ctx);
      } catch (e) {
        processingErrors.add(
          'Failed to process @${scan.decorator.name} on '
          '"${scan.method.name}": $e',
        );
      }
    }

    // ── 3. Validate (FR-006) ──
    final deps = _pubspecDependencies(projectRoot);
    final validationErrors = RouteValidator().validate(
      routes: plugin.routeInfos,
      redirects: plugin.redirectInfos,
      nonViewTargets: plugin.nonViewTargets,
      pubspecDeps: deps,
    );

    final errors = <String>[
      ...processingErrors,
      ...validationErrors.map((e) => e.toString()),
    ];
    if (errors.isNotEmpty) {
      return RouteBuildResult(
        success: false,
        errors: errors,
        warnings: warnings,
        wroteRouterFile: false,
      );
    }

    // ── 4. Emit ──
    final routerFile = File(routerFilePath);

    if (!plugin.hasRoutes) {
      if (!routerFile.existsSync()) {
        // No routes, no stale file: nothing to do.
        _log('No @Route annotations found — nothing to generate.');
        return RouteBuildResult.success(warnings: warnings);
      }
      // Stale file: regenerate as a valid empty config (or drop it when the
      // project cannot compile one).
      if (!deps.contains('go_router')) {
        if (!dryRun) {
          routerFile.deleteSync();
        }
        warnings.add(
          'Removed stale $routerFilePath (no @Route annotations remain and '
          'go_router is not a dependency).',
        );
        return RouteBuildResult.success(
          warnings: warnings,
          deletedFiles: [routerFilePath],
        );
      }
      final code = plugin.generateRouterFile();
      if (!dryRun) {
        await _write(routerFile, code);
      }
      warnings.add(
        'Regenerated $routerFilePath as an empty configuration '
        '(no @Route annotations remain).',
      );
      return RouteBuildResult.success(
        warnings: warnings,
        generatedFiles: [routerFilePath],
        wroteRouterFile: true,
      );
    }

    final code = plugin.generateRouterFile();
    if (!dryRun) {
      await _write(routerFile, code);
    }
    return RouteBuildResult.success(
      warnings: warnings,
      generatedFiles: [routerFilePath],
      wroteRouterFile: true,
    );
  }

  Future<void> _write(File file, String content) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    _log('Wrote ${file.path}');
  }

  void _log(String message) {
    if (verbose) {
      // ignore: avoid_print
      print('[zfa:route] $message');
    }
  }

  /// Direct dependency names from `pubspec.yaml` (used for the go_router
  /// precondition). Empty set when pubspec is missing/unparseable.
  static Set<String> _pubspecDependencies(String projectRoot) {
    try {
      final file = File(p.join(projectRoot, 'pubspec.yaml'));
      if (!file.existsSync()) return const {};
      final yaml = loadYaml(file.readAsStringSync()) as YamlMap?;
      if (yaml == null) return const {};
      final deps = yaml['dependencies'];
      if (deps is YamlMap) {
        return deps.keys.map((k) => k.toString()).toSet();
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }
}

/// Outcome of one route build stage run.
class RouteBuildResult {
  RouteBuildResult({
    required this.success,
    this.errors = const [],
    this.warnings = const [],
    this.generatedFiles = const [],
    this.deletedFiles = const [],
    this.wroteRouterFile = false,
  });

  RouteBuildResult.success({
    this.warnings = const [],
    this.generatedFiles = const [],
    this.deletedFiles = const [],
    this.wroteRouterFile = false,
  }) : success = true,
       errors = const [];

  final bool success;

  /// Formatted, actionable error messages (empty on success).
  final List<String> errors;

  final List<String> warnings;

  /// Files written by the stage (absolute/relative paths as constructed).
  final List<String> generatedFiles;

  /// Files deleted by the stage (stale router file removal).
  final List<String> deletedFiles;

  /// Whether `zfa_router.g.dart` was written (or would be, in dry-run).
  final bool wroteRouterFile;
}
