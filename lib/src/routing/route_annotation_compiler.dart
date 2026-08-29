/// Orchestrates the @Route annotation pipeline: scan → validate → generate
/// → write (spec 033 FR-002).
///
/// Used by `zfa build` before build_runner runs. Validation failures throw
/// [RouteCompilationException] carrying EVERY error with file:line
/// locations (SC-003) — one build reports all misconfigurations.
library;

import 'dart:io';

import 'package:yaml/yaml.dart' as yaml;

import 'route_annotation_scanner.dart';
import 'route_config_generator.dart';
import 'route_model.dart';
import 'route_validator.dart';

class RouteAnnotationCompiler {
  static const String routerFilePath = 'lib/src/routing/zfa_router.g.dart';

  /// Compiles all @Route annotations under `<projectRoot>/lib/` and writes
  /// the artifacts.
  ///
  /// Returns a [RouteCompilationOutcome]. When the project has no @Route
  /// annotations and no stale router file, nothing is written and the
  /// outcome is marked `skipped` (projects not using the feature stay
  /// untouched — including the zuraffa repo itself).
  Future<RouteCompilationOutcome> compile(String projectRoot) async {
    final libDir = '$projectRoot/lib';
    final scan = await RouteAnnotationScanner().scanDirectory(libDir);

    final packageName = _readPackageName(projectRoot);

    final controllerSources = <RouteDeclaration, String?>{};
    String? resolveController(RouteDeclaration view) {
      return controllerSources.putIfAbsent(
        view,
        () => _readSiblingController(view),
      );
    }

    final errors = RouteValidator.validate(
      scan,
      controllerSourceOf: resolveController,
    );

    if (errors.isNotEmpty) {
      throw RouteCompilationException(errors);
    }

    final hasContent = scan.routes.isNotEmpty || scan.redirects.isNotEmpty;
    final routerFile = File('$projectRoot/$routerFilePath');
    if (!hasContent && !routerFile.existsSync()) {
      return const RouteCompilationOutcome(
        routeCount: 0,
        redirectCount: 0,
        writtenFiles: {},
        skipped: true,
      );
    }

    final config = RouteConfigGenerator.generate(
      packageName: packageName,
      routes: scan.routes,
      redirects: scan.redirects,
      guardIndex: scan.classIndex,
    );

    final written = <String, String>{};
    final routerAbs = '$projectRoot/$routerFilePath';
    final router = File(routerAbs);
    await router.parent.create(recursive: true);
    await router.writeAsString(config.routerSource);
    written[routerAbs] = config.routerSource;

    for (final entry in config.deepLinkFiles.entries) {
      final file = File('$projectRoot/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
      written[file.path] = entry.value;
    }

    return RouteCompilationOutcome(
      routeCount: scan.routes.length,
      redirectCount: scan.redirects.length,
      writtenFiles: written,
      skipped: false,
    );
  }

  /// Reads the target package's name from `pubspec.yaml` (default:
  /// `app`).
  static String _readPackageName(String projectRoot) {
    final pubspec = File('$projectRoot/pubspec.yaml');
    if (!pubspec.existsSync()) return 'app';
    try {
      final doc = yaml.loadYaml(pubspec.readAsStringSync());
      if (doc is yaml.YamlMap) {
        final name = doc['name'];
        if (name is String && name.isNotEmpty) return name;
      }
    } catch (_) {
      // Malformed pubspec — fall through to default.
    }
    return 'app';
  }

  /// Loads the sibling `<Name>Controller` source for a View, following the
  /// Zuraffa convention (`ProductView` ↔ `ProductController`): first the
  /// same file, then `<name>_controller.dart` / `<name>Controller.dart` in
  /// the same directory.
  static String? _readSiblingController(RouteDeclaration view) {
    // 1. Same-file controller.
    try {
      final source = File(view.filePath).readAsStringSync();
      if (source.contains('Controller')) return source;
    } catch (_) {
      return null;
    }

    // 2. Sibling file by convention.
    final controllerName = _controllerNameFor(view.viewClassName);
    final dir = File(view.filePath).parent;
    final candidates = [
      '${dir.path}/${_snake(controllerName)}.dart',
      '${dir.path}/$controllerName.dart',
      '${dir.path}/${controllerName.toLowerCase()}.dart',
    ];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        try {
          return file.readAsStringSync();
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  static String _controllerNameFor(String viewClassName) {
    if (viewClassName.endsWith('View') && viewClassName.length > 4) {
      return '${viewClassName.substring(0, viewClassName.length - 4)}Controller';
    }
    return '${viewClassName}Controller';
  }

  static String _snake(String name) {
    final buffer = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final char = name[i];
      if (char.toUpperCase() == char && i > 0) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }
}
