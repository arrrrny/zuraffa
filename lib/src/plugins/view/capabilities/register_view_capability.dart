import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:code_builder/code_builder.dart';
import '../../../core/plugin_system/capability.dart';
import '../view_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../../../utils/string_utils.dart';

class RegisterViewCapability implements ZuraffaCapability {
  final ViewPlugin plugin;

  RegisterViewCapability(this.plugin);

  @override
  String get name => 'register';

  @override
  String get description => 'Register entities as parameters in a View';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description':
            'Name of the View to register parameters in (e.g. SplashView)',
      },
      'entities': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'List of entities to add (e.g. Locale, User?). Trailing ? means optional.',
      },
      'outputDir': {
        'type': 'string',
        'description': 'Directory to output the file',
        'default': 'lib/src',
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
    'required': ['target', 'entities'],
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
    final files = await _runRegistration(args);

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
    final files = await _runRegistration(args);

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  Future<List<GeneratedFile>> _runRegistration(
    Map<String, dynamic> args,
  ) async {
    final target = args['target'] as String;
    final entities = List<String>.from(args['entities']);
    final outputDir = args['outputDir'] ?? 'lib/src';
    final dryRun = args['dryRun'] ?? false;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final viewName = target.endsWith('View') ? target : '${target}View';
    final baseName = viewName.replaceAll('View', '');
    final baseSnake = StringUtils.camelToSnake(baseName);

    // 1. Locate existing view file
    final viewFile = _findViewFile(baseSnake, outputDir);
    if (viewFile == null) {
      if (verbose) {
        print('❌ View file not found for: $target');
      }
      return [];
    }

    final domainSnake = path.basename(path.dirname(viewFile.path));

    // 2. Prepare parameters and imports
    final customParameters = <Parameter>[];
    final additionalImports = <String>[];

    for (final entityEntry in entities) {
      final isOptional = entityEntry.endsWith('?');
      final entityName = isOptional
          ? entityEntry.substring(0, entityEntry.length - 1)
          : entityEntry;
      final entitySnake = StringUtils.camelToSnake(entityName);
      final entityCamel = StringUtils.pascalToCamel(entityName);

      customParameters.add(
        Parameter(
          (p) => p
            ..name = entityCamel
            ..type = refer(isOptional ? '$entityName?' : entityName)
            ..named = true
            ..required = !isOptional,
        ),
      );

      // Add entity import
      additionalImports.add(
        '../../domain/entities/$entitySnake/$entitySnake.dart',
      );
    }

    final config = GeneratorConfig(
      name: baseName,
      domain: domainSnake,
      outputDir: outputDir,
      generateView: true,
      generateVpcs: false,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    // 3. Detect if it's a custom view or entity-based
    final isCustom = !viewFile.readAsStringSync().contains('CleanView');

    return await plugin.generateWithCustomParameters(
      config,
      viewName: viewName,
      filePath: viewFile.path,
      customParameters: customParameters,
      additionalImports: additionalImports,
      args: {'capability': isCustom ? 'custom' : 'create'},
    );
  }

  File? _findViewFile(String baseSnake, String outputDir) {
    final pagesDir = Directory(path.join(outputDir, 'presentation', 'pages'));
    if (!pagesDir.existsSync()) return null;

    for (final domainDir in pagesDir.listSync().whereType<Directory>()) {
      final file = File(path.join(domainDir.path, '${baseSnake}_view.dart'));
      if (file.existsSync()) return file;

      final detailFile = File(
        path.join(domainDir.path, '${baseSnake}_detail_view.dart'),
      );
      if (detailFile.existsSync()) return detailFile;
    }

    return null;
  }
}
