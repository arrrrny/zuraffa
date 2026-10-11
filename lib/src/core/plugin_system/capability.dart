import 'dart:async';

import '../../domain/entities/feature_contract/feature_contract.dart';

/// A JSON Schema definition (represented as a Map).
typedef JsonSchema = Map<String, dynamic>;

/// Represents a change to be made by a capability.
class Effect {
  /// The file path involved in the effect.
  final String file;

  /// The action to be performed (create, modify, delete, skip).
  final String action;

  /// Optional diff or description of modification.
  final String? diff;

  /// The content of the file before the change (for updates/deletes).
  final String? previousContent;

  Effect({
    required this.file,
    required this.action,
    this.diff,
    this.previousContent,
  });

  Map<String, dynamic> toJson() => {
    'file': file,
    'action': action,
    if (diff != null) 'diff': diff,
    if (previousContent != null) 'previous_content': previousContent,
  };
}

/// The result of planning a capability execution.
class EffectReport {
  /// Unique ID for this plan (for future reference/execution).
  final String planId;

  /// The ID of the plugin that generated this plan.
  final String pluginId;

  /// The name of the capability that generated this plan.
  final String capabilityName;

  /// The arguments used to generate this plan.
  final Map<String, dynamic> args;

  /// List of effects that will occur.
  final List<Effect> changes;

  /// Whether the plan is valid and can be executed.
  final bool isValid;

  /// Optional message or error description.
  final String? message;

  EffectReport({
    required this.planId,
    required this.pluginId,
    required this.capabilityName,
    required this.args,
    required this.changes,
    this.isValid = true,
    this.message,
  });

  Map<String, dynamic> toJson() => {
    'plan_id': planId,
    'plugin_id': pluginId,
    'capability_name': capabilityName,
    'args': args,
    'valid': isValid,
    if (message != null) 'message': message,
    'changes': changes.map((e) => e.toJson()).toList(),
  };
}

/// The result of executing a capability.
class ExecutionResult {
  /// Whether the execution was successful.
  final bool success;

  /// List of files modified or created.
  final List<String> files;

  /// Optional message or error description.
  final String? message;

  /// Optional additional data returned by the execution.
  final Map<String, dynamic>? data;

  /// Structured warnings (spec 0974, issue #974): non-fatal outcomes a
  /// caller can act on. Each entry carries `target` (the file, entity or
  /// capability-level object the warning is about) and `reason` (why).
  /// Empty (and omitted from [toJson]) when there is nothing to report.
  final List<Map<String, dynamic>> warnings;

  ExecutionResult({
    required this.success,
    this.files = const [],
    this.message,
    this.data,
    this.warnings = const [],
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'files': files,
    if (message != null) 'message': message,
    if (data != null) 'data': data,
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}

/// A strict capability interface that allows the Kernel to "interview" plugins.
abstract class ZuraffaCapability {
  /// The unique name of the capability (e.g., "create_usecase").
  String get name;

  /// Precise prompt/description for AI.
  String get description;

  /// JSON Schema for input arguments.
  JsonSchema get inputSchema;

  /// JSON Schema for output result.
  JsonSchema get outputSchema;

  /// Feature scope (spec 1098, issue #1098): capabilities that need to
  /// control which feature contracts they serve implement the
  /// [FeatureScopedCapability] protocol below. Capabilities without it are
  /// unscoped — they serve every feature. The plugin loader consults the
  /// protocol when a typed FeatureContract is active: a plugin with any
  /// protocol-declaring capability that refuses the feature is not loaded
  /// for that feature.

  /// The AI can ask "What will this do?" before doing it.
  Future<EffectReport> plan(Map<String, dynamic> args);

  /// Execute the action.
  Future<ExecutionResult> execute(Map<String, dynamic> args);
}

/// Opt-in feature-scoping protocol (spec 1098, gap 8): the capability
/// layer can DECLARE which features a capability serves, and the plugin
/// loader VALIDATES it when loading feature-scoped registries.
abstract interface class FeatureScopedCapability implements ZuraffaCapability {
  /// Whether this capability serves [feature].
  bool supportsFeature(FeatureContract feature);
}
