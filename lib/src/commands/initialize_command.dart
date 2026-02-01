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
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show help',
        negatable: false,
      );

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
          '     zfa generate $entityName --methods=get,getList,create,update,delete --repository --data --vpc --state');
      print('   • Or generate incrementally:');
      print('     zfa generate $entityName --methods=get,getList --repository');
      print(
          '     zfa generate $entityName --methods=get,getList --vpc --state --force');
      print(
          '     zfa generate $entityName --methods=get,getList --data --force');
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
/// Sample $entityName entity for testing Zuraffa.
/// 
/// This is a simple entity with common fields to help you get started.
/// Feel free to modify or replace with your own entity structure.
class $entityName {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const $entityName({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  $entityName copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return $entityName(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is $entityName &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.price == price &&
        other.category == category &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      price,
      category,
      isActive,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return '$entityName(id: \$id, name: \$name, price: \$price, category: \$category, isActive: \$isActive)';
  }

  // Example factory constructors
  factory $entityName.sample() {
    return $entityName(
      id: '1',
      name: 'Sample $entityName',
      description: 'This is a sample $entityName for testing',
      price: 99.99,
      category: 'Electronics',
      createdAt: DateTime.now(),
    );
  }

  // JSON serialization helpers (optional - you can use code generation instead)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory $entityName.fromJson(Map<String, dynamic> json) {
    return $entityName(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
''';
  }
}
