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
        idType: results['id-type'],
        generateVpc: results['vpc'] == true,
        generateView: results['view'] == true,
        generatePresenter: results['presenter'] == true,
        generateController: results['controller'] == true,
        generateObserver: results['observer'] == true,
        generateData: results['data'] == true,
        generateDataSource: results['datasource'] == true,
        generateState: results['state'] == true,
      );
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
      ..addOption('id-type', help: 'ID type for entity', defaultsTo: 'String')
      ..addFlag('vpc',
          help: 'Generate View + Presenter + Controller', defaultsTo: false)
      ..addFlag('view', help: 'Generate View only', defaultsTo: false)
      ..addFlag('presenter', help: 'Generate Presenter only', defaultsTo: false)
      ..addFlag('controller',
          help: 'Generate Controller only', defaultsTo: false)
      ..addFlag('observer', help: 'Generate Observer', defaultsTo: false)
      ..addFlag('datasource',
          help: 'Generate DataSource only', defaultsTo: false)
      ..addFlag('state', help: 'Generate State object', defaultsTo: false)
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
  --id-type=<type>      ID type for entity (default: String)

CUSTOM USECASE:
  --repos=<list>        Comma-separated repositories to inject
  --type=<type>         usecase|stream|background|completable (default: usecase)
  --params=<type>       Params type (default: NoParams)
  --returns=<type>      Return type (default: void)

VPC LAYER:
  --vpc                 Generate View + Presenter + Controller
  --view                Generate View only
  --presenter           Generate Presenter only
  --controller          Generate Controller only
  --state               Generate State object with granular loading states
  --observer            Generate Observer class

INPUT/OUTPUT:
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
