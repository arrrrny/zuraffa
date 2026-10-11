/// The generator/runtime version-skew contract (issue #1197, part of
/// #908 P0).
///
/// Observed this cycle: a master generator emitted
/// `package:zuraffa/skin.dart` (spec 1102) into consumers resolved
/// against the published 6.1.0 core — a core that predates the skin
/// barrel — and every such slice died once with `uri_does_not_exist`
/// (120 manual overrides per corpus walk). This module makes that
/// failure mode a CONTRACT instead of a surprise:
///
/// 1. **Floors.** Every `package:zuraffa/*` import the generator
///    emits must either exist across the whole supported core range
///    (from [supportedCoreFloor], the OLDEST supported tag, through
///    master) or be registered in [coreApiFloors] and gated at its
///    emission site. The static half of this contract is pinned by
///    `test/skew/bug_1197_two_end_matrix_test.dart` (the two-end
///    matrix, also run as a CI job); the runtime half is
///    [SkewContract.requireSurfaces].
///
/// 2. **Availability is authoritative.** Version strings are
///    advisory: the `v6.1.0` tag shipped `pubspec.yaml` 6.0.1 while
///    master still says 6.1.0 while carrying `skin.dart`. So the gate
///    asks the RESOLVED core whether the surface file exists — never
///    a version comparison.
///
/// 3. **Fail-open on unknown, fail-closed on known-bad.** When the
///    installed core cannot be resolved at all (no package config,
///    generation into a scaffold) the gate stays out of the way —
///    the same contract as `ZuraffaBarrelExports` (#942/#1176). When
///    the core IS resolved and lacks a required surface, emission is
///    refused with an actionable prescription instead of writing
///    artifacts that cannot compile.
///
/// 4. **Stamped.** Receipts carry `min_core_version` (the declared
///    floor) and `generated_against_core` (what the run resolved),
///    and `zfa doctor` reports the skew triangle: target pubspec pin
///    vs installed core vs running generator (#1184's staleness
///    check feeds this).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../version.dart';

/// The OLDEST supported core — the bottom end of the two-end skew
/// matrix (`test/skew/bug_1197_two_end_matrix_test.dart` + the
/// `skew-matrix` CI workflow). Generated slices must compile against
/// a core at least this old, and against master.
const String supportedCoreFloor = '6.0.0';

/// One declared API floor: a `package:zuraffa/*` surface the
/// generator emits that does NOT exist across the whole supported
/// core range. [introducedIn] is the core version the surface is
/// declared available from (advisory — availability wins); it is
/// stamped into receipts and reported by `zfa doctor`.
class CoreApiFloor {
  /// Stable identifier (`skin-barrel`).
  final String id;

  /// The lib-relative surface URI (`skin.dart`).
  final String uri;

  /// The core version the surface is declared available from.
  final String introducedIn;

  /// Human-readable list of the emission sites that require it.
  final String requiredBy;

  const CoreApiFloor({
    required this.id,
    required this.uri,
    required this.introducedIn,
    required this.requiredBy,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'uri': uri,
    'introduced_in': introducedIn,
    'required_by': requiredBy,
  };
}

/// The declared floors. KEEP IN SYNC WITH the two-end matrix test:
/// any emitted `package:zuraffa/*` URI missing from the oldest
/// supported core must be registered here (and gated), or the matrix
/// goes red.
const List<CoreApiFloor> coreApiFloors = [
  CoreApiFloor(
    id: 'skin-barrel',
    uri: 'skin.dart',
    introducedIn: '6.2.0',
    requiredBy: 'view --skin, app shell --skin-audit, zfa skin kit',
  ),
  CoreApiFloor(
    id: 'simulation-barrel',
    uri: 'simulation.dart',
    introducedIn: '6.2.0',
    requiredBy:
        'zfa di datasource/mock registrations, simulation binding '
        '(spec 893) — caught by the #1197 two-end matrix',
  ),
  CoreApiFloor(
    id: 'xray-overlay',
    uri: 'src/plugins/xray/xray_overlay.dart',
    introducedIn: '6.2.0',
    requiredBy:
        'app shell --xray (spec 036) — caught by the #1197 '
        'two-end matrix',
  ),
];

/// The zuraffa core a generation target actually resolves to.
class InstalledCore {
  /// The core package root (its pubspec.yaml + lib/ live here).
  final String root;

  /// The core's pubspec version, when parseable (advisory).
  final String? version;

  /// Whether this resolution came from the target's package config
  /// (`true`) or the generator's own checkout fallback (`false`).
  final bool fromPackageConfig;

