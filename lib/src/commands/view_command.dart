import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../generator/code_generator.dart';
import '../utils/logger.dart';

class ViewCommand {
  Future<GeneratorResult> execute(
    List<String> args, {
    bool exitOnCompletion = true,
  }) async {
    if (args.isEmpty) {
      print(
        '❌ Usage: zfa view <ViewName> --domain=<folder> --presenter=<PresenterName> [options]',
      );
      print('\nRun: zfa view --help for more information');
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
      print('❌ Missing view name');
      print(
        'Usage: zfa view <ViewName> --domain=<folder> --presenter=<PresenterName>',
      );
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: ['Missing view name'],
        nextSteps: [],
      );
    }

    final parser = _buildArgParser();
    final ArgResults results;
    try {
      results = parser.parse(args.skip(1).toList());
    } on FormatException catch (e) {
      print('❌ ${e.message}');
      print('\nRun: zfa view --help for usage information');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: [e.message],
        nextSteps: [],
      );
    }

    final outputDir = _resolveOutputDir(results['output'] as String);
    final dryRun = results['dry-run'] == true;
    final force = results['force'] == true;
    final verbose = results['verbose'] == true;
    final quiet = results['quiet'] == true;

    final domain = results['domain'];
    final presenter = results['presenter'];
    final controller = results['controller'];
    final stateClass = results['state-class'];

    if (domain == null) {
      print('❌ Error: --domain is required');
      print('   Specifies the folder where the view will be placed.');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: name,
        success: false,
        files: [],
        errors: ['Missing --domain'],
        nextSteps: [],
      );
    }

    if (presenter == null) {
      print('❌ Error: --presenter is required');
      print('   Specifies the existing presenter to connect to.');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: name,
        success: false,
        files: [],
        errors: ['Missing --presenter'],
        nextSteps: [],
      );
    }

    final config = GeneratorConfig(
      name: name,
      domain: domain,
      customPresenterName: presenter,
      customControllerName:
          controller ?? presenter.replaceAll('Presenter', 'Controller'),
      customStateName:
          stateClass ??
          (results['state'] == true
              ? '${presenter.replaceAll('Presenter', 'State')}'
              : null),
      generateView: true,
      generateState: results['state'] == true,
    );

    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final result = await generator.generate();

    if (!result.success) {
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

    if (exitOnCompletion) exit(0);
    return result;
  }

  String _resolveOutputDir(String outputDir) {
    if (path.isAbsolute(outputDir)) {
      return outputDir;
    }
    final envPwd = Platform.environment['PWD'];
    if (envPwd != null && envPwd.isNotEmpty) {
      final envDir = Directory(envPwd);
      if (envDir.existsSync()) {
        return path.normalize(path.join(envPwd, outputDir));
      }
    }
    return path.normalize(path.join(Directory.current.path, outputDir));
  }

  ArgParser _buildArgParser() {
    return ArgParser()
      ..addOption(
        'domain',
        abbr: 'd',
        help: 'Target folder for the view (required)',
      )
      ..addOption(
        'presenter',
        abbr: 'p',
        help: 'Existing presenter name to connect to (required)',
      )
      ..addOption(
        'controller',
        abbr: 'c',
        help: 'Existing controller name (default: <Presenter>Controller)',
      )
      ..addOption(
        'state-class',
        abbr: 's',
        help: 'Existing state class name (default: <Presenter>State)',
      )
      ..addFlag('state', help: 'Use state with the view', defaultsTo: false)
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory',
        defaultsTo: 'lib/src',
      )
      ..addFlag(
        'dry-run',
        help: 'Preview without writing files',
        defaultsTo: false,
      )
      ..addFlag('force', help: 'Overwrite existing files', defaultsTo: false)
      ..addFlag('verbose', abbr: 'v', help: 'Verbose output', defaultsTo: false)
      ..addFlag('quiet', abbr: 'q', help: 'Minimal output', defaultsTo: false);
  }

  void _printHelp() {
    print('''
zfa view - Generate an additional view for existing VPC

USAGE:
  zfa view <ViewName> --domain=<folder> --presenter=<PresenterName> [options]

DESCRIPTION:
  Generates a new view widget that connects to an existing presenter/controller.
  Useful for creating multiple views for the same business logic.

REQUIRED:
  --domain=<folder>      Target folder where view will be placed
  --presenter=<name>     Existing presenter name to connect to

OPTIONS:
  -c, --controller=<n>   Controller name (default: <Presenter>Controller)
  -s, --state-class=<n>  State class name (default: <Presenter>State)
  --state                Enable state usage in the view
  -o, --output           Output directory (default: lib/src)
  --dry-run              Preview without writing files
  --force                Overwrite existing files
  -v, --verbose          Verbose output
  -q, --quiet            Minimal output

EXAMPLES:
  # Add PaymentView to checkout folder using CheckoutPresenter
  zfa view Payment --domain=checkout --presenter=CheckoutPresenter

  # With explicit controller name
  zfa view Payment --domain=checkout --presenter=CheckoutPresenter --controller=CheckoutController

  # With state
  zfa view Payment --domain=checkout --presenter=CheckoutPresenter --state

  # Preview without writing
  zfa view Payment --domain=checkout --presenter=CheckoutPresenter --dry-run
''');
  }
}
