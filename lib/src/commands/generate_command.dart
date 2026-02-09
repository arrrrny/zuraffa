import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../generator/code_generator.dart';
import '../utils/logger.dart';
import '../config/zfa_config.dart';

class GenerateCommand {
  Future<GeneratorResult> execute(
    List<String> args, {
    bool exitOnCompletion = true,
  }) async {
    if (args.isEmpty) {
      print('❌ Usage: zfa generate <Name> [options]');
      print('\nRun: zfa generate --help for more information');
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

    final name = args[0];
    if (name.startsWith('--')) {
      print('❌ Missing name');
      print('Usage: zfa generate <Name> [options]');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: ['Missing name'],
        nextSteps: [],
      );
    }

    final parser = _buildArgParser();
    final ArgResults results;
    try {
      results = parser.parse(args.skip(1).toList());
    } on FormatException catch (e) {
      print('❌ ${e.message}');
      print('\nRun: zfa generate --help for usage information');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: [e.message],
        nextSteps: [],
      );
    }

    final config = _buildConfig(name, results);
    _validateConfig(config, exitOnCompletion: exitOnCompletion);

    final outputDir = results['output'] as String;
    final format = results['format'] as String;
    final dryRun = results['dry-run'] == true;
    final force = results['force'] == true;
    final verbose = results['verbose'] == true;
    final quiet = results['quiet'] == true;
    final shouldBuild = results['build'] == true;
    final shouldFormat = results['dart-format'] == true;

    // Load config to check buildByDefault and formatByDefault
    final zfaConfig = ZfaConfig.load();
    final runBuild =
        shouldBuild ||
        (config.enableCache && (zfaConfig?.buildByDefault ?? false));
    final runFormat = shouldFormat || (zfaConfig?.formatByDefault ?? false);

    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final result = await generator.generate();

    if (format == 'json') {
      print(jsonEncode(result.toJson()));
    } else if (!result.success) {
      if (!quiet) {
        CliLogger.printResult(result);
      }
      if (exitOnCompletion) exit(1);
    } else if (verbose && !quiet) {
      for (final file in result.files) {
        print('\n--- ${file.path} ---');
        print(file.content ?? '');
      }
      CliLogger.printResult(result);
    } else if (!quiet) {
      CliLogger.printResult(result);
    }

    // Run build if requested and generation succeeded
    if (runBuild && result.success && !dryRun) {
      print('');
      print('🔨 Running build_runner...');
      await _runBuild();
    }

    // Run dart format if generation succeeded and requested
    if (runFormat && result.success && !dryRun) {
      print('');
      print('🎨 Formatting generated code...');
      await _runFormat(outputDir);
    }

