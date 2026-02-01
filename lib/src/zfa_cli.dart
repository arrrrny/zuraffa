import 'dart:io';
import 'commands/generate_command.dart';
import 'commands/schema_command.dart';
import 'commands/validate_command.dart';
import 'commands/create_command.dart';
import 'commands/initialize_command.dart';

const version = '1.11.0';

Future<void> run(List<String> args) async {
  if (args.isEmpty) {
    _printHelp();
    exit(0);
  }

  final command = args[0];

  try {
    switch (command) {
      case 'generate':
        await GenerateCommand().execute(args.skip(1).toList());
        break;
      case 'schema':
        SchemaCommand().execute();
        break;
      case 'validate':
        await ValidateCommand().execute(args.skip(1).toList());
        break;
      case 'create':
        await CreateCommand().execute(args.skip(1).toList());
        break;
      case 'initialize':
      case 'init':
        await InitializeCommand().execute(args.skip(1).toList());
        break;
      case 'help':
      case '--help':
      case '-h':
        _printHelp();
        break;
      case 'version':
      case '--version':
      case '-v':
        print('zfa v$version');
        print('Zuraffa Code Generator');
        break;
      default:
        print('❌ Unknown command: $command\n');
        _printHelp();
        exit(1);
    }
  } catch (e, stack) {
    print('❌ Error: $e');
    if (args.contains('--verbose') || args.contains('-v')) {
      print('\nStack trace:\n$stack');
    }
    exit(1);
  }
}

void _printHelp() {
  print('''
zfa - Zuraffa Code Generator

USAGE:
  zfa <command> [options]

COMMANDS:
  generate <Name>     Generate code for an entity or custom usecase
  initialize          Initialize a test entity to quickly try out Zuraffa
  schema              Output JSON schema for configuration
  validate <file>     Validate JSON configuration file
  create              Create architecture folders or pages
  help                Show this help message
  version             Show version

EXAMPLES:
  zfa initialize                          # Create sample Product entity
  zfa generate Product --methods=get,getAll,create --repository --vpc
  zfa generate ProcessOrder --repos=OrderRepo,PaymentRepo --params=OrderRequest --returns=OrderResult
  echo '{"name":"Product","methods":["get","getAll"]}' | zfa generate Product --from-stdin
  zfa create
  zfa create --page user_profile

Run 'zfa initialize --help' for more details on the initialize command.
Run 'zfa generate --help' for more details on the generate command.
Run 'zfa create --help' for more details on the create command.
''');
}
