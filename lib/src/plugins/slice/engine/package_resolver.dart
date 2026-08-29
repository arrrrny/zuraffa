/// PackageResolver (spec 043): package: URI resolution (FR-009).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Error raised for unusable package configurations (U7).
class PackageResolverError implements Exception {
  /// Creates the error with a user-facing [message].
  const PackageResolverError(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'PackageResolverError: $message';
}

/// Classification of a Dart import URI (FR-009, FR-010).
enum ImportKind {
  /// `dart:` SDK library — read-only framework.
  sdk,

  /// `package:<self>/...` — a file in the project being sliced.
  self,

  /// Third-party package or an unlisted package — never traversed.
  external,

  /// Relative `../foo.dart` or `foo.dart` URI.
  relative,
}

/// The result of loading `.dart_tool/package_config.json` for a project.
class PackageConfig {
  /// Creates the config with [selfPackage] and the [packageRoots] map.
  const PackageConfig({
    required this.selfPackage,
    required this.packageRoots,
    this.packageUris = const {},
  });

  /// The name of the project's own package.
  final String selfPackage;

  /// Package name to root path for every declared package.
  final Map<String, String> packageRoots;

  /// Package name to package URI (usually `lib/`) for every declared package.
  final Map<String, String> packageUris;
}

/// Resolves `package:` and relative import URIs for one project (FR-009).
///
/// Only the self package resolves to traversable project files; every other
/// package — configured or not — is external framework territory (FR-010),
/// so the walker never crosses package boundaries (U6, U8).
class PackageResolver {
  PackageResolver._(this._config, this._projectRoot);

  final PackageConfig _config;
  final String _projectRoot;

  /// The self package name.
  String get packageName => _config.selfPackage;

  /// Loads the package configuration of the project at [projectRoot].
  ///
  /// Throws [PackageResolverError] when `.dart_tool/package_config.json` is
  /// missing (U7) or unreadable.
  static Future<PackageResolver> load(String projectRoot) async {
    final configPath = p.join(
      projectRoot,
      '.dart_tool',
      'package_config.json',
    );
    final file = File(configPath);
    if (!await file.exists()) {
      throw PackageResolverError(
        'No package configuration found at $configPath. Run '
        '`dart pub get` (or `flutter pub get`) in the project first.',
      );
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      throw PackageResolverError(
        'The package configuration at $configPath is not valid JSON. Run '
        '`dart pub get` to regenerate it.',
      );
    }
    final packages = json['packages'];
    if (packages is! List) {
      throw PackageResolverError(
        'The package configuration at $configPath has no packages list. Run '
        '`dart pub get` to regenerate it.',
      );
    }

    var selfPackage = '';
    final roots = <String, String>{};
    final packageUris = <String, String>{};
    for (final entry in packages) {
      if (entry is! Map) continue;
      final name = entry['name'];
      final rootUri = entry['rootUri'];
      if (name is! String || rootUri is! String) continue;
      final root = _resolveRootUri(rootUri, configPath);
      roots[name] = root;
      final packageUri = entry['packageUri'];
      if (packageUri is String) {
        packageUris[name] = packageUri;
      }
      // The self package is the one whose root is the project root itself.
      if (p.equals(root, p.canonicalize(projectRoot))) {
        selfPackage = name;
      }
    }
    if (selfPackage.isEmpty) {
      throw PackageResolverError(
        'The package configuration at $configPath does not declare the '
        'project itself. Run `dart pub get` to regenerate it.',
      );
    }
    return PackageResolver._(
      PackageConfig(
        selfPackage: selfPackage,
        packageRoots: roots,
        packageUris: packageUris,
      ),
      p.canonicalize(projectRoot),
    );
  }

  /// Resolves a `file:` or relative rootUri against the config file location.
  static String _resolveRootUri(String rootUri, String configPath) {
    if (rootUri.startsWith('file://')) {
      return p.canonicalize(Uri.parse(rootUri).toFilePath());
    }
    if (rootUri.startsWith('dart-ext:') || rootUri.contains('://')) {
      // SDK-style entries (e.g. flutter-sdk://...) never map to local paths.
      return rootUri;
    }
    return p.canonicalize(
      p.normalize(p.join(p.dirname(configPath), rootUri)),
    );
  }

  /// Classifies [uri] without touching the filesystem (U6, U8).
  ImportKind classify(String uri) {
    if (uri.startsWith('dart:')) return ImportKind.sdk;
    if (uri.startsWith('package:')) {
      final name = uri.substring('package:'.length).split('/').first;
      return name == _config.selfPackage ? ImportKind.self : ImportKind.external;
    }
    return ImportKind.relative;
  }

  /// Resolves [uri] to an absolute filesystem path, or null when the URI is
  /// SDK/external (never traversed).
  String? resolve(String uri) {
    switch (classify(uri)) {
      case ImportKind.sdk:
      case ImportKind.external:
        return null;
      case ImportKind.self:
        final rest = uri.substring('package:'.length);
        final path = rest.substring(rest.indexOf('/') + 1);
        final root = _config.packageRoots[_config.selfPackage] ?? _projectRoot;
        final packageUri = _config.packageUris[_config.selfPackage] ?? 'lib/';
        return p.canonicalize(p.join(root, packageUri, path));
      case ImportKind.relative:
        // Relative URIs carry no importing file here; the caller must use
        // [resolveRelative].
        return null;
    }
  }

  /// Resolves a relative [uri] against the importing file's directory (U5).
  String resolveRelative(String uri, String importingFile) {
    return p.canonicalize(
      p.normalize(p.join(p.dirname(importingFile), uri)),
    );
  }
}