  const InstalledCore({
    required this.root,
    this.version,
    this.fromPackageConfig = true,
  });

  /// Whether the core provides the lib-relative surface [uri].
  bool exposes(String uri) =>
      File(p.join(root, 'lib', uri)).existsSync() ||
      File(p.join(root, uri)).existsSync();
}

/// The verdict of a skew evaluation.
class SkewVerdict {
  /// True when emission may proceed (surfaces present, or the core
  /// was unresolvable — fail-open).
  final bool ok;

  /// True when no core could be resolved at all (fail-open, unknown).
  final bool unknown;

  final String generatorVersion;
  final String? coreVersion;
  final String? coreRoot;
  final List<String> missingSurfaces;
  final List<CoreApiFloor> floors;

  const SkewVerdict({
    required this.ok,
    required this.unknown,
    required this.generatorVersion,
    required this.coreVersion,
    required this.coreRoot,
    required this.missingSurfaces,
    this.floors = coreApiFloors,
  });

  /// The actionable remedy, repo prescription style (#911 precedent).
  String get prescription => 'dart pub upgrade zuraffa';

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'unknown_core': unknown,
    'generator_version': generatorVersion,
    if (coreVersion != null) 'core_version': coreVersion,
    if (coreRoot != null) 'core_root': coreRoot,
    'missing_surfaces': missingSurfaces,
    'floors': floors.map((f) => f.toJson()).toList(),
  };

  /// One-line report for command output.
  String get summary {
    if (!ok) {
      return 'version skew: generator v$generatorVersion needs '
          '${missingSurfaces.join(', ')} — installed core '
          '${coreVersion ?? 'unknown'} does not provide it '
          '(--> fix: $prescription)';
    }
    if (unknown) {
      return 'skew: unknown (installed zuraffa core not resolved — '
          'run dart pub get; generator v$generatorVersion)';
    }
    return 'skew: ok (generator v$generatorVersion, core '
        '${coreVersion ?? 'unknown'})';
  }
}

/// Thrown by [SkewContract.requireSurfaces] when a resolved core
/// lacks a required surface. The message is the report: what is
/// missing, which floor, and the exact fix.
class VersionSkewException implements Exception {
  final SkewVerdict verdict;

  /// The command/site that requested the surface (e.g. `zfa skin kit`).
  final String command;

  const VersionSkewException(this.verdict, this.command);

  @override
  String toString() {
    final buf = StringBuffer()
      ..writeln(
        'version skew: $command refused — the installed zuraffa core '
        'does not provide the API this emission requires.',
      );
    for (final uri in verdict.missingSurfaces) {
      final floor = verdict.floors.where((f) => f.uri == uri).toList();
      buf.writeln(
        '  missing surface: package:zuraffa/$uri'
        '${floor.isEmpty ? '' : ' (declared floor: ${floor.first.introducedIn}, required by ${floor.first.requiredBy})'}',
      );
    }
    buf.writeln(
      '  generator: v${verdict.generatorVersion} | installed core: '
      '${verdict.coreVersion ?? 'unknown'}'
      '${verdict.coreRoot == null ? '' : ' (${verdict.coreRoot})'}',
    );
    buf.writeln('  --> fix: ${verdict.prescription}');
    return buf.toString().trimRight();
  }
}

/// The skew contract surface: resolve the installed core, evaluate
/// required surfaces, gate emission sites.
abstract final class SkewContract {
  static InstalledCore? _seeded;

  /// Test seam: seed an explicit core resolution (mirrors
  /// `ZuraffaBarrelExports.seedForTest`).
  static void seedForTest(InstalledCore? core) => _seeded = core;

  static void resetForTest() => _seeded = null;

  /// Resolves the core for [projectRoot]:
  /// 1. the target's `.dart_tool/package_config.json` → the `zuraffa`
  ///    entry (the core the consumer ACTUALLY compiles against);
  /// 2. fallback: the generator's own checkout, when the generator
  ///    itself runs from a zuraffa source tree (from-source runs share
  ///    their lib/ with the generated import surface);
  /// 3. `null` when neither applies (fail-open territory).
  static InstalledCore? resolveCore(String projectRoot) =>
      _seeded ?? resolveCoreFromRoot(projectRoot);

  static InstalledCore? resolveCoreFromRoot(String projectRoot) {
    final fromConfig = _resolveFromPackageConfig(projectRoot);
    if (fromConfig != null) return fromConfig;
    return _resolveFromGeneratorCheckout();
  }

