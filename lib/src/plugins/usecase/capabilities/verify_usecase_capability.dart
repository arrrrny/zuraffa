import 'dart:io';

import '../../../core/plugin_system/capability.dart';
import '../conformance/usecase_gate.dart';
import '../usecase_plugin.dart';

/// SPEC 1119 — the standalone `verify` capability for the usecase plugin.
///
/// The plugin surface is no longer one-capability-only: agents (MCP) can
/// invoke the per-method conformance gate + entity drift check directly,
/// with the issue #996 provenance contract
/// (`usecase-verify-<entity>-<timestamp>.json`) riding the standard
/// capability receipt wrapper.
class VerifyUsecaseCapability implements ZuraffaCapability {
  final UseCasePlugin plugin;

  VerifyUsecaseCapability(this.plugin);

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify generated usecases conform to the contract — per-method '
      'signature gate + entity drift detection (spec 1119)';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Entity the usecases were generated for (e.g. Product)',
      },
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Override the audited method set (default: the create '
            'receipt, then file discovery)',
      },
      'domain': {'type': 'string', 'description': 'Override the domain folder'},
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'ok': {'type': 'boolean'},
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'findings': {
        'type': 'array',
        'items': {'type': 'object'},
      },
      'drifted': {'type': 'boolean'},
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    // The gate is read-only: the plan is an empty effect set that still
    // names the audited surface.
    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: const [],
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final entity = args['name']?.toString() ?? '';
    if (entity.trim().isEmpty) {
      return ExecutionResult(
        success: false,
        files: const [],
        data: {'error': 'name is required'},
      );
    }

    final report = await UsecaseGate().run(
      projectRoot: Directory.current.path,
      entity: entity,
      methods: (args['methods'] as List<dynamic>?)?.cast<String>(),
      domain: args['domain']?.toString(),
    );

    return ExecutionResult(
      success: report.ok,
      files: const [],
      data: {
        'ok': report.ok,
        'entity': report.entity,
        'methods': report.methods,
        'findings': [for (final finding in report.findings) finding.toJson()],
        'drifted': report.drift?.drifted ?? false,
        'entityDrift': report.drift?.toJson(),
        'receiptBound': report.receiptBound,
        // The receipt hash input (issue #996): binds the audited surface
        // the way create binds the generated surface.
        'methodset': report.methods,
      },
    );
  }
}
