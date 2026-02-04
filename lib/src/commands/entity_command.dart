import 'dart:io';

/// Entity Command - Delegates to Zorphy CLI for entity generation
///
/// This command provides a convenient wrapper around Zorphy's CLI,
/// allowing users to create entities, enums, and manage them through
/// the zfa CLI.
class EntityCommand {
  /// Execute the entity command by delegating to zorphy CLI
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      _printHelp();
      exit(0);
    }

    final subCommand = args[0];
    final subArgs = args.skip(1).toList();

    try {
      await _executeZorphy(subCommand, subArgs);
    } catch (e) {
      print('❌ Error executing entity command: $e');
      exit(1);
    }
  }

  /// Execute zorphy CLI with the given command and arguments
  Future<void> _executeZorphy(String command, List<String> args) async {
    // Check if we're in a Dart/Flutter project
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('❌ Error: pubspec.yaml not found in current directory.');
      print('   Please run this command from your Flutter/Dart project root.');
      exit(1);
    }

    // Build the zorphy CLI command
    final zorphyArgs = [command, ...args];

    print('🦒 Running Zorphy: zorphy_cli ${zorphyArgs.join(' ')}');
    print('   (Zorphy is bundled with ZFA - no setup required!)');
    print('');

    // Run zorphy CLI as a subprocess using the bundled version
    final process = await Process.start('dart', [
      'run',
      'zorphy:zorphy_cli',
      ...zorphyArgs,
    ], mode: ProcessStartMode.inheritStdio);

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      print('\n❌ Zorphy CLI exited with code $exitCode');
      exit(exitCode);
    }

    print('\n✅ Entity command completed successfully!');
  }

  /// Print help for the entity command
  void _printHelp() {
    print('''
zfa entity - Zorphy Entity Generation Commands

USAGE:
  zfa entity <subcommand> [options]

NOTE:
  Zorphy is bundled with ZFA - no additional installation needed!

SUBCOMMANDS:
  create      Create a new Zorphy entity with fields
  new         Quick-create a simple entity (basic defaults)
  enum        Create a new Zorphy enum
  add-field   Add field(s) to an existing entity
  from-json   Create entity/ies from JSON file
  list        List all Zorphy entities
  help        Show this help message

CREATE COMMAND:
  zfa entity create [options]
  Options:
    -n, --name              Entity name (required)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --json                  Enable JSON serialization (default: true)
    --copywith-fn           Enable function-based copyWith (default: false)
    --compare               Enable compareTo (default: true)
    --sealed                Create sealed class (default: false)
    --non-sealed            Create non-sealed class (default: false)
    -f, --fields            Interactive field prompts (default: true)
    --field                 Add fields directly ("name:type" or "name:type?")
    --extends               Interface to extend
    --subtype               Explicit subtypes

ENUM COMMAND:
  zfa entity enum [options]
  Options:
    -n, --name              Enum name (required)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --value                 Enum values (comma-separated)

NEW COMMAND:
  zfa entity new [options]
  Options:
    -n, --name              Entity name (required)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --json                  Enable JSON (default: true)

ADD-FIELD COMMAND:
  zfa entity add-field [options]
  Options:
    -n, --name              Entity name (required)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --field                 Fields to add ("name:type" or "name:type?")

FROM-JSON COMMAND:
  zfa entity from-json <file.json> [options]
  Options:
    --name                  Entity name (inferred from file if not provided)
    -o, --output            Output base directory (default: lib/src/domain/entities)
    --json                  Enable JSON serialization (default: true)
    --prefix-nested         Prefix nested entities with parent name (default: true)

LIST COMMAND:
  zfa entity list [options]
  Options:
    -o, --output            Directory to search (default: lib/src/domain/entities)

EXAMPLES:
  # Interactive entity creation
  zfa entity create -n User

  # Create with fields (basic types)
  zfa entity create -n User --field name:String --field age:int --field email:String?

  # Create with entity references and enums
  zfa entity create -n Order --field customer:\$Customer --field status:OrderStatus --field items:List<\$OrderItem>

  # Create enum
  zfa entity enum -n OrderStatus --value pending,processing,shipped,delivered

  # Create nested entity
  zfa entity create -n Address --field street:String --field city:String --field zipCode:String

  # Quick create simple entity
  zfa entity new -n Product

  # Add field to existing entity
  zfa entity add-field -n User --field phone:String?

  # Create from JSON
  zfa entity from-json user_data.json

  # List entities
  zfa entity list

FIELD TYPES:
  Basic types: String, int, double, bool, num, DateTime
  Nullable types: Add ? after type (e.g., String?, int?)
  Generic types: List<Type>, Set<Type>, Map<KeyType, ValueType>
  Custom types: Any other class name
  Zorphy Objects: \$TypeName (concrete), \$\$TypeName (sealed/polymorphic)
  Enums: TypeName (will be imported from enums/index.dart)

  Examples:
    name:String              → String field
    age:int?                 → Nullable int field
    tags:List<String>        → List of strings
    order:\$Order             → Order entity (concrete)
    status:OrderStatus       → OrderStatus enum
    metadata:Map<String, dynamic> → Map field

  Note: In shell, use --field order:\\\$Order (escape the \$)

For more information, visit: https://github.com/arrrrny/zorphy
''');
  }
}
