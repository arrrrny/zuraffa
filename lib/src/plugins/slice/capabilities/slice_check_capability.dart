/// SliceCheckCapability (spec 1114): the slice compliance check.
///
/// `zfa slice check <feature-id>` validates the slice against its
/// contract — the CONTRACT is the truth (read back from
/// `contract/contract.json`), the DISK is the claim, and the manifest
/// feeds the expectations:
///
/// 1. every file in the slice's `engine/` is in the contract's
///    entities (entity subtree names + entity-mentioning files + the
///    boundary interface + the generated harness);
/// 2. every view in `skin/` is in the contract's routes;
/// 3. every layer is in `xrayLayer` — expanded transitively: a layer's
///    files may occupy its layer or the layers BENEATH it
///    (presentation → {presentation, domain, data},
///    domain → {domain, data}, data → {data});
/// 4. files outside the slice — anything on disk that is not part of
///    the composed base (engine/skin/contract/receipts/specs/slice.yaml/
///    .slice) — FAIL the check. The agent EDITING owned files inside
///    the slice is allowed: that is the work.
///
/// Verdicts: compliant ⇒ success (exit 0) with a report written to
/// `receipts/slice-check.json`; any violation ⇒ failure (exit 1) with
/// the offending files named.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/entities/feature_contract/feature_contract.dart';
import '../generators/feature_slice_composer.dart';
import '../models/feature_slice_manifest.dart';
import '../models/slice_boundary.dart';

/// One compliance violation.
class SliceCheckViolation {
  /// The rule that failed: `engine-entity` | `skin-route` | `layer` |
  /// `outside-slice`.
  final String kind;

  /// The offending file, relative to the slice root.
  final String file;

  /// What went wrong (names the rule and the file).
  final String message;

  const SliceCheckViolation({
    required this.kind,
    required this.file,
    required this.message,
  });

  Map<String, String> toJson() => {
    'kind': kind,
    'file': file,
    'message': message,
  };
}

/// The result of a compliance check.
class SliceCheckResult {
  /// True iff compliant (exit 0).
  final bool success;

  /// The summary line (INV-1: text, never a stack trace).
  final String message;

  /// Every violation, when non-compliant.
  final List<SliceCheckViolation> violations;

  /// How many files were checked.
  final int checkedFiles;

  /// The engine/skin file counts for the report.
  final int engineFiles;
  final int skinFiles;

  /// Absolute path of the written report
  /// (`<slice>/receipts/slice-check.json`).
  final String? reportPath;

  const SliceCheckResult({
    required this.success,
    required this.message,
    this.violations = const [],
    this.checkedFiles = 0,
    this.engineFiles = 0,
    this.skinFiles = 0,
    this.reportPath,
  });
}

