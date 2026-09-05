/// Auto-generated contract tests for Tier-1 certified mocks (spec 1001,
/// issue #1001): "mocks the framework certifies, not the agent".
///
/// [MockContractTestWriter] renders `<entity>_mock_contract_test.dart` —
/// for every method declared by the `<Entity>DataSource` interface the
/// test pins:
///
/// 1. **existence + exact signature** — a typed tear-off assignment
///    (`final Ret Function(Params) m$ = dataSource.m;`) through the
///    INTERFACE type. Removing or re-signaturing any interface member
///    breaks the file's compilation, so the certification goes red the
///    moment the contract drifts (the certification is live, not a
///    snapshot).
/// 2. **behavioral conformance** — the method is invoked through the
///    interface and the returned value is type-checked, proving the mock
///    is a Fake with typed defaults (it returns the mock data's typed
///    samples) rather than a stub that throws.
///
/// The file is written into the target project at
/// `test/mock/<snake>/<snake>_mock_contract_test.dart` and is executed in
/// a throwaway sandbox by [MockCertificationSandbox] (dart analyze +
/// dart test) — the same relative geometry, so the identical bytes run
/// in both places.
library;

import 'package:path/path.dart' as p;

import '../../../core/context/file_system.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/method_extractor.dart';
import '../../../utils/string_utils.dart';

/// One interface method the contract pins.
class ContractMethod {
  const ContractMethod({
    required this.name,
    required this.returnType,
    required this.paramsType,
  });

  final String name;
  final String returnType;
  final String paramsType;

  bool get returnsStream => returnType.startsWith('Stream<');
}

/// Renders the certification contract test for one entity's mock.
class MockContractTestWriter {
  const MockContractTestWriter();

  /// The interface (abstract class) name for [entityName].
  static String interfaceName(String entityName) => '${entityName}DataSource';

  /// The mock datasource class name for [entityName].
  static String mockClassName(String entityName) =>
      '${entityName}MockDataSource';

  /// The canonical contract test path inside a project:
  /// `test/mock/<snake>/<snake>_mock_contract_test.dart`.
  static String contractTestPath(String entityName) => p.join(
    'test',
    'mock',
    StringUtils.camelToSnake(entityName),
    '${StringUtils.camelToSnake(entityName)}_mock_contract_test.dart',
  );

  /// The canonical mock-cert receipt path inside a project:
  /// `test/mock/<snake>/mock-cert.<Entity>.json`.
  static String receiptPath(String entityName) => p.join(
    'test',
    'mock',
    StringUtils.camelToSnake(entityName),
    'mock-cert.$entityName.json',
  );

  /// The mock datasource subject path under [outputDir].
  static String mockDatasourcePath(String entityName, String outputDir) {
    final snake = StringUtils.camelToSnake(entityName);
    return p.join(
      outputDir,
      'data',
      'datasources',
      snake,
      '${snake}_mock_datasource.dart',
    );
  }

  /// Extracts the method contract from the datasource interface on disk
  /// at `data/datasources/<snake>/<snake>_datasource.dart` under
  /// [outputDir]. Returns null when the interface file or class is absent
  /// — the caller must refuse certification honestly (nothing to pin).
  Future<List<ContractMethod>?> extractContract(
    String entityName,
    String outputDir, {
    FileSystem? fileSystem,
  }) async {
    final snake = StringUtils.camelToSnake(entityName);
    final interfacePath = p.join(
      outputDir,
      'data',
      'datasources',
      snake,
      '${snake}_datasource.dart',
    );
    final fs = fileSystem ?? const DefaultFileSystem();
    if (!fs.existsSync(interfacePath)) return null;

    final parsed = await MethodExtractor.extractMethodsFromInterface(
      interfacePath,
      interfaceName(entityName),
      fileSystem: fs,
    );
    if (parsed.isEmpty) return null;
    return parsed
        .map(
          (m) => ContractMethod(
            name: m.fieldName,
            // MethodExtractor cleans Future<>/Stream<> wrappers off the
            // declared return (useCaseType carries the async kind), so
            // the RAW interface signature is reconstructed here — the
            // contract must pin what the interface actually declares.
            returnType: _rawReturnType(
              m.returnsType ?? 'void',
              m.useCaseType ?? 'usecase',
            ),
            paramsType: m.paramsType ?? 'NoParams',
          ),
        )
        .toList();
  }

  /// Rebuild the declared return type from the cleaned type + async kind
  /// ('usecase' → Future<T>, 'stream' → Stream<T>, 'completable' →
  /// Future<void>, 'sync' → T).
  static String _rawReturnType(String cleaned, String useCaseType) {
    switch (useCaseType) {
      case 'stream':
        return 'Stream<$cleaned>';
      case 'completable':
        return 'Future<void>';
      case 'sync':
        return cleaned;
      case 'usecase':
      default:
        return 'Future<$cleaned>';
    }
  }