    if (exitOnCompletion) exit(0);
    return result;
  }

  GeneratorConfig _buildConfig(String name, ArgResults results) {
    // Load ZFA config for defaults
    final zfaConfig = ZfaConfig.load() ?? const ZfaConfig();

    if (results['from-stdin'] == true) {
      final input = stdin.readLineSync() ?? '';
      final json = jsonDecode(input) as Map<String, dynamic>;
      return GeneratorConfig.fromJson(json, name);
    } else if (results['from-json'] != null) {
      final file = File(results['from-json']);
      if (!file.existsSync()) {
        print('❌ JSON file not found: ${results['from-json']}');
        exit(1);
      }
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return GeneratorConfig.fromJson(json, name);
    } else {
      final methodsStr = results['methods'] as String?;
      final usecasesStr = results['usecases'] as String?;
      final variantsStr = results['variants'] as String?;

      // Apply config defaults for entity-based operations
      final isEntityBased = methodsStr != null && methodsStr.isNotEmpty;
      final shouldGenerateGql =
          results['gql'] == true || (isEntityBased && zfaConfig.gqlByDefault);
      // Only apply appendByDefault for custom UseCases, not entity-based
      final shouldAppend =
          results['append'] == true ||
          (!isEntityBased && zfaConfig.appendByDefault);
      final useZorhpy = results['zorphy'] || zfaConfig.zorphyByDefault;
      final idFieldType =
          results['id-field'] == 'null' || results['id-field-type'] == 'null'
          ? 'NoParams'
          : results['id-field-type'] ?? results['id-type'] ?? 'String';

      return GeneratorConfig(
        name: name,
        methods: methodsStr?.split(',').map((s) => s.trim()).toList() ?? [],
        repo: results['repo'],
        service: results['service'],
        usecases: usecasesStr?.split(',').map((s) => s.trim()).toList() ?? [],
        variants: variantsStr?.split(',').map((s) => s.trim()).toList() ?? [],
        domain: results['domain'],
        repoMethod: results['method'],
        serviceMethod:
            results['service-method'] ??
            (results['service'] != null ? results['method'] : null),
        appendToExisting: shouldAppend,
        generateRepository: true,
        useCaseType: results['type'],
        paramsType: results['params'],
        returnsType: results['returns'],
        idField: results['id-field'] ?? 'id',
        idType: idFieldType,
        generateVpc: results['vpc'] == true || results['vpcs'] == true,
        generateView:
            results['view'] == true ||
            results['vpc'] == true ||
            results['vpcs'] == true,
        generatePresenter:
            results['presenter'] == true ||
            results['vpc'] == true ||
            results['vpcs'] == true ||
            results['pc'] == true ||
            results['pcs'] == true,
        generateController:
            results['controller'] == true ||
            results['vpc'] == true ||
            results['vpcs'] == true ||
            results['pc'] == true ||
            results['pcs'] == true,
        generateObserver: results['observer'] == true,
        generateData: results['data'] == true,
        generateDataSource: results['datasource'] == true,
        generateState:
            results['state'] == true ||
            results['vpcs'] == true ||
            results['pcs'] == true,
        generateInit: results['init'] == true,
        queryField: results['query-field'] ?? results['id-field'] ?? 'id',
        queryFieldType: results['query-field-type'],
        useZorphy: useZorhpy,
        generateTest: results['test'] == true,
        enableCache: results['cache'] == true,
        cachePolicy: results['cache-policy'] ?? 'daily',
        cacheStorage:
            results['cache-storage'] ??
            (results['cache'] == true ? 'hive' : null),
        ttlMinutes: results['ttl'] != null
            ? int.tryParse(results['ttl'])
            : null,
        generateMock: results['mock'] == true,
        generateMockDataOnly: results['mock-data-only'] == true,
        useMockInDi: results['use-mock'] == true,
        generateDi: results['di'] == true,
        diFramework: 'get_it',
        generateGql: shouldGenerateGql,
        gqlReturns: results['gql-returns'],
        gqlType: results['gql-type'],
        gqlInputType: results['gql-input-type'],
        gqlInputName: results['gql-input-name'],
        gqlName: results['gql-name'],
      );
    }
  }

  void _validateConfig(GeneratorConfig config, {bool exitOnCompletion = true}) {
    // Rule 1: Entity-based cannot have --domain, --repo, --service, --usecases, --variants
    if (config.isEntityBased) {
      if (config.domain != null) {
        print('❌ Error: --domain cannot be used with entity-based generation');
        print('   Entity-based UseCases auto-use entity name as domain');
        if (exitOnCompletion) exit(1);
        throw ArgumentError('Invalid config: --domain with entity-based');
      }
      if (config.repo != null) {
        print('❌ Error: --repo cannot be used with entity-based generation');
        print('   Entity-based UseCases auto-inject ${config.name}Repository');
        if (exitOnCompletion) exit(1);
        throw ArgumentError('Invalid config: --repo with entity-based');
      }
      if (config.service != null) {
        print('❌ Error: --service cannot be used with entity-based generation');
        print('   Entity-based UseCases auto-inject ${config.name}Repository');
        if (exitOnCompletion) exit(1);
        throw ArgumentError('Invalid config: --service with entity-based');
      }
      if (config.usecases.isNotEmpty) {
        print(
          '❌ Error: --usecases cannot be used with entity-based generation',
        );
        if (exitOnCompletion) exit(1);
        throw ArgumentError('Invalid config: --usecases with entity-based');
      }
      if (config.variants.isNotEmpty) {
        print(
          '❌ Error: --variants cannot be used with entity-based generation',
        );
        if (exitOnCompletion) exit(1);
        throw ArgumentError('Invalid config: --variants with entity-based');
      }
    }

    // Rule 2: Custom UseCases require --domain
    if (config.isCustomUseCase && config.domain == null) {
      print('❌ Error: --domain is required for custom UseCases');
      print('');
      print('Usage:');
      print(
        '  zfa generate ${config.name} --domain=<domain> --repo=<Repository> --params=<Type> --returns=<Type>',
      );
      print('  or');
      print(
        '  zfa generate ${config.name} --domain=<domain> --service=<Service> --params=<Type> --returns=<Type>',
      );
      print('');
      print('Example:');
      print(
        '  zfa generate SearchProduct --domain=search --repo=Product --params=Query --returns=List<Product>',
      );
      print(
        '  zfa generate ProcessPayment --domain=payment --service=Payment --params=PaymentRequest --returns=PaymentResult',
      );
      if (exitOnCompletion) exit(1);
      throw ArgumentError('Invalid config: missing --domain');
    }

    // Rule 3: Orchestrator (--usecases) cannot have --repo or --service
    if (config.isOrchestrator &&
        (config.repo != null || config.service != null)) {
      print('❌ Error: Cannot use --repo or --service with --usecases');
      print(
        '   Orchestrators compose UseCases, they don\'t use repositories/services directly',
      );
      print('');
      print('Either:');
      print('  - Use --repo or --service for dependency-based UseCase');
      print('  - Use --usecases for orchestrator UseCase');
      if (exitOnCompletion) exit(1);
      throw ArgumentError(
        'Invalid config: --usecases with --repo or --service',
      );
    }

    // Rule 4: Custom non-orchestrator requires --repo OR --service (except background)
    // Also: --repo and --service are mutually exclusive
    if (config.isCustomUseCase &&
        !config.isOrchestrator &&
        config.useCaseType != 'background') {
      if (config.repo != null && config.service != null) {
        print('❌ Error: Cannot use both --repo and --service');
        print(
          '   Use --repo for repository injection OR --service for service injection',
        );
        if (exitOnCompletion) exit(1);
        throw ArgumentError('Invalid config: both --repo and --service');
      }
      if (config.repo == null && config.service == null) {
        print('❌ Error: --repo or --service is required for custom UseCases');
        print('   (except orchestrators with --usecases or --type=background)');
        print('');
        print('Usage:');
        print(
          '  zfa generate ${config.name} --domain=${config.domain ?? 'domain'} --repo=<Repository> --params=<Type> --returns=<Type>',
        );
        print(
          '  zfa generate ${config.name} --domain=${config.domain ?? 'domain'} --service=<Service> --params=<Type> --returns=<Type>',
        );
        if (exitOnCompletion) exit(1);
        throw ArgumentError('Invalid config: missing --repo or --service');
      }
    }

    // Rule 5: Orchestrator requires --params and --returns
    if (config.isOrchestrator) {
      if (config.paramsType == null) {
        print('❌ Error: --params is required for orchestrator UseCases');
        exit(1);
      }
      if (config.returnsType == null) {
        print('❌ Error: --returns is required for orchestrator UseCases');
        exit(1);
      }
    }

    // Rule 5b: Polymorphic requires --params and --returns
    if (config.isPolymorphic) {
      if (config.paramsType == null) {
        print('❌ Error: --params is required for polymorphic UseCases');
        print('');
        print('Usage:');
        print(
          '  zfa generate ${config.name} --variants=A,B,C --domain=${config.domain ?? 'domain'} --repo=<Repository> --params=<Type> --returns=<Type>',
        );
        exit(1);
      }
      if (config.returnsType == null) {
        print('❌ Error: --returns is required for polymorphic UseCases');
        print('');
        print('Usage:');
        print(
          '  zfa generate ${config.name} --variants=A,B,C --domain=${config.domain ?? 'domain'} --repo=<Repository> --params=<Type> --returns=<Type>',
        );
        exit(1);
      }
    }

    // Rule 6: Validate --id-field=null usage
    if (config.idField == 'null') {
      final invalidMethods = config.methods
          .where((method) => method == 'getList' || method == 'watchList')
          .toList();

      if (invalidMethods.isNotEmpty) {
        print(
          '❌ Error: --id-field=null can only be used with get and watch methods, not list methods.',
        );
        print('   Invalid methods: ${invalidMethods.join(', ')}');
        print('   Use --id-field=null only with: get, watch');
        exit(1);
      }
    }

    // Rule 7: Validate UseCase type
    final validTypes = [
      'usecase',
      'stream',
      'background',
      'completable',
      'sync',
    ];
    if (!validTypes.contains(config.useCaseType)) {
      print('❌ Error: Invalid --type: ${config.useCaseType}');
      print('   Valid types: ${validTypes.join(', ')}');
      exit(1);
    }

    // Rule 8: GraphQL validation
    if (config.generateGql) {
      // For custom UseCases, --gql-type is mandatory
      if (config.isCustomUseCase && config.gqlType == null) {
        print(
          '❌ Error: --gql-type is required for custom UseCases when using --gql',
        );
        print('   Valid types: query, mutation, subscription');
        print('');
        print('Example:');
        print(
          '  zfa generate ${config.name} --domain=${config.domain ?? 'domain'} --service=Service --gql --gql-type=mutation',
        );
        exit(1);
      }

      // Validate gql-type values
      if (config.gqlType != null &&
          !['query', 'mutation', 'subscription'].contains(config.gqlType)) {
        print('❌ Error: Invalid --gql-type "${config.gqlType}"');
        print('   Valid types: query, mutation, subscription');
        exit(1);
      }
    }
  }

  ArgParser _buildArgParser() {
    return ArgParser()
      ..addOption('from-json', abbr: 'j', help: 'JSON configuration file')
      ..addFlag('from-stdin', help: 'Read JSON from stdin', defaultsTo: false)
      ..addOption(
        'methods',
        abbr: 'm',
        help:
            'Comma-separated methods: get,getList,create,update,delete,watch,watchList',
      )
      ..addOption('repo', help: 'Repository to inject (single)')
      ..addOption('service', help: 'Service to inject (alternative to --repo)')
      ..addOption(
        'usecases',
        help: 'Comma-separated UseCases to compose (orchestrator pattern)',
      )
      ..addOption(
        'variants',
        help: 'Comma-separated variants for polymorphic pattern',
      )
      ..addOption(
        'domain',
        help: 'Domain folder for custom UseCases (required for custom)',
      )
      ..addOption(
        'method',
        help: 'Dependency method name (default: auto from UseCase name)',
      )
      ..addOption(
        'service-method',
        help: 'Service method name (default: auto from UseCase name)',
      )
      ..addFlag(
        'append',
        help: 'Append method to existing repository or service',
      )
      ..addFlag(
        'data',
        abbr: 'd',
        help: 'Generate data repository implementation + data source',
        defaultsTo: false,
      )
      ..addOption(
        'type',
        help: 'UseCase type: usecase,stream,background,completable,sync',
        defaultsTo: 'usecase',
      )
      ..addOption('params', help: 'Params type for custom usecase')
      ..addOption('returns', help: 'Return type for custom usecase')
      ..addFlag(
        'vpc',
        help: 'Generate View + Presenter + Controller',
        defaultsTo: false,
      )
      ..addFlag(
        'vpcs',
        help: 'Generate View + Presenter + Controller + State',
        defaultsTo: false,
      )
      ..addFlag(
        'pc',
        help: 'Generate Presenter + Controller only',
        defaultsTo: false,
      )
      ..addFlag(
        'pcs',
        help: 'Generate Presenter + Controller + State',
        defaultsTo: false,
      )
      ..addFlag('view', help: 'Generate View only', defaultsTo: false)
      ..addFlag('presenter', help: 'Generate Presenter only', defaultsTo: false)
      ..addFlag(
        'controller',
        help: 'Generate Controller only',
        defaultsTo: false,
      )
      ..addFlag('observer', help: 'Generate Observer', defaultsTo: false)
      ..addFlag(
        'test',
        abbr: 't',
        help: 'Generate Unit Tests',
        defaultsTo: false,
      )
      ..addFlag(
        'datasource',
        help: 'Generate DataSource only',
        defaultsTo: false,
      )
      ..addFlag(
        'init',
        help: 'Generate initialize method for repository and datasource',
        defaultsTo: false,
      )
      ..addOption(
        'id-type',
        help: 'ID type for entity (deprecated, use --id-field-type)',
        defaultsTo: 'String',
      )
      ..addOption(
        'id-field',
        help: 'ID field name for update/delete (default: id)',
        defaultsTo: 'id',
      )
      ..addOption(
        'id-field-type',
        help: 'ID field type (default: String)',
        defaultsTo: 'String',
      )
      ..addOption(
        'query-field',
        help: 'Query field name for get/watch (default: matches --id-field)',
      )
      ..addOption(
        'query-field-type',
        help: 'Query field type (default: matches --id-type)',
      )
      ..addFlag(
        'zorphy',
        help:
            'Use Zorphy-style typed patches (Zorphy generates patch() methods) (e.g. EntityPatch) for updates',
        defaultsTo: false,
      )
      ..addFlag('state', help: 'Generate State object', defaultsTo: false)
      ..addFlag(
        'cache',
        help: 'Enable caching with dual datasources (remote + local)',
        defaultsTo: false,
      )
      ..addOption(
        'cache-policy',
        help: 'Cache policy: daily, restart, ttl (default: daily)',
        defaultsTo: 'daily',
      )
      ..addOption(
        'cache-storage',
        help: 'Local storage hint: hive, sqlite, shared_preferences',
      )
      ..addOption(
        'ttl',
        help: 'TTL duration in minutes (default: 1440 = 24 hours)',
      )
      ..addFlag(
        'mock',
        help: 'Generate mock data source with sample data',
        defaultsTo: false,
      )
      ..addFlag(
        'mock-data-only',
        help: 'Generate only mock data file (no data source)',
        defaultsTo: false,
      )
      ..addFlag(
        'use-mock',
        help: 'Use mock datasource in DI (default: remote datasource)',
        defaultsTo: false,
      )
      ..addFlag(
        'di',
        help: 'Generate dependency injection files',
        defaultsTo: false,
      )
      ..addFlag(
        'gql',
        help: 'Generate GraphQL queries and mutations',
        defaultsTo: false,
      )
      ..addOption(
        'gql-returns',
        help: 'GraphQL return fields (comma-separated, supports dot notation)',
      )
      ..addOption(
        'gql-type',
        help: 'GraphQL operation type: query, mutation, subscription',
      )
      ..addOption(
        'gql-input-type',
        help: 'GraphQL input type name (e.g., CategoryFilter)',
      )
      ..addOption(
        'gql-input-name',
        help: 'GraphQL input parameter name (e.g., options)',
      )
      ..addOption(
        'gql-name',
        help: 'GraphQL operation name (e.g., DetectCategory)',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory',
        defaultsTo: 'lib/src',
      )
      ..addOption(
        'format',
        help: 'Output format: json,text',
        defaultsTo: 'text',
      )
      ..addFlag(
        'dry-run',
        help: 'Preview without writing files',
        defaultsTo: false,
      )
      ..addFlag('force', help: 'Overwrite existing files', defaultsTo: false)
      ..addFlag('verbose', abbr: 'v', help: 'Verbose output', defaultsTo: false)
      ..addFlag('quiet', abbr: 'q', help: 'Minimal output', defaultsTo: false)
      ..addFlag(
        'build',
        help:
            'Run build_runner after generation (auto for --cache if buildByDefault=true)',
        defaultsTo: false,
      )
      ..addFlag(
        'dart-format',
        help: 'Run dart format after generation (auto if formatByDefault=true)',
        defaultsTo: false,
      );
  }

  Future<void> _runBuild() async {
    final process = await Process.start('dart', [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ], mode: ProcessStartMode.inheritStdio);

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      print('\n❌ build_runner exited with code $exitCode');
      exit(exitCode);
    }

    print('\n✅ Build completed successfully!');
  }

  Future<void> _runFormat(String outputDir) async {
    final process = await Process.start('dart', [
      'format',
      outputDir,
    ], mode: ProcessStartMode.inheritStdio);

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      print('\n⚠️  dart format exited with code $exitCode (non-critical)');
      return;
    }

    print('✅ Code formatted successfully!');
  }

  void _printHelp() {
    print('''
zfa generate - Generate Clean Architecture code

USAGE:
  zfa generate <Name> [options]

ENTITY-BASED GENERATION:
  --methods=<list>      Comma-separated: get,getList,create,update,delete,watch,watchList
  -d, --data            Generate data repository + data source
  --datasource          Generate data source only
  --init                Generate initialize method for repository and datasource
  --id-field=<name>     ID field name (default: id)
  --id-field-type=<t>   ID field type (default: String)
  --query-field=<name>  Query field name for get/watch (default: id)
  --query-field-type=<t> Query field type (default: same as id-field-type)
  --zorphy             Use Zorphy-style typed patches (alias: --zorphy)

CACHING:
  --cache              Enable caching with dual datasources (remote + local)
  --cache-policy=<p>   Cache policy: daily, restart, ttl (default: daily)
  --cache-storage=<s>  Local storage hint: hive, sqlite, shared_preferences
  --ttl=<minutes>      TTL duration in minutes (default: 1440 = 24 hours)

MOCK DATA:
  --mock               Generate mock data source with sample data
  --mock-data-only     Generate only mock data file (no data source)

DEPENDENCY INJECTION:
  --di                 Generate DI registration files (get_it)

GRAPHQL:
  --gql                Generate GraphQL queries and mutations
  --gql-returns=<list> GraphQL return fields (comma-separated, supports dot notation)
  --gql-type=<type>    GraphQL operation type: query, mutation, subscription
  --gql-input-type=<t> GraphQL input type name (e.g., CategoryFilter)
  --gql-input-name=<n> GraphQL input parameter name (e.g., options)
  --gql-name=<name>    GraphQL operation name (e.g., DetectCategory)

CUSTOM USECASE:
  --repo=<name>         Repository to inject (single, enforces SRP)
  --service=<name>      Service to inject (alternative to --repo)
  --domain=<name>       Domain folder (required for custom UseCases)
  --method=<name>       Dependency method name (default: auto from UseCase name)
  --service-method=<n>  Service method name (default: auto from UseCase name)
  --append              Append to existing repository/service
  --usecases=<list>     Orchestrator: compose UseCases (comma-separated)
  --variants=<list>     Polymorphic: generate variants (comma-separated)
  --type=<type>         usecase|stream|background|completable (default: usecase)
  --params=<type>       Params type (default: NoParams)
  --returns=<type>      Return type (default: void)

VPC LAYER:
  --vpc                 Generate View + Presenter + Controller
  --vpcs                Generate View + Presenter + Controller + State
  --pc                  Generate Presenter + Controller only (preserve View)
  --pcs                 Generate Presenter + Controller + State (preserve View)
  --view                Generate View only
  --presenter           Generate Presenter only
  --controller          Generate Controller only
  --state               Generate State object with granular loading states
  --observer            Generate Observer class
  -t, --test            Generate Unit Tests

 INPUT/OUTPUT:
   -j, --from-json       JSON configuration file
   --from-stdin          Read JSON from stdin
   -o, --output          Output directory (default: lib/src)
   --format=json|text    Output format (default: text)
   --dart-format         Run dart format after generation (auto if formatByDefault=true)
   --dry-run             Preview without writing files
   --force               Overwrite existing files
   -v, --verbose         Verbose output
   -q, --quiet           Minimal output

EXAMPLES:
  # Entity-based CRUD with VPC and State
  zfa generate Product --methods=get,getList,create,update,delete --vpc --state

  # With data layer (repository impl + datasource)
  zfa generate Product --methods=get,getList,create,update,delete --data

  # Stream usecases
  zfa generate Product --methods=watch,watchList

  # Custom usecase with repository
  zfa generate SearchProduct --domain=search --repo=Product --params=Query --returns=List<Product>

  # Custom usecase with service
  zfa generate ProcessPayment --domain=payment --service=Payment --params=PaymentRequest --returns=PaymentResult

  # Stream usecase with service
  zfa generate WatchPrices --domain=pricing --service=PriceStream --params=ProductId --returns=Price --type=stream

  # Append method to existing repository
  zfa generate WatchProduct --domain=product --repo=Product --params=String --returns=Product --type=stream --append

  # Background usecase
  zfa generate ProcessImages --type=background --params=ImageBatch --returns=ProcessedImage --domain=processing

  # From JSON
  zfa generate Product -j product.json

  # From stdin (AI-friendly)
  echo '{"name":"Product","methods":["get","getList"]}' | zfa generate Product --from-stdin --format=json
''');
  }
}
