import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import '../models/generator_config.dart';
import '../generator/code_generator.dart';
import '../utils/logger.dart';

class GenerateCommand {
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      print('❌ Usage: zfa generate <Name> [options]');
      print('\nRun: zfa generate --help for more information');
      exit(1);
    }

    if (args[0] == '--help' || args[0] == '-h') {
      _printHelp();
      exit(0);
    }

    final name = args[0];
    if (name.startsWith('--')) {
      print('❌ Missing name');
      print('Usage: zfa generate <Name> [options]');
      exit(1);
    }

    final parser = _buildArgParser();
    final results = parser.parse(args.skip(1).toList());

    GeneratorConfig config;

    if (results['from-stdin'] == true) {
      final input = stdin.readLineSync() ?? '';
      final json = jsonDecode(input) as Map<String, dynamic>;
      config = GeneratorConfig.fromJson(json, name);
    } else if (results['from-json'] != null) {
      final file = File(results['from-json']);
      if (!file.existsSync()) {
        print('❌ JSON file not found: ${results['from-json']}');
        exit(1);
      }
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      config = GeneratorConfig.fromJson(json, name);
    } else {
      final methodsStr = results['methods'] as String?;
      final reposStr = results['repos'] as String?;
      config = GeneratorConfig(
        name: name,
        methods: methodsStr?.split(',').map((s) => s.trim()).toList() ?? [],
        repos: reposStr?.split(',').map((s) => s.trim()).toList() ?? [],
        generateRepository: results['repository'] == true,
        useCaseType: results['type'],
        paramsType: results['params'],
        returnsType: results['returns'],
        idField: results['id-field'] ?? 'id',
        idType: results['id-field-type'] ?? results['id-type'] ?? 'String',
        generateVpc: results['vpc'] == true || results['vpcs'] == true,
        generateView: results['view'] == true ||
            results['vpc'] == true ||
            results['vpcs'] == true,
        generatePresenter: results['presenter'] == true ||
            results['vpc'] == true ||
            results['vpcs'] == true ||
            results['pc'] == true ||
            results['pcs'] == true,
        generateController: results['controller'] == true ||
            results['vpc'] == true ||
            results['vpcs'] == true ||
            results['pc'] == true ||
            results['pcs'] == true,
        generateObserver: results['observer'] == true,
        generateData: results['data'] == true,
        generateDataSource: results['datasource'] == true,
        generateState: results['state'] == true ||
            results['vpcs'] == true ||
            results['pcs'] == true,
        generateInit: results['init'] == true,
        queryField: results['query-field'] ?? results['id-field'] ?? 'id',
        queryFieldType: results['query-field-type'],
        useMorphy: results['morphy'] == true,
        generateTest: results['test'] == true,
        subdirectory: results['subdirectory'],
        enableCache: results['cache'] == true,
        cachePolicy: results['cache-policy'] ?? 'daily',
        cacheStorage: results['cache-storage'] ??
            (results['cache'] == true ? 'hive' : null),
        ttlMinutes:
            results['ttl'] != null ? int.tryParse(results['ttl']) : null,
        generateMock: results['mock'] == true,
        generateMockDataOnly: results['mock-data-only'] == true,
        useMockInDi: results['use-mock'] == true,
        generateDi: results['di'] == true,
        diFramework: 'get_it',
      );
    }

    // Validate --id-field=null usage
    if (config.idField == 'null') {
      final invalidMethods = config.methods
          .where((method) => method == 'getList' || method == 'watchList')
          .toList();

      if (invalidMethods.isNotEmpty) {
        print(
            '❌ Error: --id-field=null can only be used with get and watch methods, not list methods.');
        print('   Invalid methods: ${invalidMethods.join(', ')}');
        print('   Use --id-field=null only with: get, watch');
        exit(1);
      }
    }

    final outputDir = results['output'] as String;
    final format = results['format'] as String;
    final dryRun = results['dry-run'] == true;
    final force = results['force'] == true;
    final verbose = results['verbose'] == true;
    final quiet = results['quiet'] == true;

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
    } else if (verbose && !quiet) {
      for (final file in result.files) {
        print('\n--- ${file.path} ---');
        print(file.content ?? '');
      }
      CliLogger.printResult(result);
    } else if (!quiet) {
      CliLogger.printResult(result);
    }

    exit(result.success ? 0 : 1);
  }

  ArgParser _buildArgParser() {
    return ArgParser()
      ..addOption('from-json', abbr: 'j', help: 'JSON configuration file')
      ..addFlag('from-stdin', help: 'Read JSON from stdin', defaultsTo: false)
      ..addOption('methods',
          abbr: 'm',
          help:
              'Comma-separated methods: get,getList,create,update,delete,watch,watchList')
      ..addOption('repos', help: 'Comma-separated repositories to inject')
      ..addFlag('repository',
          abbr: 'r', help: 'Generate repository interface', defaultsTo: false)
      ..addFlag('data',
          abbr: 'd',
          help: 'Generate data repository implementation + data source',
          defaultsTo: false)
      ..addOption('type',
          help: 'UseCase type: usecase,stream,background,completable',
          defaultsTo: 'usecase')
      ..addOption('params', help: 'Params type for custom usecase')
      ..addOption('returns', help: 'Return type for custom usecase')
      ..addFlag('vpc',
          help: 'Generate View + Presenter + Controller', defaultsTo: false)
      ..addFlag('vpcs',
          help: 'Generate View + Presenter + Controller + State',
          defaultsTo: false)
      ..addFlag('pc',
          help: 'Generate Presenter + Controller only', defaultsTo: false)
      ..addFlag('pcs',
          help: 'Generate Presenter + Controller + State', defaultsTo: false)
      ..addFlag('view', help: 'Generate View only', defaultsTo: false)
      ..addFlag('presenter', help: 'Generate Presenter only', defaultsTo: false)
      ..addFlag('controller',
          help: 'Generate Controller only', defaultsTo: false)
      ..addFlag('observer', help: 'Generate Observer', defaultsTo: false)
      ..addFlag('test',
          abbr: 't', help: 'Generate Unit Tests', defaultsTo: false)
      ..addFlag('datasource',
          help: 'Generate DataSource only', defaultsTo: false)
      ..addFlag('init',
          help: 'Generate initialize method for repository and datasource',
          defaultsTo: false)
      ..addOption('id-type',
          help: 'ID type for entity (deprecated, use --id-field-type)',
          defaultsTo: 'String')
      ..addOption('id-field',
          help: 'ID field name for update/delete (default: id)',
          defaultsTo: 'id')
      ..addOption('id-field-type',
          help: 'ID field type (default: String)', defaultsTo: 'String')
      ..addOption('query-field',
          help: 'Query field name for get/watch (default: matches --id-field)')
      ..addOption('query-field-type',
          help: 'Query field type (default: matches --id-type)')
      ..addFlag('morphy',
          help: 'Use Morphy-style typed patches (e.g. EntityPatch) for updates',
          defaultsTo: false)
      ..addFlag('state', help: 'Generate State object', defaultsTo: false)
      ..addFlag('cache',
          help: 'Enable caching with dual datasources (remote + local)',
          defaultsTo: false)
      ..addOption('cache-policy',
          help: 'Cache policy: daily, restart, ttl (default: daily)',
          defaultsTo: 'daily')
      ..addOption('cache-storage',
          help: 'Local storage hint: hive, sqlite, shared_preferences')
      ..addOption('ttl',
          help: 'TTL duration in minutes (default: 1440 = 24 hours)')
      ..addFlag('mock',
          help: 'Generate mock data source with sample data', defaultsTo: false)
      ..addFlag('mock-data-only',
          help: 'Generate only mock data file (no data source)',
          defaultsTo: false)
      ..addFlag('use-mock',
          help: 'Use mock datasource in DI (default: remote datasource)',
          defaultsTo: false)
      ..addFlag('di',
          help: 'Generate dependency injection files', defaultsTo: false)
      ..addOption('subdirectory',
          help: 'Subdirectory to organize files (e.g., products, orders)')
      ..addOption('output',
          abbr: 'o', help: 'Output directory', defaultsTo: 'lib/src')
      ..addOption('format',
          help: 'Output format: json,text', defaultsTo: 'text')
      ..addFlag('dry-run',
          help: 'Preview without writing files', defaultsTo: false)
      ..addFlag('force', help: 'Overwrite existing files', defaultsTo: false)
      ..addFlag('verbose', abbr: 'v', help: 'Verbose output', defaultsTo: false)
      ..addFlag('quiet', abbr: 'q', help: 'Minimal output', defaultsTo: false);
  }

  void _printHelp() {
    print('''
zfa generate - Generate Clean Architecture code

USAGE:
  zfa generate <Name> [options]

ENTITY-BASED GENERATION:
  --methods=<list>      Comma-separated: get,getList,create,update,delete,watch,watchList
  -r, --repository      Generate repository interface
  -d, --data            Generate data repository + data source
  --datasource          Generate data source only
  --init                Generate initialize method for repository and datasource
  --id-field=<name>     ID field name (default: id)
  --id-field-type=<t>   ID field type (default: String)
  --query-field=<name>  Query field name for get/watch (default: id)
  --query-field-type=<t> Query field type (default: same as id-field-type)
  --morphy             Use Morphy-style typed patches (e.g. EntityPatch)

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

CUSTOM USECASE:
  --repos=<list>        Comma-separated repositories to inject
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
  --subdirectory=<dir>  Subdirectory to organize files (e.g., products, orders)
  -j, --from-json       JSON configuration file
  --from-stdin          Read JSON from stdin
  -o, --output          Output directory (default: lib/src)
  --format=json|text    Output format (default: text)
  --dry-run             Preview without writing files
  --force               Overwrite existing files
  -v, --verbose         Verbose output
  -q, --quiet           Minimal output

EXAMPLES:
  # Entity-based CRUD with VPC and State
  zfa generate Product --methods=get,getList,create,update,delete --repository --vpc --state

  # With data layer (repository impl + datasource)
  zfa generate Product --methods=get,getList,create,update,delete --repository --data

  # Stream usecases
  zfa generate Product --methods=watch,watchList --repository

  # Custom usecase with multiple repos
  zfa generate ProcessOrder --repos=OrderRepo,PaymentRepo --params=OrderRequest --returns=OrderResult

  # Background usecase
  zfa generate ProcessImages --type=background --params=ImageBatch --returns=ProcessedImage

  # From JSON
  zfa generate Product -j product.json

  # From stdin (AI-friendly)
  echo '{"name":"Product","methods":["get","getList"]}' | zfa generate Product --from-stdin --format=json
''');
  }
}
