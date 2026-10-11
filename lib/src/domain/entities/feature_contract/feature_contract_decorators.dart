/// FeatureContract decorators (spec 1098): persistent knowledge across
/// layers.
///
/// Decorators are the persistence mechanism for the feature contract: emit
/// `@FeatureOwned('<id>')` / `@FeatureContract(...)` COMMENT anchors onto
/// generated artifacts so the knowledge survives round-trips through
/// hand-edits, re-generation, xray scans and slice compositions — without a
/// separate registry that can rot.
///
/// Comment form (not Dart annotations) is deliberate and matches the
/// existing `zfa:` anchor convention: the anchors survive `dart format`,
/// hand-edits and regeneration, and are parseable by [scan] without
/// compiling the target project.
///
/// Slice computes "the minimal base for feature X" by READING decorators,
/// not by guessing path conventions; xray groups the deck by the same
/// annotations; the skin auditor's route table and `zfa:` anchors can be
/// validated against the declared contract at runtime.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'feature_contract.dart';

/// Emits and reads the `@FeatureOwned` / `@FeatureContract` anchors.
class FeatureContractDecorators {
  /// The per-artifact ownership anchor.
  static const String markerOwned = '@FeatureOwned';

  /// The full-contract anchor.
  static const String markerContract = '@FeatureContract';

  const FeatureContractDecorators._();

  /// The one-line ownership anchor for [featureId]
  /// (e.g. `// @FeatureOwned('login')`).
  static String ownedLine(String featureId) => "// $markerOwned('$featureId')";

  /// The full-contract header block for [contract] — every line a comment
  /// anchor so the block survives formatting and hand-edits.
  static String contractHeader(FeatureContract contract) {
    final buffer = StringBuffer()
      ..writeln("// $markerContract(id: '${contract.id}')");
    buffer.writeln("//     displayName: '${contract.displayName}'");
    final entities = contract.entities ?? const <String>[];
    if (entities.isNotEmpty) {
      buffer.writeln('//     entities: [${entities.join(', ')}]');
    }
    final routes = contract.routes ?? const <String>{};
    if (routes.isNotEmpty) {
      buffer.writeln('//     routes: [${routes.join(', ')}]');
    }
    final layer = contract.xrayLayer;
    if (layer != null) {
      buffer.writeln('//     xrayLayer: ${layer.name}');
    }
    return buffer.toString().trimRight();
  }

  /// The `@FeatureOwned` feature id declared in [source], or `null` when
  /// the artifact carries no ownership anchor.
  static String? ownedFeatureOf(String source) {
    final match = RegExp(
      r'''//\s*@FeatureOwned\(\s*(['"])([^'"]+)\1\s*\)''',
    ).firstMatch(source);
    return match?.group(2);
  }

  /// Scans `.dart` files under [root] recursively and groups their
  /// project-relative POSIX paths by owning feature id.
  ///
  /// Files without an anchor belong to no feature and are omitted.
  static Map<String, Set<String>> scan(String root) {
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) return {};
    final grouped = <String, Set<String>>{};
    for (final entity in rootDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      String source;
      try {
        source = entity.readAsStringSync();
      } on FileSystemException {
        continue;
      }
      final featureId = ownedFeatureOf(source);
      if (featureId == null || featureId.isEmpty) continue;
      final rel = p.relative(entity.path, from: root).replaceAll('\\', '/');
      (grouped[featureId] ??= {}).add(rel);
    }
    return grouped;
  }

  /// Partitions [files] (absolute or [root]-relative paths) by the owning
  /// feature declared in each file's `@FeatureOwned` anchor.
  static Map<String, List<String>> groupFilesByFeature(
    Iterable<String> files, {
    String? root,
  }) {
    final grouped = <String, List<String>>{};
    for (final path in files) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final featureId = ownedFeatureOf(file.readAsStringSync());
      if (featureId == null || featureId.isEmpty) continue;
      final key = (root != null && p.isAbsolute(path))
          ? p.relative(path, from: root).replaceAll('\\', '/')
          : path;
      (grouped[featureId] ??= []).add(key);
    }
    return grouped;
  }
}
