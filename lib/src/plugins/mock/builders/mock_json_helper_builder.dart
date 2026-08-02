import '../../../core/builder/shared/spec_library.dart';
import '../../../utils/entity_analyzer.dart';
import 'mock_type_helper.dart';

class MockJsonHelperBuilder {
  final String outputDir;
  final SpecLibrary specLibrary;
  final MockTypeHelper typeHelper;

  MockJsonHelperBuilder({
    required this.outputDir,
    SpecLibrary? specLibrary,
    MockTypeHelper? typeHelper,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       typeHelper = typeHelper ?? const MockTypeHelper();

  String generateHelperContent({
    required String entityName,
    required String domain,
    required String jsonFilePath,
  }) {
    final helperClassName = '${entityName}MockJson';
    final entityImport = EntityAnalyzer.getEntityImportPath(
      entityName,
      outputDir,
      fromDir: 'data/mock_json/$domain',
    );

    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      entityName,
      outputDir,
    );
    final isPolymorphic = subtypes.isNotEmpty;

    final subtypeImports = <String>[];
    if (isPolymorphic) {
      for (final subtype in subtypes) {
        final subImport = EntityAnalyzer.getEntityImportPath(
          subtype,
          outputDir,
          fromDir: 'data/mock_json/$domain',
        );
        subtypeImports.add("import '$subImport';");
      }
    }
    // writeln() semantics: each import is followed by a newline so the
    // template's own trailing newline yields a blank line before the class.
    final subtypeImportsText = isPolymorphic
        ? '${subtypeImports.join('\n')}\n'
        : '';

    final deserializeMethod = isPolymorphic
        ? _buildPolymorphicDeserializer(entityName, subtypes)
        : '        return $entityName.fromJson(j as Map<String, dynamic>);';

    final loadMethod =
        '''
  static Future<List<$entityName>> load${entityName}s() async {
    final file = File('$jsonFilePath');
    if (!await file.exists()) {
      throw StateError('Mock JSON file not found: $jsonFilePath');
    }
    try {
      final jsonStr = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList.map((j) => _deserialize(j as Map<String, dynamic>)).toList();
    } catch (e) {
      throw StateError('Failed to load mock JSON from $jsonFilePath: \$e');
    }
  }''';

    final sampleMethod =
        '''
  static Future<$entityName> loadSample$entityName() async {
    final list = await load${entityName}s();
    if (list.isEmpty) {
      throw StateError('Mock JSON file is empty: $jsonFilePath');
    }
    return list.first;
  }''';

    final privat =
        '''
  static $entityName _deserialize(Map<String, dynamic> j) {
$deserializeMethod
  }
''';

    return '''
import 'dart:convert';
import 'dart:io';

import '$entityImport';
$subtypeImportsText
class $helperClassName {
  $loadMethod

  $sampleMethod

  static Future<List<$entityName>> loadSampleList() async {
    return load${entityName}s();
  }

  static Future<List<$entityName>> loadEmptyList() async {
    return <$entityName>[];
  }
$privat}
''';
  }

  String _buildPolymorphicDeserializer(
    String entityName,
    List<String> subtypes,
  ) {
    final lines = <String>[
      '    final type = j[\'_type\'] as String?;',
      '    switch (type) {',
      ...subtypes.map(
        (subtype) => "      case '$subtype': return $subtype.fromJson(j);",
      ),
      '      default: return $entityName.fromJson(j);',
      '    }',
    ];
    return lines.join('\n');
  }
}
