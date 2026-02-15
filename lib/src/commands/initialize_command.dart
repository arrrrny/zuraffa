import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import '../utils/file_utils.dart';
import '../utils/string_utils.dart';

class InitializeCommand {
  Future<void> execute(List<String> args) async {
    final parser = ArgParser()
      ..addOption(
        'entity',
        abbr: 'e',
        defaultsTo: 'Product',
        help: 'Entity name to generate (default: Product)',
      )
      ..addOption(
        'output',
        abbr: 'o',
        defaultsTo: 'lib/src',
        help: 'Output directory (default: lib/src)',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing files',
        negatable: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Preview what would be generated without writing files',
        negatable: false,
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Enable verbose output',
        negatable: false,
      )
      ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false);

    final results = parser.parse(args);

    if (results['help'] as bool) {
      _printHelp(parser);
      return;
    }

    final entityName = results['entity'] as String;
    final outputDir = results['output'] as String;
    final force = results['force'] as bool;
    final dryRun = results['dry-run'] as bool;
    final verbose = results['verbose'] as bool;

    final entitySnake = StringUtils.camelToSnake(entityName);

    // Create entity directory path
    final entityDir = path.join(outputDir, 'domain', 'entities', entitySnake);
    final entityFile = path.join(entityDir, '$entitySnake.dart');

    // Generate entity content
    final content = _generateEntityContent(entityName);

    try {
      final result = await FileUtils.writeFile(
        entityFile,
        content,
        'entity',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
      );

      if (dryRun) {
        print('✓ Would generate: ${result.path}');
      } else {
        print('✓ Generated: ${result.path}');
      }

      print('\n📝 Next steps:');
      print('   • Generate complete feature:');
      print(
        '     zfa generate $entityName --methods=get,getList,create,update,delete --data --vpc --state',
      );
      print('   • Or generate incrementally:');
      print('     zfa generate $entityName --methods=get,getList');
      print(
        '     zfa generate $entityName --methods=get,getList --vpc --state --force',
      );
      print(
        '     zfa generate $entityName --methods=get,getList --data --force',
      );
    } catch (e) {
      print('❌ Error: $e');
      exit(1);
    }
  }

  void _printHelp(ArgParser parser) {
    print('''
Initialize a test entity to quickly try out Zuraffa

USAGE:
  zfa initialize [options]
  zfa init [options]

OPTIONS:
${parser.usage}

EXAMPLES:
  zfa initialize                           # Generate Product entity
  zfa initialize --entity=User             # Generate User entity
  zfa init -e Order --output=lib/src       # Generate Order entity in lib/src
  zfa initialize --dry-run                 # Preview without writing files

DESCRIPTION:
  Creates a sample entity with common fields (id, name, description, price, etc.)
  to help you quickly test Zuraffa's code generation capabilities.
  
  After running this command, use 'zfa generate' to create the full Clean Architecture
  structure around your entity.
''');
  }

  String _generateEntityContent(String entityName) {
    return '''
import 'package:zorphy_annotation/zorphy.dart';

part '${entityName}.zorphy.dart';

@Zorphy(
  json: true,
  copyWith: true,
  equal: true,
)
class $entityName with _\$$entityName {
  const $entityName._();

  const factory $entityName({
    @Default('') String id,
    required String name,
    String? description,
    required double price,
    String? category,
    @Default(true) bool isActive,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _\$$entityName${entityName}Impl;

  factory $entityName.fromJson(Map<String, dynamic> json) =>
      _\$${entityName}FromJson(json);
}
''';
  }
}