  /// Renders the contract test source for [entityName] pinned to
  /// [methods]. Imports are computed relative from the contract test's
  /// canonical location, so the exact same bytes compile both in the
  /// target project and in the certification sandbox.
  String render({
    required String entityName,
    required List<ContractMethod> methods,
    required String projectRoot,
    required String outputDir,
  }) {
    final snake = StringUtils.camelToSnake(entityName);
    final testPath = p.join(projectRoot, contractTestPath(entityName));
    final testDir = p.dirname(testPath);
    final entityPath = _entityFile(entityName, outputDir);
    final interfacePath = p.join(
      outputDir,
      'data',
      'datasources',
      snake,
      '${snake}_datasource.dart',
    );
    final mockPath = mockDatasourcePath(entityName, outputDir);
    final mockDataPath = p.join(
      outputDir,
      'data',
      'mock',
      '${snake}_mock_data.dart',
    );

    String rel(String target) => p.relative(target, from: testDir);

    final buffer = StringBuffer()
      ..writeln('// GENERATED - DO NOT EDIT')
      ..writeln('// Mock certification contract (spec 1001, issue #1001).')
      ..writeln('//')
      ..writeln(
        '// Auto-generated by `zfa mock create $entityName '
        '--certify`.',
      )
      ..writeln(
        '// Every method the ${interfaceName(entityName)} interface '
        'declares is pinned',
      )
      ..writeln(
        '// through the INTERFACE type (typed tear-offs + '
        'behavioral calls).',
      )
      ..writeln(
        '// Removing or re-signaturing any interface member breaks '
        "this file's",
      )
      ..writeln(
        '// compilation — the certification goes red (the '
        'certification is live).',
      )
      ..writeln("import 'package:test/test.dart';")
      ..writeln("import 'package:zuraffa/mock.dart';");

    if (entityPath != null) buffer.writeln("import '${rel(entityPath)}';");
    buffer
      ..writeln("import '${rel(interfacePath)}';")
      ..writeln("import '${rel(mockPath)}';")
      ..writeln("import '${rel(mockDataPath)}';")
      ..writeln()
      ..writeln('void main() {')
      ..writeln(
        '  final ${interfaceName(entityName)} dataSource =\n'
        '      ${mockClassName(entityName)}();',
      )
      ..writeln()
      ..writeln("  group('$entityName mock contract (spec 1001)', () {")
      ..writeln(
        '    test(\'mock satisfies the ${interfaceName(entityName)} '
        'interface\', () {',
      )
      ..writeln(
        '      expect(dataSource, isA<${interfaceName(entityName)}>());',
      )
      ..writeln('    });');

    for (final method in methods) {
      final invocation = _behavioralInvocation(
        entityName: entityName,
        method: method,
        outputDir: outputDir,
      );
      // Behavioral invocations may await — the test closure must be
      // async for them.
      final asyncMarker = invocation == null ? '' : ' async';
      buffer
        ..writeln()
        ..writeln(
          "    test('${method.name}: exists, returns ${method.returnType}, "
          'fake with typed defaults\', ()$asyncMarker {',
        )
        // The signature pin: compiles only while the interface keeps this
        // member with this exact signature, and only while the mock —
        // viewed through the interface — still satisfies it.
        ..writeln(
          '      // Signature pin — interface drift breaks this '
          'file.',
        )
        ..writeln(
          '      final ${method.returnType} Function('
          '${method.paramsType}) ${_safeLocal(method.name)}\$ =\n'
          '          dataSource.${method.name};',
        )
        ..writeln('      expect(${_safeLocal(method.name)}\$, isNotNull);');
      if (invocation != null) {
        buffer
          ..writeln(
            '      // Behavioral: the fake returns typed default '
            'data (no throw).',
          )
          ..writeln(invocation);
      } else {
        buffer
          ..writeln(
            '      // Behavioral invocation omitted: the params '
            'type (${method.paramsType})',
          )
          ..writeln(
            '      // has no synthesizable default; the pin above '
            'still proves the',
          )
          ..writeln('      // contract (compile-level).');
      }
      buffer.writeln('    });');
    }

    buffer
      ..writeln('  });')
      ..writeln('}')
      ..writeln();
    return buffer.toString();
  }

