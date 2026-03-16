import 'dart:io';
import 'package:path/path.dart' as path;
import '../../../core/plugin_system/capability.dart';
import '../di_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../../../utils/string_utils.dart';

class RegisterCapability implements ZuraffaCapability {
  final DiPlugin plugin;

  RegisterCapability(this.plugin);

  @override
  String get name => 'register';

  @override
  String get description => 'Register an existing class in DI';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description': 'Name of the class to register (e.g. CategoryProvider, ListingUseCase)',
      },
      'outputDir': {
        'type': 'string',
        'description': 'Directory to output the file',
        'default': 'lib/src',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain name (required if it cannot be inferred)',
      },
      'dryRun': {
        'type': 'boolean',
        'description': 'Run without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Force overwrite existing files',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Enable verbose logging',
        'default': false,
      },
    },
    'required': ['target'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final files = await _runRegistration(args, dryRun: true);

    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: files
          .map((f) => Effect(file: f.path, action: f.action, diff: null))
          .toList(),
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final files = await _runRegistration(args, dryRun: args['dryRun'] ?? false);

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  Future<List<GeneratedFile>> _runRegistration(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final target = args['target'] as String;
    final outputDir = args['outputDir'] ?? 'lib/src';
    final domain = args['domain'];
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    // Determine type and base name
    String baseName = target;
    bool isUseCase = target.endsWith('UseCase');
    bool isService = target.endsWith('Service');
    bool isProvider = target.endsWith('Provider');
    bool isMockProvider = target.endsWith('MockProvider');
    bool isRepository = target.endsWith('Repository');
    bool isDataSource = target.endsWith('DataSource');
    bool isMockDataSource = target.endsWith('MockDataSource');

    if (isUseCase) baseName = target.replaceAll('UseCase', '');
    if (isService) baseName = target.replaceAll('Service', '');
    if (isProvider) baseName = target.replaceAll('Provider', '');
    if (isMockProvider) baseName = target.replaceAll('MockProvider', '');
    if (isRepository) baseName = target.replaceAll('Repository', '');
    if (isDataSource) baseName = target.replaceAll('DataSource', '');
    if (isMockDataSource) baseName = target.replaceAll('MockDataSource', '');

    // Inferred domain if not provided
    String? effectiveDomain = domain;
    if (effectiveDomain == null) {
      effectiveDomain = _inferDomain(baseName, outputDir);
    }

    final config = GeneratorConfig(
      name: baseName,
      outputDir: outputDir,
      domain: effectiveDomain,
      generateDi: true,
      generateUseCase: isUseCase,
      generateService: isService,
      generateData: isProvider || isMockProvider || isRepository || isDataSource || isMockDataSource,
      generateDataSource: isDataSource || isMockDataSource,
      generateRepository: isRepository,
      useMockInDi: isMockProvider || isMockDataSource,
      service: isService || isProvider || isMockProvider ? baseName : null,
      repo: isRepository || isDataSource || isMockDataSource ? baseName : null,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }

  String? _inferDomain(String baseName, String outputDir) {
    final baseSnake = StringUtils.camelToSnake(baseName);
    
    // Check in domain/usecases
    final usecasesDir = Directory(path.join(outputDir, 'domain', 'usecases'));
    if (usecasesDir.existsSync()) {
      for (final dir in usecasesDir.listSync().whereType<Directory>()) {
        if (File(path.join(dir.path, '${baseSnake}_usecase.dart')).existsSync()) {
          return path.basename(dir.path);
        }
      }
    }

    // Check in domain/services
    final servicesDir = Directory(path.join(outputDir, 'domain', 'services'));
    if (servicesDir.existsSync()) {
      for (final dir in servicesDir.listSync().whereType<Directory>()) {
        if (File(path.join(dir.path, '${baseSnake}_service.dart')).existsSync()) {
          return path.basename(dir.path);
        }
      }
    }

    // Fallback to the base name in snake_case as domain
    return baseSnake;
  }
}
