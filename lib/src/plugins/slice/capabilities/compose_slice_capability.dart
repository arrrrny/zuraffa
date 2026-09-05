/// ComposeSliceCapability (spec 1098, materialization step 6): resolve a
/// typed FeatureContract → SliceBoundary.
///
/// `zfa slice compose <feature-id>` loads the feature's declared contract
/// (`specs/<id>/contract.yaml`), validates the boundary against the real
/// project, and persists `specs/<id>/compose.plan.json` — the resolved
/// base plan (boundary, routes, entities, layer, decorator) that the
/// sandbox/cut path can consume. No more re-deriving "what belongs to
/// this feature" from string-path conventions: the contract is the single
/// definition of the feature, shared with xray and the engine receipts.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/entities/feature_contract/feature_contract.dart';
import '../../../domain/entities/feature_contract/feature_contract_decorators.dart';
import '../../../domain/entities/feature_contract/feature_contract_registry.dart';

/// The result of a compose resolution.
class ComposeResult {
  final bool success;

  /// Human-readable outcome (also the failure reason on [success] ==
  /// false). INV-1: usage/failure text, never a stack trace.
  final String message;

  /// The resolved contract, when composition succeeded.
  final FeatureContract? contract;

  /// Files written (the compose plan), project-relative.
  final List<String> files;

  const ComposeResult({
    required this.success,
    required this.message,
    this.contract,
    this.files = const [],
  });
}

/// Resolves a feature contract into a compose plan.
class ComposeSliceCapability {
  /// Resolves [featureId] against [projectRoot]'s declared contracts.
  ///
  /// On success writes `specs/<featureId>/compose.plan.json` with the
  /// resolved boundary and the `@FeatureOwned` decorator line.
  Future<ComposeResult> execute({
    required String projectRoot,
    required String featureId,
  }) async {
    final registry = FeatureContractRegistry.scanProject(projectRoot);
    final contract = registry.findById(featureId);
    if (contract == null) {
      final known = registry.knownIds.toList()..sort();
      return ComposeResult(
        success: false,
        message:
            'Unknown feature contract: "$featureId". '
            'Known contracts: '
            '${known.isEmpty ? "(none)" : known.join(", ")}. '
            'Declare it at specs/<feature-id>/contract.yaml (spec 1098).',
      );
    }

    // Validate the boundary against the real project before declaring the
    // composition resolved — a contract pointing at a file that does not
    // exist is not a base an agent can receive.
    final boundary = contract.boundary;
    if (boundary != null) {
      final boundaryFile = File(p.join(projectRoot, boundary.interfaceFile));
      if (!boundaryFile.existsSync()) {
        return ComposeResult(
          success: false,
          contract: contract,
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
      'feature': contract.id,
      'display_name': contract.displayName,
      'entities': contract.entities ?? const <String>[],
      'routes': (contract.routes ?? const <String>{}).toList(),
      'xray_layer': contract.xrayLayer?.name,
      'resolved_boundary': boundary == null
          ? null
          : {
              'type_name': boundary.typeName,
              'interface_file': boundary.interfaceFile,
              'di_registration_file': boundary.diRegistrationFile,
              'mock_strategy': boundary.mockStrategy,
            },
      'decorator': FeatureContractDecorators.ownedLine(contract.id),
    };

    final planFile = File(
      p.join(projectRoot, 'specs', contract.id, 'compose.plan.json'),
    );
    await planFile.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await planFile.writeAsString(encoder.convert(plan));

    final routeCount = (contract.routes ?? const <String>{}).length;
    return ComposeResult(
      success: true,
      contract: contract,
      files: [
        p.relative(planFile.path, from: projectRoot).replaceAll('\\', '/'),
      ],
      message:
          'Resolved feature "${contract.id}" '
          '(${contract.displayName}): '
          '${boundary == null ? "no boundary" : boundary.typeName} boundary, '
          '$routeCount route(s), '
          '${(contract.entities ?? const <String>[]).length} entity(ies). '
          'Plan written to specs/${contract.id}/compose.plan.json.',
    );
  }
}
