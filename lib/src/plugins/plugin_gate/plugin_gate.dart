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
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return const {};
      final section = decoded['capabilities'];
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
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return false;
      final packages = decoded['packages'];
      if (packages is! List) return false;
      return packages.any(
        (entry) => entry is Map<String, dynamic> && entry['name'] == package,
      );
    } on FormatException {
      return false;
    }
  }

  /// The companion package's own `bin/<package>.dart` entrypoint, resolved
  /// from the project's `package_config.json` `rootUri` — the path the
  /// core command delegates to (compiled AOT through the `ZfaExecutable`
  /// no-JIT seam). `null` when the package is not resolvable (the gate's
  /// job to have refused already).
  static String? companionEntry(String name, {String? projectRoot}) {
    final entry = PluginCatalog.find(name);
    if (entry == null) return null;
    final root = _resolveRoot(projectRoot);
    final file = File(p.join(root, '.dart_tool', 'package_config.json'));
    if (!file.existsSync()) return null;
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return null;
      final packages = decoded['packages'];
      if (packages is! List) return null;
      for (final pkg in packages) {
        if (pkg is! Map<String, dynamic> || pkg['name'] != entry.package) {
          continue;
        }
        final rootUri = pkg['rootUri'] as String?;
        if (rootUri == null) return null;
        final packageRoot = Directory(
          rootUri.startsWith('file://') ? rootUri.substring(7) : rootUri,
        ).absolute.path;
        final candidate = p.join(packageRoot, 'bin', '${entry.package}.dart');
        if (File(candidate).existsSync()) return candidate;
        return null;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  /// `null` when the capability is usable right now; otherwise the
  /// guidance message naming the exact fix (FR-008). Per SPEC 917 every
  /// refusal ends with a machine-actionable `--> fix:` line.
  static String? refusalFor(
    String name, {
    String? projectRoot,
    Map<String, bool>? capabilities,
  }) {
    final entry = PluginCatalog.find(name);
    if (entry == null) {
      final names = PluginCatalog.all.map((e) => e.name).join(', ');
      return 'Unknown optional capability: $name\n'
          '   Available capabilities: $names\n'
          "   --> fix: run 'zfa plugin list' to see the catalog";
    }
    final enabled =
        capabilities?[name] ?? isEnabled(name, projectRoot: projectRoot);
    if (!enabled) {
      return '${entry.name} is an optional capability — run '
          "'zfa plugin enable ${entry.name}' and add "
          'package:${entry.package}\n'
          "   --> fix: zfa plugin enable ${entry.name}";
    }
    if (!isResolvable(entry.package, projectRoot: projectRoot)) {
      return '${entry.package} is enabled but not resolvable in this '
          'project — add it to pubspec.yaml and run dart pub get\n'
          '   --> fix: add package:${entry.package} to pubspec.yaml '
          'and run dart pub get';
    }
    return null;
  }

  static String _resolveRoot(String? projectRoot) {
    if (projectRoot != null) return projectRoot;
    return Directory.current.path;
  }
}