/// Checks slice compliance against the feature contract.
class SliceCheckCapability {
  /// Checks the slice for [featureId] under [projectRoot].
  Future<SliceCheckResult> execute({
    required String projectRoot,
    required String featureId,
  }) async {
    final sliceRoot = FeatureSliceComposer.sliceRootOf(projectRoot, featureId);
    final manifestFile = File(p.join(sliceRoot, 'slice.yaml'));
    if (!manifestFile.existsSync()) {
      return SliceCheckResult(
        success: false,
        message:
            'Feature "$featureId" has no composed slice — run '
            '`zfa slice compose $featureId` first (spec 1114).',
      );
    }

    final FeatureSliceManifest manifest;
    try {
      manifest = FeatureSliceManifest.fromYaml(manifestFile.readAsStringSync());
    } on FeatureSliceManifestYamlError catch (error) {
      return SliceCheckResult(
        success: false,
        message:
            'The slice manifest at ${manifestFile.path} is corrupt '
            '(${error.message}) — re-run `zfa slice compose $featureId` '
            '(spec 1114).',
      );
    } on FormatException {
      return SliceCheckResult(
        success: false,
        message:
            'The slice manifest at ${manifestFile.path} is corrupt '
            '(unparseable) — re-run `zfa slice compose $featureId` '
            '(spec 1114).',
      );
    }

    // The CONTRACT is the truth — read back from the slice's own
    // contract JSON, not from the manifest's word.
    final contractFile = File(p.join(sliceRoot, manifest.contractFile));
    if (!contractFile.existsSync()) {
      return SliceCheckResult(
        success: false,
        message:
            'The slice carries no contract at ${manifest.contractFile} '
            '— re-run `zfa slice compose $featureId` (spec 1114).',
      );
    }
    final FeatureContract contract;
    try {
      contract = _contractFromJson(contractFile.readAsStringSync());
    } on Object {
      return SliceCheckResult(
        success: false,
        message:
            'The slice contract at ${contractFile.path} is corrupt '
            '(unparseable) — re-run `zfa slice compose $featureId` '
            '(spec 1114).',
      );
    }

    final violations = <SliceCheckViolation>[];
    var checked = 0;
    final engineDisk = <String>[];
    final skinDisk = <String>[];

    // — walk the slice tree —
    final allowedRootFiles = <String>{
      'slice.yaml',
      'receipts/slice-check.json',
    };
    final sliceDir = Directory(sliceRoot);
    for (final entity in sliceDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final rel = p
          .relative(entity.path, from: sliceRoot)
          .replaceAll('\\', '/');
      if (rel.startsWith('.git/') || rel.startsWith('.git\\')) continue;
      if (rel.startsWith('.slice/')) continue;
      checked++;
      if (rel.startsWith('engine/')) {
        engineDisk.add(rel);
      } else if (rel.startsWith('skin/')) {
        skinDisk.add(rel);
      } else if (rel.startsWith('contract/') ||
          rel.startsWith('receipts/') ||
          rel.startsWith('specs/')) {
        // Contract/receipts/specs are the feature's own record — the
        // mount and receipts mirror the spec tree by construction.
      } else if (!allowedRootFiles.contains(rel)) {
        violations.add(
          SliceCheckViolation(
            kind: 'outside-slice',
            file: rel,
            message:
                'file outside the slice: $rel — the slice is '
                'engine/skin/contract/receipts only (spec 1114)',
          ),
        );
      }
    }

    // 1. Engine compliance: every engine file is in the contract's
    // entities (or the boundary seam, or generated harness).
    final entities = contract.entities ?? const <String>[];
    final boundary = contract.boundary;
    final boundaryBase = boundary == null
        ? null
        : p.basename(boundary.interfaceFile);
    final generatedHarness = <String>{
      if (boundary != null) 'engine/mocks/${_snake(boundary.typeName)}.dart',
      if (boundary != null) 'engine/di/slice_di.dart',
      'skin/routes/router.dart',
    };
    for (final rel in engineDisk..sort()) {
      final ok = _engineFileCompliant(
        rel,
        entities: entities,
        boundaryBase: boundaryBase,
        generated: generatedHarness,
      );
      if (!ok) {
        final claimed = _claimedEntity(rel);
        violations.add(
          SliceCheckViolation(
            kind: 'engine-entity',
            file: rel,
            message:
                'engine file outside the contract entities: $rel '
                '(entity "$claimed" is not declared by the contract — '
                'spec 1114)',
          ),
        );
      }
    }

    // 2. Skin compliance: every view in skin/ is in the contract's
    // routes.
    final routes = contract.routes ?? const <String>{};
    for (final rel in skinDisk..sort()) {
      if (generatedHarness.contains(rel)) continue;
      final ok = _skinFileCompliant(rel, routes: routes);
      if (!ok) {
        violations.add(
          SliceCheckViolation(
            kind: 'skin-route',
            file: rel,
            message:
                'view outside the contract routes: $rel — the slice '
                'exposes only the contract routes (spec 1114)',
          ),
        );
      }
    }

    // 3. Layer compliance: every manifest layer is in xrayLayer
    //    (expanded: its layer or the layers beneath it).
    final allowedLayers = _expandLayers(contract.xrayLayer);
    if (allowedLayers != null) {
      for (final file in [...manifest.engineFiles, ...manifest.skinFiles]) {
        if (!allowedLayers.contains(file.layer)) {
          violations.add(
            SliceCheckViolation(
              kind: 'layer',
              file: file.relativePath,
              message:
                  'layer "${file.layer}" is outside the contract '
                  'xrayLayer "${contract.xrayLayer!.name}" (expanded to '
                  '${allowedLayers.join('/')}) — spec 1114',
            ),
          );
        }
      }
    }

    // — write the report —
    final reportPath = p.join(sliceRoot, 'receipts', 'slice-check.json');
    final report = <String, dynamic>{
      'schema': 'slice.check.v1',
      'feature': contract.id,
      'verdict': violations.isEmpty ? 'compliant' : 'violations',
      'checked_files': checked,
      'engine_files': engineDisk.length,
      'skin_files': skinDisk.length,
      'violations': [for (final v in violations) v.toJson()],
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    File(reportPath).parent.createSync(recursive: true);
    File(
      reportPath,
    ).writeAsStringSync(JsonEncoder.withIndent('  ').convert(report));

    if (violations.isNotEmpty) {
      final kinds = violations.map((v) => v.kind).toSet().toList()..sort();
      return SliceCheckResult(
        success: false,
        message:
            'slice check FAILED for "${contract.id}": '
            '${violations.length} violation(s) [${kinds.join(", ")}] — '
            'files outside the slice: '
            '${violations.map((v) => v.file).take(5).join(", ")}'
            '${violations.length > 5 ? " …" : ""}. '
            'Report: receipts/slice-check.json (spec 1114).',
        violations: violations,
        checkedFiles: checked,
        engineFiles: engineDisk.length,
        skinFiles: skinDisk.length,
        reportPath: reportPath,
      );
    }
    return SliceCheckResult(
      success: true,
      message:
          'slice check: compliant — "${contract.id}" carries only '
          'its contract (${engineDisk.length} engine file(s), '
          '${skinDisk.length} skin file(s), $checked checked). '
          'Report: receipts/slice-check.json (spec 1114).',
      violations: const [],
      checkedFiles: checked,
      engineFiles: engineDisk.length,
      skinFiles: skinDisk.length,
      reportPath: reportPath,
    );
  }

  // ------------------------------------------------------------------
  // compliance rules
  // ------------------------------------------------------------------

  /// Rule 1: an engine file is in the contract's entities when it
  /// lives under an entity subtree (`engine/entities/<E>/`), mentions a
  /// declared entity in its name, IS the boundary interface, or IS a
  /// generated harness file.
  static bool _engineFileCompliant(
    String rel, {
    required List<String> entities,
    required String? boundaryBase,
    required Set<String> generated,
  }) {
    if (generated.contains(rel)) return true;
    if (rel.startsWith('engine/entities/')) {
      final claimed = _claimedEntity(rel);
      return entities.any((e) => e.toLowerCase() == claimed.toLowerCase());
    }
    final base = p.basenameWithoutExtension(rel).toLowerCase();
    final variantsOf = FeatureSliceComposer.nameVariants;
    for (final entity in entities) {
      if (variantsOf(entity).any(base.contains)) return true;
    }
    if (boundaryBase != null &&
        base == p.basenameWithoutExtension(boundaryBase).toLowerCase()) {
      return true;
    }
    return false;
  }

  /// The entity a path under `engine/entities/` claims to belong to.
  static String _claimedEntity(String rel) {
    final parts = rel.split('/');
    // engine/entities/<Entity>/rest...
    return parts.length >= 3 ? parts[2] : '(unknown)';
  }

  /// Rule 2: a skin file is in the contract's routes when its name
  /// carries a route's segments (views), intersects them (widgets/
  /// states), or it is the generated routes barrel.
  static bool _skinFileCompliant(String rel, {required Set<String> routes}) {
    final base = p.basenameWithoutExtension(rel).toLowerCase();
    final tokens = base
        .split(RegExp(r'[_\-.]'))
        .where((t) => t.isNotEmpty)
        .toSet();
    for (final route in routes) {
      final segments = route
          .split('/')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.isEmpty) continue;
      if (segments.every(tokens.contains)) return true;
      if (segments.toSet().intersection(tokens).isNotEmpty) return true;
    }
    return false;
  }

