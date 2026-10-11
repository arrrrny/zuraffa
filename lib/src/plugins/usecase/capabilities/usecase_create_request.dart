import '../../../models/generator_config.dart';

/// SPEC 1119 — the ONE create-request resolution for the usecase plugin.
///
/// Extracted from the monolithic `CreateUseCaseCapability` (order 5 of
/// the spec): the smart-type inference, the custom-usecase detection and
/// the honest default vocabulary previously existed in TWO copies (the
/// capability's `_generateFiles` and the `zfa usecase create` command).
/// Both now resolve through this class — one derivation, no drift.
class UsecaseCreateRequest {
  final String name;

  /// Raw execution strategy (pre smart-inference).
  final String? useCaseType;
  final List<String> methods;
  final String? domain;
  final String? repo;
  final String? service;
  final List<String> usecases;
  final List<String> variants;
  final String? params;
  final String? returns;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final bool revert;

  const UsecaseCreateRequest({
    required this.name,
    this.useCaseType,
    this.methods = const [],
    this.domain,
    this.repo,
    this.service,
    this.usecases = const [],
    this.variants = const [],
    this.params,
    this.returns,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    this.revert = false,
  });

  /// Normalizes a capability/MCP args map (issue #996 shape) into a
  /// request. Unknown keys are ignored; values are coerced the same way
  /// the capability always coerced them.
  factory UsecaseCreateRequest.fromMap(Map<String, dynamic> args) {
    return UsecaseCreateRequest(
      name: args['name']?.toString() ?? '',
      useCaseType: args['type']?.toString(),
      methods: (args['methods'] as List<dynamic>?)?.cast<String>() ?? const [],
      domain: args['domain']?.toString(),
      repo: args['repo']?.toString(),
      service: args['service']?.toString(),
      usecases:
          (args['usecases'] as List<dynamic>?)?.cast<String>() ?? const [],
      variants:
          (args['variants'] as List<dynamic>?)?.cast<String>() ?? const [],
      params: args['params']?.toString(),
      returns: args['returns']?.toString(),
      dryRun: args['dryRun'] == true,
      force: args['force'] == true,
      verbose: args['verbose'] == true,
      revert: args['revert'] == true,
    );
  }

  /// Smart Type Inference: a Stream return type upgrades the future
  /// default to stream (the rule create has always applied).
  String get effectiveUseCaseType {
    var type = useCaseType;
    if (type == null || type == 'future') {
      if (returns != null && returns!.startsWith('Stream<')) {
        type = 'stream';
      }
    }
    return type ?? 'future';
  }

  /// True when the request names a custom (non-entity) usecase shape.
  bool get isCustomUseCase =>
      repo != null ||
      service != null ||
      usecases.isNotEmpty ||
      variants.isNotEmpty ||
      params != null ||
      returns != null ||
      domain != null;

  /// Entity runs default to the honest vocabulary (spec #972 FR-5):
  /// get,update — anything else must be requested explicitly.
  List<String> get effectiveMethods =>
      (methods.isEmpty && !isCustomUseCase) ? ['get', 'update'] : methods;

  /// The resolved [GeneratorConfig] the generator (and the gate) consume.
  GeneratorConfig toConfig({required String outputDir}) => GeneratorConfig(
    name: name,
    useCaseType: effectiveUseCaseType,
    methods: effectiveMethods,
    outputDir: outputDir,
    domain: domain,
    repo: repo,
    service: service,
    usecases: usecases,
    paramsType: params,
    returnsType: returns,
    dryRun: dryRun,
    force: force,
    verbose: verbose,
    revert: revert,
  );
}
