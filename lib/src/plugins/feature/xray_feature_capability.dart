import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/feature_contract/feature_contract.dart';
import '../../domain/entities/feature_contract/feature_contract_decorators.dart';
import '../../domain/entities/feature_contract/feature_id.dart';
import '../../domain/entities/feature_contract/xray_layer_decorators.dart';
import '../../core/plugin_system/capability.dart';
import '../slice/services/feature_contract_resolution.dart';
import 'feature_plugin.dart';

/// The outcome of validating an xray capability invocation against the
/// registered contracts (spec 1115, issue #1115 item 6).
class XrayCapabilityArgs {
  /// Whether the invocation may run.
  final bool isValid;

  /// The typed feature argument, when it parsed.
  final FeatureId? featureId;

  /// Why the invocation was rejected (empty when valid).
  final List<String> errors;

  const XrayCapabilityArgs({
    required this.isValid,
    this.featureId,
    this.errors = const [],
  });
}

/// `xray` capability (spec 1115, issue #1115 item 6): the feature-plugin
/// surface of the x-ray tool.
///
/// The argument is TYPED — `feature: { type: 'FeatureId', required: true }`
/// — not a raw string: the capability validates the id against the
/// REGISTERED contracts (contract.yaml / spec.md declarations) before
/// anything runs, and executes the feature-grouped deck scan (the same
/// grouping `zfa xray deck --feature` prints).
class XrayFeatureCapability
    implements ZuraffaCapability, FeatureScopedCapability {
  final FeaturePlugin plugin;

  XrayFeatureCapability(this.plugin);

  @override
  String get name => 'xray';

  @override
  String get description =>
      'X-ray a feature: group its code by xray layer '
      '(engine/skin/shared) against its registered contract';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'feature': {
        'type': 'FeatureId',
        'description':
            'The feature contract id (e.g. 004-login-ui). Validated '
            'against the registered contracts — never a raw string.',
      },
      'projectRoot': {'type': 'string', 'description': 'Project root'},
    },
    'required': ['feature'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'features': {
        'type': 'object',
        'description': 'feature id → { files, layers } grouping',
      },
    },
  };

  /// Validates [args]: presence, FeatureId shape, and registration.
  XrayCapabilityArgs validateArgs(Map<String, dynamic> args) {
    final raw = args['feature'];
    if (raw is! String || raw.trim().isEmpty) {
      return const XrayCapabilityArgs(
        isValid: false,
        errors: ["'feature' is required (type: FeatureId)"],
      );
    }
    final featureId = FeatureId.tryParse(raw);
    if (featureId == null) {
      return XrayCapabilityArgs(
        isValid: false,
        errors: [
          "'feature' must be a valid FeatureId (kebab-case, e.g. "
              "'004-login-ui'), got '$raw'",
        ],
      );
    }
    final projectRoot = projectRootOf(args);
    final known = knownFeatureContractIds(projectRoot);
    if (!known.contains(featureId.value)) {
      return XrayCapabilityArgs(
        isValid: false,
        featureId: featureId,
        errors: [
          "unknown feature contract: '${featureId.value}'. "
              'Known contracts: ${known.isEmpty ? "(none)" : known.join(", ")}',
        ],
      );
    }
    return XrayCapabilityArgs(isValid: true, featureId: featureId);
  }

  String projectRootOf(Map<String, dynamic> args) =>
      args['projectRoot'] as String? ?? Directory.current.path;

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final validation = validateArgs(args);
    return EffectReport(
      planId: 'plan_xray_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      isValid: validation.isValid,
      message: validation.errors.isEmpty
          ? 'read-only scan: groups the feature\'s files by xray layer'
          : validation.errors.join('; '),
      changes: const [],
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final validation = validateArgs(args);
    if (!validation.isValid) {
      return ExecutionResult(
        success: false,
        message: validation.errors.join('; '),
      );
    }
    final projectRoot = projectRootOf(args);
    final owned =
        FeatureContractDecorators.scan(
          projectRoot,
        )[validation.featureId!.value] ??
        const <String>{};
    final layers = <String, int>{
      for (final split in XraySplit.values) split.name: 0,
    };
    for (final rel in owned) {
      final file = File(p.join(projectRoot, rel));
      if (!file.existsSync()) continue;
      final split =
          XrayLayerDecorators.scan(file.readAsStringSync()) ??
          XrayLayerDecorators.forPath(rel);
      layers[split.name] = layers[split.name]! + 1;
    }
    return ExecutionResult(
      success: true,
      data: {
        'features': <String, dynamic>{
          validation.featureId!.value: <String, dynamic>{
            'files': owned.toList()..sort(),
            'layers': layers,
          },
        },
      },
    );
  }

  @override
  bool supportsFeature(FeatureContract feature) {
    // X-ray serves every declared feature — it IS the feature-grouping
    // tool. Registration is still enforced by validateArgs at run time.
    return true;
  }
}
