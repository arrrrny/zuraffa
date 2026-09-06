/// ComposeSliceCapability (spec 1098 step 6 + spec 1114): resolve a
/// typed FeatureContract and compose the feature's slice.
///
/// `zfa slice compose <feature-id>` resolves the feature's declared
/// contract (`specs/<id>/contract.yaml`, or the spec's `## Skin
/// Contract` JSON, or its `## Lanes` CORE block — spec 1114), validates
/// the boundary against the real project, persists
/// `specs/<id>/compose.plan.json` (the 1098 resolved base plan) AND
/// writes the feature slice `.zfa/slices/<id>/` with engine/, skin/,
/// contract/ and receipts/ (spec 1114) — the minimal base an agent
/// receives for that feature, and only that feature.
///
/// The contract may arrive TYPED via [contract] (the PluginContext
/// carrier, #1114 item 5): the capability then uses it instead of
/// re-resolving the raw string id.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/entities/feature_contract/feature_contract.dart';
import '../../../domain/entities/feature_contract/feature_contract_decorators.dart';
import '../generators/feature_slice_composer.dart';
import '../models/feature_slice_manifest.dart';
import '../services/feature_contract_resolution.dart';

/// The result of a compose resolution.
class ComposeResult {
  final bool success;

  /// Human-readable outcome (also the failure reason on [success] ==
  /// false). INV-1: usage/failure text, never a stack trace.
  final String message;

  /// The resolved contract, when composition succeeded.
  final FeatureContract? contract;

  /// Files written (the compose plan + the slice tree's top-level
  /// records), project-relative.
  final List<String> files;

  /// Absolute path to the composed slice root (spec 1114), on success.
  final String? sliceRoot;

  /// The feature-centric manifest of the composed slice (spec 1114).
  final FeatureSliceManifest? manifest;

  const ComposeResult({
    required this.success,
    required this.message,
    this.contract,
    this.files = const [],
    this.sliceRoot,
    this.manifest,
  });
}

/// Resolves a feature contract and composes its slice.
class ComposeSliceCapability {
  /// Resolves [featureId] against [projectRoot]'s declared contracts.
  ///
  /// On success writes `specs/<featureId>/compose.plan.json` (the 1098
  /// plan) and `.zfa/slices/<featureId>/` (the 1114 slice: engine/,
  /// skin/, contract/, receipts/, specs/ mount, slice.yaml).
  ///
  /// [contract] (spec 1114, item 5): the typed contract carried by the
  /// PluginContext — when set, it is the resolution (the raw string id
  /// is not re-resolved); its id must agree with [featureId].
  Future<ComposeResult> execute({
    required String projectRoot,
    required String featureId,
    FeatureContract? contract,
    bool force = false,
  }) async {
    // Spec 1114: the typed carrier wins; the string is only a fallback.
    FeatureContract? typed = contract;
    String origin = 'context';
    if (typed != null && typed.id != featureId) {
      return ComposeResult(
        success: false,
        message:
            'Feature contract mismatch: the context carries '
            '"${typed.id}" but the invocation asked for "$featureId". '
            'The typed contract is the definition (spec 1114).',
      );
    }
    if (typed == null) {
      final resolved = resolveFeatureContract(
        projectRoot: projectRoot,
        featureId: featureId,
      );
      typed = resolved?.contract;
      origin = resolved?.origin ?? 'context';
    }

    if (typed == null) {
      final known = knownFeatureContractIds(projectRoot);
      return ComposeResult(
        success: false,
        message:
            'Unknown feature contract: "$featureId". '
            'Known contracts: '
            '${known.isEmpty ? "(none)" : known.join(", ")}. '
            'Declare it at specs/<feature-id>/contract.yaml (spec 1098) '
            'or in the spec\'s ## Skin Contract / ## Lanes section '
            '(spec 1114).',
      );
    }
    final feature = typed;

    // Validate the boundary against the real project before declaring
    // the composition resolved — a contract pointing at a file that
    // does not exist is not a base an agent can receive.
    final boundary = feature.boundary;
    if (boundary != null) {
      final boundaryFile = File(p.join(projectRoot, boundary.interfaceFile));
      if (!boundaryFile.existsSync()) {
        return ComposeResult(
          success: false,
          contract: feature,
          message:
              'Feature "$featureId" boundary is unresolved: interface file '
              '"${boundary.interfaceFile}" does not exist in the project. '
              'Fix the contract boundary or generate '
              '${boundary.typeName} first (spec 1098).',
        );
      }
    }

    final plan = <String, dynamic>{
      'schema': 'compose.plan.v1',
      'feature': feature.id,
      'display_name': feature.displayName,
      'entities': feature.entities ?? const <String>[],
      'routes': (feature.routes ?? const <String>{}).toList(),
      'xray_layer': feature.xrayLayer?.name,
      'resolved_boundary': boundary == null
          ? null
          : {
              'type_name': boundary.typeName,
              'interface_file': boundary.interfaceFile,
              'di_registration_file': boundary.diRegistrationFile,
              'mock_strategy': boundary.mockStrategy,
            },
      'decorator': FeatureContractDecorators.ownedLine(feature.id),
    };

    // Spec 1114: compose the feature slice FIRST — engine/skin/
    // contract/receipts at .zfa/slices/<id>/ — so the receipts copy
    // exactly the feature's pre-existing spec tree (never this run's
    // own plan output).
    final FeatureSliceComposition composition;
    try {
      composition = FeatureSliceComposer().compose(
        projectRoot: projectRoot,
        contract: feature,
        origin: origin,
        force: force,
      );
    } on StateError catch (error) {
      return ComposeResult(
        success: false,
        contract: feature,
        message: error.message,
      );
    }

    final planFile = File(
      p.join(projectRoot, 'specs', feature.id, 'compose.plan.json'),
    );
    await planFile.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await planFile.writeAsString(encoder.convert(plan));

    final routeCount = (feature.routes ?? const <String>{}).length;
    final entityCount = (feature.entities ?? const <String>[]).length;
    return ComposeResult(
      success: true,
      contract: feature,
      sliceRoot: composition.sliceRoot,
      manifest: composition.manifest,
      files: [
        p.relative(planFile.path, from: projectRoot).replaceAll('\\', '/'),
        '${composition.manifest.sliceRoot}/slice.yaml',
        '${composition.manifest.sliceRoot}/contract/contract.json',
      ],
      message:
          'Resolved feature "${feature.id}" '
          '(${feature.displayName}): '
          '${boundary == null ? "no boundary" : boundary.typeName} boundary, '
          '$routeCount route(s), '
          '$entityCount entity(ies). '
          'Plan written to specs/${feature.id}/compose.plan.json. '
          'Slice written to ${composition.manifest.sliceRoot} '
          '(${composition.manifest.engineFiles.length} engine file(s), '
          '${composition.manifest.skinFiles.length} skin file(s), '
          '${composition.manifest.receiptsFiles.length} receipt(s)) — '
          'open it with `zfa slice worktree ${feature.id}` (spec 1114).',
    );
  }
}
