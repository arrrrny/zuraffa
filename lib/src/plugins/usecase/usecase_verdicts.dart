import 'package:path/path.dart' as path;

import '../../models/generated_file.dart';

/// Spec #972 machine contracts for the usecase plugin: per-method
/// verdicts, the generation report, and the interface expectation the
/// `zfa make` post-pass verifies.

/// One method's verdict for `zfa usecase create --json`.
///
/// action:
///   * `created`  — the usecase file was newly emitted.
///   * `appended` — the file existed; the `execute` member was appended
///                  in place.
///   * `skipped`  — nothing changed (method already present, dropped by
///                  the source-interface guard, unknown method, or
///                  nothing to delete on the revert path). Carries a
///                  [reason].
///   * `deleted`  — the revert path removed the usecase file.
class MethodVerdict {
  static const actionCreated = 'created';
  static const actionAppended = 'appended';
  static const actionSkipped = 'skipped';
  static const actionDeleted = 'deleted';

  /// Machine-stable reason codes for skipped methods.
  static const reasonUnknownMethod = 'unknown_method';
  static const reasonAlreadyPresent = 'already_present';
  static const reasonNothingToRevert = 'nothing_to_revert';

  final String name;
  final String action;

  /// Present iff [action] is `skipped` (or the file the verdict maps to).
  final String? reason;

  const MethodVerdict({required this.name, required this.action, this.reason});

  Map<String, dynamic> toJson() => {
    'name': name,
    'action': action,
    if (reason != null) 'reason': reason,
  };
}

/// The full report of one entity-usecase generation run: the files (for
/// the existing callers) plus the per-method verdicts and guard outcome
/// (for the spec #972 CLI envelope and receipt).
class UsecaseGenerationReport {
  final List<GeneratedFile> files;

  /// Verdicts in request order, one per requested method.
  final List<MethodVerdict> verdicts;

  /// True when the source interface was absent at generation time (the
  /// same-plan fail-open case).
  final bool interfaceAbsent;

  /// Guard reason codes for the methods the guard dropped, keyed by
  /// method name (`interface_missing_method:<Class>.<method>`).
  final Map<String, String> guardReasonCodes;

  const UsecaseGenerationReport({
    required this.files,
    required this.verdicts,
    required this.interfaceAbsent,
    required this.guardReasonCodes,
  });
}

/// The interface contract a fail-open usecase generation run assumed:
/// "the source interface `<className>` at `<interfacePath>` will declare
/// `methods` by the time this plan commits".
///
/// Recorded into the plan (PluginContext.data → the persisted plan/run
/// artifacts) whenever the guard failed open, and verified by the
/// `zfa make` post-pass ([UsecaseExpectationPostPass]).
class UseCaseInterfaceExpectation {
  /// Entity name the usecases were generated for.
  final String entity;

  /// Interface file path exactly as the guard resolved it (may be
  /// relative to the project root).
  final String interfacePath;

  /// Interface class name the generated usecases call through.
  final String className;

  /// Method set the generated usecases invoke on the interface.
  final List<String> methods;

  /// True when the responsible plugin is the service plugin (the
  /// interface lives under domain/services), false for the repository
  /// plugin.
  final bool viaService;

  const UseCaseInterfaceExpectation({
    required this.entity,
    required this.interfacePath,
    required this.className,
    required this.methods,
    required this.viaService,
  });

  /// The plugin id responsible for declaring this interface.
  String get responsiblePluginId => viaService ? 'service' : 'repository';

  Map<String, dynamic> toJson() => {
    'entity': entity,
    'interface_path': interfacePath.replaceAll('\\', '/'),
    'class_name': className,
    'methods': methods,
    'via_service': viaService,
  };

  factory UseCaseInterfaceExpectation.fromJson(Map<String, dynamic> json) =>
      UseCaseInterfaceExpectation(
        entity: json['entity'] as String,
        interfacePath:
            (json['interface_path'] as String?) ??
            (json['interfacePath'] as String? ?? ''),
        className: json['class_name'] as String,
        methods: ((json['methods'] as List?) ?? const [])
            .map((m) => m.toString())
            .toList(growable: false),
        viaService: (json['via_service'] as bool?) ?? false,
      );

  /// Resolves the interface path against [projectRoot] when relative.
  String resolve(String projectRoot) => path.isAbsolute(interfacePath)
      ? interfacePath
      : path.join(projectRoot, interfacePath);
}
