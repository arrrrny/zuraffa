import 'dart:async';

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

  Effect({required this.file, required this.action, this.diff});

  Map<String, dynamic> toJson() => {
    'file': file,
    'action': action,
    if (diff != null) 'diff': diff,
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

  ExecutionResult({
    required this.success,
    this.files = const [],
    this.message,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'files': files,
    if (message != null) 'message': message,
    if (data != null) 'data': data,
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

  /// The AI can ask "What will this do?" before doing it.
  Future<EffectReport> plan(Map<String, dynamic> args);

  /// Execute the action.
  Future<ExecutionResult> execute(Map<String, dynamic> args);
}
