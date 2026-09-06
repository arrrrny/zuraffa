/// The xray_layer decorator (spec 1115, issue #1115): the PERSISTED
/// cross-layer knowledge.
///
/// `@XrayLayer('engine'|'skin'|'shared')` is written by the codegen —
/// every generator's emit, the slice composer's engine/ and skin/ halves —
/// and read back by xray scans (`zfa xray deck --feature`, `zfa xray
/// check`) and the skin auditor, without compiling the target project.
///
/// Comment-anchor form (not a Dart annotation) is deliberate and matches
/// the `@FeatureOwned` convention (spec 1098): the anchor survives
/// `dart format`, hand-edits and regeneration, and keeps generated
/// artifacts dependency-free.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'feature_contract.dart';
import 'feature_contract_decorators.dart';
import '../../../plugins/slice/models/file_graph.dart';

/// Which half of the engine-skin split (#1012) a file belongs to.
enum XraySplit {
  /// Entities, usecases, services, repositories, datasources, engine DI.
  engine,

  /// Views, widgets, states, routes — the skin.
  skin,

  /// Cross-cutting files both halves share (DI index, core, main).
  shared;

  /// Parses a `@XrayLayer('...')` value. Unknown values throw — an
  /// unvalidated split string is exactly the class of bug spec 1115
  /// removes.
  static XraySplit parse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final split in XraySplit.values) {
      if (split.name == normalized) return split;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unknown xray layer (expected one of: '
          '${XraySplit.values.map((s) => s.name).join(", ")})',
    );
  }
}

/// Emits and reads the `@XrayLayer` anchor — the decorator writer and
/// scanner (the `FeatureContractDecorators` counterpart for LAYERS).
class XrayLayerDecorators {
  /// The anchor marker.
  static const String marker = '@XrayLayer';

  const XrayLayerDecorators._();

  /// The one-line layer anchor for [split]
  /// (e.g. `// @XrayLayer('engine')`).
  static String line(XraySplit split) => "// $marker('${split.name}')";

  /// The `XraySplit` declared in [source], or `null` when the file carries
  /// no layer anchor.
  static XraySplit? scan(String source) {
    final match = RegExp(
      r'''//\s*@XrayLayer\(\s*(['"])([a-zA-Z]+)\1\s*\)''',
    ).firstMatch(source);
    if (match == null) return null;
    try {
      return XraySplit.parse(match.group(2)!);
    } on ArgumentError {
      return null;
    }
  }

  /// The split a file at [relativePath] belongs to, derived from the
  /// clean-architecture tree it lives in:
  ///
  /// * `lib/src/presentation/**` → [XraySplit.skin];
  /// * `lib/src/domain/**`, `lib/src/data/**` → [XraySplit.engine];
  /// * everything else (di, core, main, tooling) → [XraySplit.shared].
  static XraySplit forPath(String relativePath) {
    final layer = classifyLayer(relativePath);
    return switch (layer) {
      'view' || 'presenter' || 'presentation_shared' => XraySplit.skin,
      'domain' || 'data' => XraySplit.engine,
      _ => XraySplit.shared,
    };
  }

  /// The contract's deck layer ([XRayLayer]) mapped onto the split:
  /// presentation → skin; domain/data → engine.
  static XraySplit forContractLayer(XRayLayer? layer) => switch (layer) {
    XRayLayer.presentation => XraySplit.skin,
    XRayLayer.domain || XRayLayer.data => XraySplit.engine,
    null => XraySplit.shared,
  };

  /// The whole CONTRACT mapped onto the split — the deck artifact's layer:
  ///
  /// * `xrayLayer: presentation` → skin, `domain`/`data` → engine;
  /// * undeclared: a ROUTED contract is skin-side (routes are skin
  ///   knowledge), an entity-only contract is engine-side.
  static XraySplit forContract(FeatureContract contract) {
    final layer = contract.xrayLayer;
    if (layer != null) return forContractLayer(layer);
    return (contract.routes ?? const <String>{}).isNotEmpty
        ? XraySplit.skin
        : XraySplit.engine;
  }

  /// Stamps [source] with the feature-ownership + layer anchors.
  ///
  /// The anchors ride as a header comment block (before everything) so the
  /// knowledge survives formatting and hand-edits:
  ///
  /// ```
  /// // @FeatureOwned('004-login-ui')
  /// // @XrayLayer('engine')
  /// ```
  ///
  /// Idempotent: an anchor already present is kept as-is (a file the
  /// generator stamped once is not re-stamped, and an EXISTING layer
  /// anchor wins over the path-derived one — the check surfaces real
  /// disagreements instead of silently rewriting them).
  static String stamp({
    required String source,
    required String filePath,
    required String featureId,
  }) {
    return stampSplit(
      source: source,
      split: forPath(filePath),
      featureId: featureId,
    );
  }

  /// Like [stamp] with the split given EXPLICITLY — the slice composer
  /// derives the split from the SLICE tree (`engine/**`, `skin/**`), not
  /// from the host project's paths.
  static String stampSplit({
    required String source,
    required XraySplit split,
    required String featureId,
  }) {
    final ownership = FeatureContractDecorators.ownedFeatureOf(source);
    final existing = scan(source);
    final buffer = StringBuffer();
    if (ownership == null) {
      // Unclaimed file: attribute it. A file already owned by a DIFFERENT
      // feature keeps its anchor — the check surfaces the conflict.
      buffer.writeln(FeatureContractDecorators.ownedLine(featureId));
    }
    if (existing == null) {
      buffer.writeln(line(split));
    }
    final header = buffer.toString();
    if (header.isEmpty) return source;
    return '$header$source';
  }

  /// Scans `.dart` files under [root] recursively and groups their
  /// project-relative POSIX paths by the `@XrayLayer` anchor they carry.
  /// Files without an anchor are omitted.
  static Map<XraySplit, Set<String>> scanRoot(String root) {
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) return {};
    final grouped = <XraySplit, Set<String>>{};
    for (final entity in rootDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      String source;
      try {
        source = entity.readAsStringSync();
      } on FileSystemException {
        continue;
      }
      final split = scan(source);
      if (split == null) continue;
      final rel = p.relative(entity.path, from: root).replaceAll('\\', '/');
      (grouped[split] ??= {}).add(rel);
    }
    return grouped;
  }
}
