import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/context/file_system.dart';

/// Package-mode marker detection for the v6 package SDK (spec 025,
/// FR-010/FR-011).
///
/// A Zuraffa-native package signals package-mode through its own build
/// configuration file, `zfa.yaml`, at the package root:
///
/// ```yaml
/// # zfa.yaml
/// package_mode: true
/// ```
///
/// The marker deliberately does NOT live in `build.yaml`: build_runner
/// strictly validates that file's schema and rejects unknown top-level
/// keys (verified in the spec-025 e2e — a `zfa:` key makes every
/// subsequent `dart run build_runner build` fail with exit 78). `zfa.yaml`
/// is owned by zfa alone, so the pipeline can extend it freely.
///
/// When the marker is present the zfa pipeline suppresses app-specific
/// codegen (routes, app service locator, presentation) and the DI plugin
/// emits a package registrar instead of the app locator (FR-004). The
/// same `zfa make` / `zfa build` commands work identically in both
/// contexts — only the emission shape differs.
class PackageMode {
  const PackageMode._();

  /// The marker key inside `zfa.yaml`.
  static const String markerKey = 'package_mode';

  /// The zfa-owned configuration file carrying the marker.
  static const String configFile = 'zfa.yaml';

  /// Whether package-mode is enabled for the project rooted at
  /// [projectRoot].
  ///
  /// Reads `<projectRoot>/zfa.yaml` and returns `true` only when
  /// `package_mode` is exactly `true`. Missing files, missing markers,
  /// non-boolean values, and malformed YAML all resolve to `false` — the
  /// detector never throws, so generator paths can call it
  /// unconditionally.
  static bool isEnabled(String projectRoot) {
    final configPath = projectRoot.isEmpty
        ? configFile
        : '$projectRoot/$configFile';
    final file = File(configPath);
    if (!file.existsSync()) return false;
    return _isEnabledInContent(file.readAsStringSync());
  }

  /// Whether package-mode is enabled for the project the [configContent]
  /// (the `zfa.yaml` content) belongs to. Exposed for tests and direct
  /// content checks.
  static bool isEnabledInContent(String configContent) =>
      _isEnabledInContent(configContent);

  /// Whether package-mode is enabled for the project containing
  /// [outputDir] (e.g. `lib/src`), walking up to the project root.
  ///
  /// The marker's `zfa.yaml` and the project's `pubspec.yaml` live side
  /// by side at the project root, so the walk stops at the first
  /// `zfa.yaml` found (marker checked) or at the first `pubspec.yaml`
  /// found without one (definitively not a package-mode project). This
  /// works for both absolute output dirs (tests, `--output`) and the
  /// default relative `lib/src` (resolved against the process CWD, which
  /// is the project root during `zfa` runs).
  static bool isEnabledForOutput(String outputDir, {FileSystem? fileSystem}) {
    final fs = fileSystem ?? const DefaultFileSystem();
    var current = outputDir.isEmpty ? '.' : outputDir;
    while (true) {
      final config = p.join(current, configFile);
      if (fs.existsSync(config)) {
        return _isEnabledInContent(fs.readSync(config));
      }
      // A pubspec.yaml without a sibling zfa.yaml marks the project root
      // of a non-package-mode project — stop walking.
      if (fs.existsSync(p.join(current, 'pubspec.yaml'))) {
        return false;
      }
      final parent = p.dirname(current);
      if (parent == current) return false;
      current = parent;
    }
  }

  static bool _isEnabledInContent(String content) {
    // Tolerate JSON-flavored content too (json is yaml) — irrelevant for
    // the scaffold (yaml) but keeps hand-authored configs forgiving.
    dynamic doc;
    try {
      doc = loadYaml(content);
    } catch (_) {
      try {
        doc = jsonDecode(content);
      } catch (_) {
        return false;
      }
    }
    if (doc is! Map) return false;
    return doc[markerKey] == true;
  }
}