  /// The behavioral invocation for a method, or null when a safe default
  /// for the params type cannot be synthesized.
  String? _behavioralInvocation({
    required String entityName,
    required ContractMethod method,
    required String outputDir,
  }) {
    final params = _defaultParamsExpr(
      entityName: entityName,
      paramsType: method.paramsType,
      outputDir: outputDir,
    );
    if (params == null) return null;

    final ret = method.returnType;
    if (ret == 'Future<void>' || ret == 'void') {
      return 'await dataSource.${method.name}($params);';
    }
    if (ret.startsWith('Future<') || ret.startsWith('Stream<')) {
      final inner = _unwrapAsync(ret);
      if (method.returnsStream) {
        return 'final value = await dataSource'
            '.${method.name}($params).first;\n'
            '      expect(value, isA<$inner>());';
      }
      return 'final value = await dataSource.${method.name}($params);\n'
          '      expect(value, isA<$inner>());';
    }
    // Sync return: call and type-check directly.
    return 'final value = dataSource.${method.name}($params);\n'
        '      expect(value, isA<$ret>());';
  }

  String _unwrapAsync(String ret) =>
      ret.substring(ret.indexOf('<') + 1, ret.length - 1);

  /// Synthesizes a default expression for a params type, or null when no
  /// safe default exists. Canonical datasource param types are covered;
  /// anything else degrades to the signature pin only.
  String? _defaultParamsExpr({
    required String entityName,
    required String paramsType,
    required String outputDir,
  }) {
    final t = paramsType.trim();
    if (t == 'NoParams') return 'const NoParams()';
    if (t.startsWith('QueryParams<')) return '$t()';
    if (t.startsWith('ListQueryParams<')) return '$t()';
    if (t.startsWith('InitializationParams')) {
      return 'const InitializationParams(timeout: Duration.zero)';
    }
    if (t == entityName) return '${entityName}MockData.sample$entityName';
    if (_isEntityDartName(t, outputDir)) {
      return '${t}MockData.sample$t';
    }

    final idValue = _firstRecordIdExpr(entityName, outputDir);
    if (idValue == null) return null;

    if (t.startsWith('DeleteParams<')) return '$t(id: $idValue)';
    if (t.startsWith('UpdateParams<')) {
      final patch = _patchTypeFor(t);
      return '$t(id: $idValue, data: $patch())';
    }
    if (t.startsWith('ToggleParams<')) {
      final idField = _idFieldName(entityName, outputDir) ?? 'id';
      final fields = EntityAnalyzer.analyzeEntity(entityName, outputDir);
      final value = _toggleSampleValue(fields[idField]);
      return '$t(id: $idValue, field: '
          "const Field<$entityName, dynamic>('$idField'), value: $value)";
    }
    return null;
  }

  /// A type-correct sample value for the toggled field — the generated
  /// `copyWithField` casts the value to the field's declared type, so a
  /// mistyped (or null) value throws (same convention the test plugin's
  /// `toggleSampleValue` uses).
  String _toggleSampleValue(String? fieldType) {
    final t = fieldType?.replaceAll('?', '').trim();
    switch (t) {
      case 'int':
      case 'num':
        return '1';
      case 'double':
        return '1.0';
      case 'bool':
        return 'true';
      case 'String':
      default:
        return "'toggled'";
    }
  }

  /// `UpdateParams<I, P>` → the `P` (patch) argument as written in the
  /// interface.
  String _patchTypeFor(String paramsType) {
    final args = _typeArguments(paramsType)!;
    return args[1];
  }

  List<String>? _typeArguments(String type) {
    final open = type.indexOf('<');
    final close = type.lastIndexOf('>');
    if (open == -1 || close <= open) return null;
    return type
        .substring(open + 1, close)
        .split(',')
        .map((s) => s.trim())
        .toList();
  }

  bool _isEntityDartName(String t, String outputDir) {
    if (t.isEmpty) return false;
    if (t[0].toUpperCase() != t[0]) return false;
    return EntityAnalyzer.entityFileExists(t, outputDir);
  }

  String? _firstRecordIdExpr(String entityName, String outputDir) {
    final fields = EntityAnalyzer.analyzeEntity(entityName, outputDir);
    final idField = _idFieldName(entityName, outputDir);
    if (idField == null || !fields.containsKey(idField)) return null;
    final collection = '${StringUtils.pascalToCamel(entityName)}s';
    return '${entityName}MockData.$collection.first.$idField';
  }

  String? _idFieldName(String entityName, String outputDir) {
    final fields = EntityAnalyzer.analyzeEntity(entityName, outputDir);
    if (fields.containsKey('id')) return 'id';
    if (fields.isEmpty) return null;
    final first = fields.entries.first;
    const scalars = {'String', 'int', 'String?', 'int?'};
    return scalars.contains(first.value) ? first.key : null;
  }

  String _safeLocal(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

  String? _entityFile(String entityName, String outputDir) {
    if (!EntityAnalyzer.entityFileExists(entityName, outputDir)) return null;
    final snake = StringUtils.camelToSnake(entityName);
    return p.join(outputDir, 'domain', 'entities', snake, '$snake.dart');
  }
}