  /// Rule 3: the layers a contract's xrayLayer allows — its own layer
  /// plus every layer BENEATH it. `null` allows every layer
  /// (back-compat: an engine-only Lanes contract has no skin anyway).
  static Set<String>? _expandLayers(XRayLayer? layer) {
    switch (layer) {
      case null:
        return null;
      case XRayLayer.presentation:
        return {'presentation', 'domain', 'data'};
      case XRayLayer.domain:
        return {'domain', 'data'};
      case XRayLayer.data:
        return {'data'};
    }
  }

  static FeatureContract _contractFromJson(String source) {
    final dynamic decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('contract JSON is not an object');
    }
    final boundaryNode = decoded['boundary'];
    final SliceBoundary? boundary;
    if (boundaryNode is Map) {
      boundary = SliceBoundary(
        typeName: boundaryNode['type_name']?.toString() ?? '',
        interfaceFile: boundaryNode['interface_file']?.toString() ?? '',
        diRegistrationFile: boundaryNode['di_registration_file']?.toString(),
        mockStrategy: boundaryNode['mock_strategy']?.toString() ?? 'auto',
      );
    } else {
      boundary = null;
    }
    final xrayLayerValue = decoded['xray_layer'];
    return FeatureContract(
      id: decoded['id']?.toString() ?? '',
      displayName: decoded['display_name']?.toString() ?? '',
      entities: [
        for (final e in (decoded['entities'] as List? ?? const []))
          e.toString(),
      ],
      boundary: boundary,
      routes: {
        for (final r in (decoded['routes'] as List? ?? const [])) r.toString(),
      },
      xrayLayer: xrayLayerValue == null
          ? null
          : XRayLayer.parse(xrayLayerValue.toString()),
    );
  }

  static String _snake(String raw) {
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == '-' || c == ' ' || c == '_') {
        out.write('_');
      } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        out.write('_');
        out.write(c.toLowerCase());
      } else {
        out.write(c.toLowerCase());
      }
    }
    return out.toString();
  }
}
