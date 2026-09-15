/// The capability gate (spec 1653-trim-heavy-deps, issue #1661).
///
/// A capability is USABLE when (a) it is enabled — persisted in the
/// project's `.zfa.json` under `capabilities:` by `zfa plugin enable` —
/// and (b) its companion package is resolvable in the project (present
/// in `.dart_tool/package_config.json`, the same resolution seam
/// `ZuraffaBarrelExports` reads). An unusable capability must never
/// crash or half-run: [refusalFor] returns the exact guidance message
/// (or null when usable), so every entry point refuses identically.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'plugin_catalog.dart';

class PluginGate {
  PluginGate._();

  /// Reads the `capabilities:` section of the project's `.zfa.json`.
  /// Absent file or absent section → every capability disabled.
  static Map<String, bool> readCapabilities({String? projectRoot}) {
    final root = _resolveRoot(projectRoot);
    final file = File(p.join(root, '.zfa.json'));
    if (!file.existsSync()) return const {};
    try {
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final section = doc['capabilities'];
      if (section is! Map<String, dynamic>) return const {};
      return section.map((k, v) => MapEntry(k, v == true));
    } on FormatException {
      return const {};
    }
  }

  /// Whether the capability [name] is enabled in the project.
  static bool isEnabled(String name, {String? projectRoot}) =>
      readCapabilities(projectRoot: projectRoot)[name] ?? false;

  /// Whether the companion [package] resolves in the project — present in
  /// `.dart_tool/package_config.json` (the file `dart pub get` writes).
  static bool isResolvable(String package, {String? projectRoot}) {
    final root = _resolveRoot(projectRoot);
    final file = File(p.join(root, '.dart_tool', 'package_config.json'));
    if (!file.existsSync()) return false;
    try {
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final packages = doc['packages'];
      if (packages is! List) return false;
      return packages.any(
        (entry) => entry is Map<String, dynamic> && entry['name'] == package,
      );
    } on FormatException {
      return false;
    }
  }

  /// `null` when the capability is usable right now; otherwise the
  /// guidance message naming the exact fix (FR-008).
  static String? refusalFor(
    String name, {
    String? projectRoot,
    Map<String, bool>? capabilities,
  }) {
    final entry = PluginCatalog.find(name);
    if (entry == null) {
      final names = PluginCatalog.all.map((e) => e.name).join(', ');
      return 'Unknown optional capability: $name\n'
          '   Available capabilities: $names';
    }
    final enabled =
        capabilities?[name] ?? isEnabled(name, projectRoot: projectRoot);
    if (!enabled) {
      return '${entry.name} is an optional capability — run '
          "'zfa plugin enable ${entry.name}' and add "
          'package:${entry.package}';
    }
    if (!isResolvable(entry.package, projectRoot: projectRoot)) {
      return '${entry.package} is enabled but not resolvable in this '
          'project — add it to pubspec.yaml and run dart pub get';
    }
    return null;
  }

  static String _resolveRoot(String? projectRoot) {
    if (projectRoot != null) return projectRoot;
    return Directory.current.path;
  }
}
