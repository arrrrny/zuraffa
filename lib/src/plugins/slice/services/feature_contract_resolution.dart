/// Feature-contract resolution for the slice pipeline (spec 1114).
///
/// `zfa slice compose <feature-id>` resolves the feature to a typed
/// [FeatureContract] — never a raw string — from, in order:
///
/// 1. `specs/<feature-id>/contract.yaml` — the #1098 declared fact;
/// 2. the spec's `## Skin Contract:` declaration (skin-contract.v1,
///    issue #1164) — routes/view/state declaration, layer presentation;
/// 3. the spec's `## Lanes` CORE block (issue #1000) — an engine-only
///    feature, layer domain.
///
/// A feature with none of those resolves to `null` — declared facts
/// only, never guessed (the registry's rule, kept here).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/entities/feature_contract/feature_contract.dart';
import '../../../domain/entities/feature_contract/feature_contract_registry.dart';
import '../../../skin/contract/skin_contract_parser.dart';
import '../../tdd/services/spec_parser.dart';

/// A resolved contract plus WHERE it was declared from.
class ResolvedFeatureContract {
  /// The typed contract.
  final FeatureContract contract;

  /// The declaration origin:
  /// `contract.yaml` | `spec.md:skin-contract` | `spec.md:lanes-core`.
  final String origin;

  const ResolvedFeatureContract({required this.contract, required this.origin});
}

/// Resolves [featureId] against [projectRoot]'s declared contracts.
///
/// Order: contract.yaml, then the spec.md `## Skin Contract` JSON, then
/// the spec.md `## Lanes` CORE block. Returns `null` when the feature
/// declares no contract anywhere (unknown feature).
ResolvedFeatureContract? resolveFeatureContract({
  required String projectRoot,
  required String featureId,
}) {
  // 1. The #1098 declared fact.
  final fromYaml = FeatureContractRegistry.loadFromSpecDir(
    p.join(projectRoot, 'specs', featureId),
  );
  if (fromYaml != null) {
    return ResolvedFeatureContract(contract: fromYaml, origin: 'contract.yaml');
  }

  // 2/3. The spec.md declarations.
  final specFile = File(p.join(projectRoot, 'specs', featureId, 'spec.md'));
  if (!specFile.existsSync()) return null;
  final specMd = specFile.readAsStringSync();

  final skin = _fromSkinContract(specMd, featureId);
  if (skin != null) return skin;

  final lanes = _fromLanesCore(specMd, featureId);
  if (lanes != null) return lanes;

  return null;
}

/// The `## Skin Contract: <name>` declaration as a FeatureContract:
/// routes are the declared paths, the layer is presentation (a skin
/// declaration), entities stay undeclared (declared facts only).
ResolvedFeatureContract? _fromSkinContract(String specMd, String featureId) {
  try {
    final declaration = parseSkinContractDeclaration(specMd);
    return ResolvedFeatureContract(
      origin: 'spec.md:skin-contract',
      contract: FeatureContract(
        id: featureId,
        displayName: declaration.name,
        entities: const <String>[],
        routes: {for (final route in declaration.contract.routes) route.path},
        xrayLayer: XRayLayer.presentation,
      ),
    );
  } on SkinContractParseException {
    return null;
  }
}

/// The `## Lanes` CORE block as a FeatureContract: an engine-only
/// feature — layer domain, no routes, entities undeclared (the lane
/// block declares behaviors, not entity ownership).
ResolvedFeatureContract? _fromLanesCore(String specMd, String featureId) {
  final lanes = SpecParser().parseLanes(specMd);
  if (lanes.isEmpty) return null;
  // Only a spec that actually declares a CORE (or BOTH) lane resolves
  // through this path — a skin-only lanes declaration is not an engine
  // contract.
  final hasCore = lanes.any(
    (lane) => lane.lane == 'CORE' || lane.lane == 'BOTH',
  );
  if (!hasCore) return null;
  return ResolvedFeatureContract(
    origin: 'spec.md:lanes-core',
    contract: FeatureContract(
      id: featureId,
      displayName: featureId,
      entities: const <String>[],
      routes: const <String>{},
      xrayLayer: XRayLayer.domain,
    ),
  );
}