  static InstalledCore? _resolveFromPackageConfig(String projectRoot) {
    try {
      final config = File(
        p.join(projectRoot, '.dart_tool', 'package_config.json'),
      );
      if (!config.existsSync()) return null;
      final decoded =
          jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
      final packages = decoded['packages'] as List<dynamic>;
      final zuraffa =
          packages.firstWhere(
                (pkg) =>
                    pkg is Map<String, dynamic> && pkg['name'] == 'zuraffa',
                orElse: () => null,
              )
              as Map<String, dynamic>?;
      if (zuraffa == null) return null;
      var root = zuraffa['rootUri'] as String;
      if (root.startsWith('file://')) root = Uri.parse(root).toFilePath();
      if (!p.isAbsolute(root)) {
        // package_config spec: relative rootUri is resolved against the
        // directory CONTAINING package_config.json (.dart_tool/), not
        // the project root — the root package's own entry is '../'.
        root = p.normalize(p.absolute(p.join(projectRoot, '.dart_tool', root)));
      }
      return InstalledCore(
        root: root,
        version: _pubspecVersion(root),
        fromPackageConfig: true,
      );
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// From-source fallback: when the RUNNING generator is the zuraffa
  /// package itself (repo checkout), its own lib/ is the core the
  /// generated imports resolve against in scaffold scenarios. The AOT
  /// binary has no lib/ — then this returns null (fail-open).
  static InstalledCore? _resolveFromGeneratorCheckout() {
    final script = Platform.script.toFilePath();
    final binDir = p.dirname(script);
    final candidates = [
      p.dirname(binDir), // <root>/bin/zfa.dart → <root>
      p.dirname(p.dirname(binDir)), // kernel snapshot nesting
    ];
    for (final root in candidates) {
      final pubspec = File(p.join(root, 'pubspec.yaml'));
      if (!pubspec.existsSync()) continue;
      try {
        final doc = loadYaml(pubspec.readAsStringSync()) as YamlMap;
        if (doc['name'] == 'zuraffa' &&
            Directory(p.join(root, 'lib')).existsSync()) {
          return InstalledCore(
            root: root,
            version: doc['version']?.toString(),
            fromPackageConfig: false,
          );
        }
      } on FileSystemException {
        continue;
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  static String? _pubspecVersion(String packageRoot) {
    final pubspec = File(p.join(packageRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;
    try {
      final doc = loadYaml(pubspec.readAsStringSync()) as YamlMap;
      return doc['version']?.toString();
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Evaluates [requiredUris] against the core resolved for
  /// [projectRoot]. Fail-open (ok, unknown=true) when unresolvable;
  /// fail-closed (ok=false + missing surfaces) when the resolved core
  /// lacks any required URI.
  static SkewVerdict evaluate({
    required String projectRoot,
    required List<String> requiredUris,
  }) {
    final core = resolveCore(projectRoot);
    if (core == null) {
      return SkewVerdict(
        ok: true,
        unknown: true,
        generatorVersion: version,
        coreVersion: null,
        coreRoot: null,
        missingSurfaces: const [],
      );
    }
    final missing = requiredUris.where((uri) => !core.exposes(uri)).toList();
    return SkewVerdict(
      ok: missing.isEmpty,
      unknown: false,
      generatorVersion: version,
      coreVersion: core.version,
      coreRoot: core.root,
      missingSurfaces: missing,
    );
  }

  /// Gates an emission site: throws [VersionSkewException] when the
  /// resolved core lacks any of [requiredUris]. A no-op when the core
  /// satisfies them or cannot be resolved (fail-open, #942 precedent).
  static void requireSurfaces({
    required String projectRoot,
    required String command,
    required List<String> requiredUris,
  }) {
    final verdict = evaluate(
      projectRoot: projectRoot,
      requiredUris: requiredUris,
    );
    if (verdict.ok) return;
    throw VersionSkewException(verdict, command);
  }
}

/// Three-way version comparison for the ADVISORY doctor reporting
/// (never the availability gate). Unparseable versions compare equal.
/// Returns <0, 0, >0 like [Comparable.compareTo].
int compareVersions(String a, String b) {
  final pa = _parse(a);
  final pb = _parse(b);
  if (pa == null || pb == null) return 0;
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return 0;
}

List<int>? _parse(String v) {
  final core = v.split('-').first.split('+').first;
  final parts = core.split('.');
  if (parts.isEmpty || parts.length > 3) return null;
  final nums = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null) return null;
    nums.add(n);
  }
  while (nums.length < 3) {
    nums.add(0);
  }
  return nums;
}
