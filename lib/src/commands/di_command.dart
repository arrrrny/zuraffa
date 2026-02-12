import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../generator/code_generator.dart';
import '../utils/string_utils.dart';
import '../config/zfa_config.dart';
import '../core/context/progress_reporter.dart';

class DiCommand {
  Future<GeneratorResult> execute(
    List<String> args, {
    bool exitOnCompletion = true,
  }) async {
    if (args.isEmpty) {
      print('❌ Usage: zfa di <UseCaseName> [options]');
      print('\nRun: zfa di --help for more information');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: ['Missing arguments'],
        nextSteps: [],
      );
    }

    if (args[0] == '--help' || args[0] == '-h') {
      _printHelp();
      if (exitOnCompletion) exit(0);
      return GeneratorResult(
        name: 'help',
        success: true,
        files: [],
        errors: [],
        nextSteps: [],
      );
    }

    final useCaseName = args[0];
    if (useCaseName.startsWith('--')) {
      print('❌ Missing use case name');
      print('Usage: zfa di <UseCaseName> [options]');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: ['Missing use case name'],
        nextSteps: [],
      );
    }

    final parser = _buildArgParser();
    final ArgResults results;
    try {
      results = parser.parse(args.skip(1).toList());
    } on FormatException catch (e) {
      print('❌ ${e.message}');
      print('\nRun: zfa di --help for usage information');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: [e.message],
        nextSteps: [],
      );
    }

    final outputDir = _resolveOutputDir(results['output'] as String?);
    final dryRun = results['dry-run'] == true;
    final force = results['force'] == true;
    final verbose = results['verbose'] == true;
    final domain = results['domain'] as String? ?? 'general';
    final useMock = results['use-mock'] == true;

    try {
      // Try to find and analyze the existing usecase
      final useCaseAnalysis = await _analyzeUseCase(
        useCaseName,
        outputDir,
        domain,
      );

      if (useCaseAnalysis == null) {
        print('❌ UseCase not found: $useCaseName');
        print('   Searched in all: lib/src/domain/usecases/*/');
        if (exitOnCompletion) exit(1);
        return GeneratorResult(
          name: useCaseName,
          success: false,
          files: [],
          errors: ['UseCase not found: $useCaseName'],
          nextSteps: ['Ensure the usecase exists before generating DI'],
        );
      }

      if (verbose) {
        print('Analyzing ${useCaseAnalysis['className']}...');
        print('  Type: ${useCaseAnalysis['useCaseType']}');
        print('  Repositories: ${useCaseAnalysis['repos']}');
        print('  Services: ${useCaseAnalysis['services']}');
        print('  Is Orchestrator: ${useCaseAnalysis['isOrchestrator']}');
      }

      final config = _buildConfig(useCaseName, useCaseAnalysis, results);

      print(
        '📦 Generating DI registration for ${useCaseAnalysis['className']}...',
      );

      final progressReporter = CliProgressReporter(verbose: verbose);

      final generator = CodeGenerator(
        config: config,
        outputDir: outputDir,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        progressReporter: progressReporter,
        disabledPluginIds: {
          'usecase',
          'repository',
          'datasource',
          'view',
          'presenter',
          'controller',
          'state',
          'route',
          'test',
          'mock',
          'cache',
          'graphql',
          'observer',
          'provider',
          'service',
          'method_append',
        },
      );

      final result = await generator.generate();

      if (exitOnCompletion) {
        if (result.success) {
          print('\n✅ Generated ${result.files.length} DI file(s)');
          for (final file in result.files) {
            print('  ✓ ${file.path} (${file.action})');
          }
          if (result.nextSteps.isNotEmpty) {
            print('\n📝 Next steps:');
            for (final step in result.nextSteps) {
              print('   • $step');
            }
          }
        } else {
          print('\n❌ Generation failed');
          for (final error in result.errors) {
            print('   • $error');
          }
        }
        exit(result.success ? 0 : 1);
      }

      return result;
    } catch (e) {
      final failure = GeneratorResult(
        name: useCaseName,
        success: false,
        files: [],
        errors: [e.toString()],
        nextSteps: [],
      );

      if (exitOnCompletion) {
        print('❌ Error: $e');
        exit(1);
      }
      return failure;
    }
  }

  Future<Map<String, dynamic>?> _analyzeUseCase(
    String useCaseName,
    String outputDir,
    String domain,
  ) async {
    // Normalize use case name
    final nameWithoutSuffix = useCaseName.replaceAll('UseCase', '');
    final useCaseSnake = StringUtils.camelToSnake(nameWithoutSuffix);
    final className = '${nameWithoutSuffix}UseCase';

    // First, try the specified domain
    final domainDir = Directory(
      path.join(outputDir, 'domain', 'usecases', domain),
    );
    if (domainDir.existsSync()) {
      final useCaseFile = File(
        path.join(domainDir.path, '${useCaseSnake}_usecase.dart'),
      );

      if (useCaseFile.existsSync()) {
        final content = await useCaseFile.readAsString();
        return _parseUseCaseFile(content, className, domain);
      }
    }

    // If not found, search in all domain folders
    final usecasesDir = Directory(path.join(outputDir, 'domain', 'usecases'));
    if (usecasesDir.existsSync()) {
      for (final dir in usecasesDir.listSync()) {
        if (dir is Directory) {
          final foundDomain = path.basename(dir.path);
          final useCaseFile = File(
            path.join(dir.path, '${useCaseSnake}_usecase.dart'),
          );

          if (useCaseFile.existsSync()) {
            final content = await useCaseFile.readAsString();
            return _parseUseCaseFile(content, className, foundDomain);
          }
        }
      }
    }

    return null;
  }

  Map<String, dynamic> _parseUseCaseFile(
    String content,
    String className,
    String domain,
  ) {
    // Parse repository dependencies
    final repoMatches = RegExp(
      r'final\s+(\w+)Repository\s+(\w+)',
    ).allMatches(content);
    final repos = repoMatches
        .map((m) => m.group(1))
        .whereType<String>()
        .toList();

    // Parse service dependencies
    final serviceMatches = RegExp(
      r'final\s+(\w+)Service\s+(\w+)',
    ).allMatches(content);
    final services = serviceMatches
        .map((m) => m.group(1))
        .whereType<String>()
        .toList();

    // Parse composed usecases (for orchestrators)
    final usecaseMatches = RegExp(
      r'final\s+\w+UseCase\s+_(\w+)',
    ).allMatches(content);
    final composedUsecases = usecaseMatches
        .map((m) {
          final fieldName = m.group(1);
          if (fieldName == null) return null;
          // Convert field name to class name (e.g., _getLocale -> GetLocaleUseCase)
          final baseName = fieldName.startsWith('_')
              ? fieldName.substring(1)
              : fieldName;
          // Remove leading underscore and capitalize
          final classBase =
              baseName.substring(0, 1).toUpperCase() + baseName.substring(1);
          return classBase.endsWith('UseCase')
              ? classBase
              : '${classBase}UseCase';
        })
        .whereType<String>()
        .toList();

    // Check if it's an orchestrator (has composed usecases)
    final isOrchestrator =
        composedUsecases.isNotEmpty && repos.isEmpty && services.isEmpty;

    // Check if it's polymorphic (has variants)
    final polymorphicMatch = RegExp(r'sealed\s+class').hasMatch(content);

    return {
      'className': className,
      'repos': repos,
      'services': services,
      'usecases': composedUsecases,
      'domain': domain,
      'isOrchestrator': isOrchestrator,
      'isPolymorphic': polymorphicMatch,
      'isEntityBased': repos.isNotEmpty || services.isNotEmpty,
    };
  }

  GeneratorConfig _buildConfig(
    String name,
    Map<String, dynamic> analysis,
    ArgResults results,
  ) {
    final nameWithoutSuffix = name.replaceAll('UseCase', '');
    final useMock = results['use-mock'] == true;

    // Determine type from analysis
    String? repo;
    String? service;
    final usecases = <String>[];

    for (final r in analysis['repos'] as List<String>) {
      final repoName = '${r}Repository';
      if (repo == null) repo = repoName;
    }

    for (final s in analysis['services'] as List<String>) {
      final serviceName = '${s}Service';
      if (service == null) service = serviceName;
    }

    // If orchestrator, collect composed usecases
    if (analysis['isOrchestrator'] == true) {
      usecases.addAll(analysis['usecases'] as List<String>);
    }

    return GeneratorConfig(
      name: nameWithoutSuffix,
      domain: analysis['domain'] as String,
      generateDi: true,
      generateData: false,
      generateRepository: false,
      generateTest: false,
      useMockInDi: useMock,
      repo: repo,
      service: service,
      usecases: usecases,
    );
  }

  String _resolveOutputDir(String? output) {
    if (output != null && output.isNotEmpty) {
      return output;
    }

    // Try to find lib/src directory
    final possiblePaths = [
      'lib/src',
      path.join('..', 'lib', 'src'),
      path.join('..', '..', 'lib', 'src'),
    ];

    for (final p in possiblePaths) {
      if (Directory(p).existsSync()) {
        return p;
      }
    }

    // Default fallback
    return 'lib/src';
  }

  ArgParser _buildArgParser() {
    return ArgParser()
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory (default: lib/src)',
      )
      ..addOption(
        'domain',
        abbr: 'd',
        help: 'Domain folder where usecase is located (default: general)',
        defaultsTo: 'general',
      )
      ..addFlag(
        'dry-run',
        help: 'Preview without writing files',
        negatable: false,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing DI files',
        negatable: false,
      )
      ..addFlag('verbose', abbr: 'v', help: 'Verbose output', negatable: false)
      ..addFlag(
        'use-mock',
        help: 'Use mock datasource in DI registration',
        negatable: false,
      );
  }

  void _printHelp() {
    print('''
Generate DI registrations for existing usecases

USAGE:
  zfa di <UseCaseName> [options]

ARGUMENTS:
  <UseCaseName>       Name of the usecase to register (e.g., CreateCustomer)

OPTIONS:
  -o, --output        Output directory (default: lib/src)
  -d, --domain        Domain folder where usecase is located (default: general)
  --dry-run           Preview without writing files
  -f, --force         Overwrite existing DI files
  -v, --verbose       Verbose output
  --use-mock          Use mock datasource in DI registration

EXAMPLES:
  zfa di CreateCustomer                        # Generate DI for CreateCustomerUseCase
  zfa di CreateCustomer --domain=customer      # Specify domain folder
  zfa di CreateCustomer --force                # Overwrite existing DI
  zfa di CreateCustomer --use-mock             # Use mock datasource

The command will:
  1. Find the usecase file in lib/src/domain/usecases/<domain>/
  2. Analyze its dependencies (repositories, services)
  3. Generate DI registration file
  4. Update the DI index files

Generated files:
  - lib/src/di/usecases/{usecase}_usecase_di.dart
  - lib/src/di/usecases/index.dart (updated)
  - lib/src/di/index.dart (updated)
''');
  }
}
