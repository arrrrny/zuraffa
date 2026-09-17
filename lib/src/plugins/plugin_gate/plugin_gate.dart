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
        final packageRoot = _resolvePackageRoot(rootUri, configPath: file.path);
        final candidate = p.join(packageRoot, 'bin', '${entry.package}.dart');
        if (File(candidate).existsSync()) return candidate;
        return null;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  /// The package root a package_config `rootUri` points at.
  ///
  /// Issue #1690 §1: package_config v2 anchors a RELATIVE `rootUri` at the
  /// CONFIG FILE's own directory (`<project>/.dart_tool/`) — pub writes
  /// relative URIs exactly for relative `path:` deps, the documented
  /// companion install. `Directory(...).absolute` anchored them at
  /// `Directory.current` instead, so a plain `zfa graphql generate` at the
  /// project root resolved a non-existent path and returned null after a
  /// completely correct install. Absolute `file://` URIs keep resolving
  /// unchanged.
  ///
  /// `rootUri` is a URI reference, not filesystem text: pub percent-encodes
  /// segments (a path dep under a `my companion/` directory is written
  /// `../my%20companion/`) and a `file://` value may carry an authority.
  /// Both have to be decoded before the filesystem is touched — the old
  /// `substring(7)` kept `%20` literal and spliced the authority into the
  /// path.
  static String _resolvePackageRoot(
    String rootUri, {
    required String configPath,
  }) {
    final uri = Uri.parse(rootUri);
    final decoded = _filePathOf(uri);
    if (uri.hasScheme || !p.isRelative(decoded)) {
      return p.normalize(decoded);
    }
    final configDir = p.dirname(p.normalize(p.absolute(configPath)));
    return p.normalize(p.join(configDir, decoded));
  }

  /// [uri] as a filesystem path, percent-escapes decoded.
  ///
  /// POSIX [Uri.toFilePath] refuses a non-empty authority
  /// (`file://localhost/…`); dropping it is the right reading for a local
  /// package_config, where pub only ever writes an empty authority.
  static String _filePathOf(Uri uri) {
    try {
      return uri.toFilePath(windows: Platform.isWindows);
    } on UnsupportedError {
      return Uri(
        scheme: 'file',
        path: uri.path,
      ).toFilePath(windows: Platform.isWindows);
    }
  }

  /// The project's `.dart_tool/package_config.json` path, or null when the
  /// project has not run `dart pub get`. Issue #1690 §2: threaded to
  /// `ZfaExecutable.ensureCompiled(packagesFile: …)` so a companion
  /// compile resolves through the CONSUMING project's package graph
  /// instead of triggering Dart's implicit `pub get` inside the pub cache.
  static String? packageConfigPath({String? projectRoot}) {
    final root = _resolveRoot(projectRoot);
    final file = File(p.join(root, '.dart_tool', 'package_config.json'));
    return file.existsSync() ? file.path : null;
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
