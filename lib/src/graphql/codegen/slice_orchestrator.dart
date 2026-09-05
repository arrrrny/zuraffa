import 'dart:io';

import 'package:zuraffa/zuraffa.dart';
import 'package:path/path.dart' as p;

/// Orchestrates the full-stack code generation for a GraphQL schema slice.
///
/// ```dart
/// final orchestrator = SliceOrchestrator(
///   schema: schema,
///   outputDir: 'lib/graphql',
/// );
/// orchestrator.generateAll();
/// ```
class SliceOrchestrator {
  SliceOrchestrator({
    required this.schema,
    required this.outputDir,
    TypeMapper? typeMapper,
    this.force = false,
  }) : typeMapper = typeMapper ?? TypeMapper();

  final GraphQLSchema schema;
  final String outputDir;
  final TypeMapper typeMapper;
  final bool force;

  final List<String> _generatedFiles = [];
  List<String> get generatedFiles => List.unmodifiable(_generatedFiles);

  /// Generate all code for the schema.
  void generateAll() {
    // 1. Entities (OBJECT types)
    _generateEntities();

    // 2. DTOs (INPUT types)
    _generateDtos();

    // 3. Unions (UNION types)
    _generateUnions();

    // 4. Datasources (per domain area)
    // Note: In a real implementation, this would group queries/mutations
    // by domain area (Product, Order, etc.) from the schema

    // 5. DI registrations
    _generateDiRegistrations();
  }

  void _generateEntities() {
    final entityDir = p.join(outputDir, 'entities');
    final generator = EntityGenerator(typeMapper: typeMapper);

    for (final type in schema.getObjectTypes()) {
      if (type.name.startsWith('__')) continue; // Skip introspection types
      final code = generator.generate(type);
      final filePath = p.join(entityDir, '${_snakeCase(type.name)}.dart');
      _writeFile(filePath, code);
      _generatedFiles.add(filePath);
    }
  }

  void _generateDtos() {
    final dtoDir = p.join(outputDir, 'dto');
    final generator = DtoGenerator(typeMapper: typeMapper);

    for (final type in schema.getInputTypes()) {
      final code = generator.generate(type);
      final filePath = p.join(dtoDir, '${_snakeCase(type.name)}.dart');
      _writeFile(filePath, code);
      _generatedFiles.add(filePath);
    }
  }

  void _generateUnions() {
    final unionDir = p.join(outputDir, 'unions');
    final generator = UnionGenerator(typeMapper: typeMapper, schema: schema);

    for (final type in schema.getUnionTypes()) {
      final code = generator.generate(type);
      final filePath = p.join(unionDir, '${_snakeCase(type.name)}.dart');
      _writeFile(filePath, code);
      _generatedFiles.add(filePath);
    }
  }

  void _generateDiRegistrations() {
    final diFile = p.join(outputDir, 'graphql_di.dart');
    final generator = DiGenerator();

    // Collect all object types that have queries
    final registrations = <DiRegistration>[];
    final queryType = schema.getQueryType();
    if (queryType != null) {
      final seen = <String>{};
      for (final field in queryType.fields) {
        if (field.name.startsWith('__')) continue; // Skip introspection
        final innerType = field.type.innerType;
        // Only register object types (skip scalars, enums, unions)
        if (innerType is! GraphQLObjectType) continue;
        final typeName = innerType.name;
        if (seen.contains(typeName)) continue;
        seen.add(typeName);
        registrations.add(DiRegistration(name: typeName));
      }
    }

    final code = generator.generate(registrations);
    _writeFile(diFile, code);
    _generatedFiles.add(diFile);
  }

  void _writeFile(String path, String content) {
    final file = File(path);
    if (!force && file.existsSync()) {
      // Skip existing files when force is disabled
      return;
    }
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String _snakeCase(String name) {
    // Handle acronyms and consecutive uppercase letters properly:
    // ProductID -> product_id, SKU -> sku, HTTPRequest -> http_request
    return name
        .replaceAllMapped(
          // Insert underscore before uppercase that follows lowercase or digit,
          // or before the last uppercase in a sequence (e.g., HTTPRequest -> HTTP_Request)
          RegExp(r'([a-z0-9])([A-Z])|([A-Z])([A-Z][a-z])'),
          (m) => m.group(1) != null
              ? '${m.group(1)}_${m.group(2)}'
              : '${m.group(3)}_${m.group(4)}',
        )
        .toLowerCase();
  }
}
