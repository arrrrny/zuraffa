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

import 'dart:io';

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
    this.parameterCount = 1,
    this.isGetter = false,
  });

  final String name;
  final String returnType;
  final String paramsType;

  /// Number of parameters the member declares (0 for parameter-less
  /// members). Threaded through from [MethodExtractor] so the zero-arg
  /// distinction is not encoded solely by an empty [paramsType] sentinel.
  final int parameterCount;

  /// True when the member is declared as a getter.
  final bool isGetter;

  /// True when this member is a genuine zero-argument method (not a
  /// getter and not a real `NoParams` parameter) and must be pinned as
  /// `Function()` / called with no arguments.
  bool get isZeroArg =>
      !isGetter && (parameterCount == 0 || paramsType.trim().isEmpty);

  bool get returnsStream => returnType.startsWith('Stream<');
}

/// Renders the certification contract test for one entity's mock.
///
/// [flutterTest] selects the host's test framework import (issue #1600, the
/// #1513 sibling): on a Flutter host plain `package:test` does not resolve
/// under the flutter_test runner, so the committed contract test must
/// import `package:flutter_test/flutter_test.dart`. The default keeps the
/// pure-Dart render byte-stable.
class MockContractTestWriter {
  const MockContractTestWriter({this.flutterTest = false});

  /// Whether the host project is a Flutter project (its pubspec declares a
  /// Flutter dependency).
  final bool flutterTest;

  /// The test framework import the rendered contract test uses.
  String get testImport => flutterTest
      ? 'package:flutter_test/flutter_test.dart'
      : 'package:test/test.dart';

  /// The interface (abstract class) name for [entityName].
  ///
  /// In entity mode (no [service]) this is `${entityName}DataSource`; in
  /// service mode it is the declared service interface (e.g.
  /// `DealShareService`).
  static String interfaceName(String entityName, {String? service}) {
    if (service == null) return '${entityName}DataSource';
    return _effectiveServiceName(service, entityName);
  }

  /// The mock subject class name for [entityName].
  ///
  /// In entity mode (no [service]) this is `${entityName}MockDataSource`;
  /// in service mode it is the generated mock provider
  /// (`${base}MockProvider`).
  static String mockClassName(String entityName, {String? service}) {
    if (service == null) return '${entityName}MockDataSource';
    final base = _stripServiceSuffix(
      _effectiveServiceName(service, entityName),
    );
    return '${base}MockProvider';
  }

  /// The declared service interface name for a (possibly raw) service
  /// argument, mirroring `GeneratorConfig.effectiveService`.
  static String _effectiveServiceName(String service, String entityName) {
    final s = service;
    if (s.endsWith('Service') || s.endsWith('Provider')) return s;
    return '${s}Service';
  }

  static String _stripServiceSuffix(String name) {
    if (name.endsWith('Service')) {
      return name.substring(0, name.length - 'Service'.length);
    }
    if (name.endsWith('Provider')) {
      return name.substring(0, name.length - 'Provider'.length);
    }
    return name;
  }

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

  /// The mock subject path under [outputDir].
  ///
  /// In entity mode (no [service]) this is the mock datasource path; in
  /// service mode it is the generated mock provider path.
  static String mockDatasourcePath(
    String entityName,
    String outputDir, {
    String? service,
    String? domain,
  }) {
    if (service == null) {
      final snake = StringUtils.camelToSnake(entityName);
      return p.join(
        outputDir,
        'data',
        'datasources',
        snake,
        '${snake}_mock_datasource.dart',
      );
    }
    final base = _stripServiceSuffix(
      _effectiveServiceName(service, entityName),
    );
    final baseSnake = StringUtils.camelToSnake(base);
    final fileName = '${baseSnake}_mock_provider.dart';
    final effectiveDomain = domain ?? StringUtils.camelToSnake(entityName);
    return p.join(outputDir, 'data', 'providers', effectiveDomain, fileName);
  }

  /// Extracts the method contract from the datasource interface on disk
  /// at `data/datasources/<snake>/<snake>_datasource.dart` under
  /// [outputDir]. Returns null when the interface file or class is absent
  /// — the caller must refuse certification honestly (nothing to pin).
  Future<List<ContractMethod>?> extractContract(
    String entityName,
    String outputDir, {
    FileSystem? fileSystem,
    String? service,
    String? domain,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    String interfacePath;
    if (service == null) {
      final snake = StringUtils.camelToSnake(entityName);
      interfacePath = p.join(
        outputDir,
        'data',
        'datasources',
        snake,
        '${snake}_datasource.dart',
      );
    } else {
      final svc = _effectiveServiceName(service, entityName);
      final svcSnake = StringUtils.camelToSnake(svc);
      final effectiveDomain = (domain != null && domain.isNotEmpty)
          ? domain
          : StringUtils.camelToSnake(entityName);
      final candidates = <String>[
        p.join(
          outputDir,
          'domain',
          'services',
          effectiveDomain,
          '$svcSnake.dart',
        ),
        p.join(outputDir, 'domain', 'services', '$svcSnake.dart'),
      ];
      interfacePath = candidates.firstWhere(
        (c) => fs.existsSync(c),
        orElse: () => candidates.first,
      );
    }
    if (!fs.existsSync(interfacePath)) return null;

    final parsed = await MethodExtractor.extractMethodsFromInterface(
      interfacePath,
      interfaceName(entityName, service: service),
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
            paramsType: (!m.isGetter && m.parameterCount == 0)
                ? ''
                : (m.paramsType ?? 'NoParams'),
            parameterCount: m.parameterCount,
            isGetter: m.isGetter,
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
    String? service,
    String? domain,
  }) {
    final snake = StringUtils.camelToSnake(entityName);
    final testPath = p.join(projectRoot, contractTestPath(entityName));
    final testDir = p.dirname(testPath);
    final entityPath = _entityFile(entityName, outputDir);
    String interfacePath;
    if (service == null) {
      interfacePath = p.join(
        outputDir,
        'data',
        'datasources',
        snake,
        '${snake}_datasource.dart',
      );
    } else {
      final svc = _effectiveServiceName(service, entityName);
      final svcSnake = StringUtils.camelToSnake(svc);
      final effectiveDomain = (domain != null && domain.isNotEmpty)
          ? domain
          : StringUtils.camelToSnake(entityName);
      final scoped = p.join(
        outputDir,
        'domain',
        'services',
        effectiveDomain,
        '$svcSnake.dart',
      );
      final flat = p.join(outputDir, 'domain', 'services', '$svcSnake.dart');
      interfacePath = File(scoped).existsSync() ? scoped : flat;
    }
    final mockPath = mockDatasourcePath(
      entityName,
      outputDir,
      service: service,
      domain: domain,
    );
    final mockDataPath = p.join(
      outputDir,
      'data',
      'mock',
      '${snake}_mock_data.dart',
    );

    String rel(String target) => p.relative(target, from: testDir);

    // Imports: the subject entity plus every OTHER entity named by a pinned
    // signature's return/parameter type. Deriving only the subject's import
    // leaves foreign-entity type names (e.g. a member returning `ZikZakPage`)
    // unimported, so the contract test cannot compile (#1856).
    final importedEntities = <String>{};
    if (entityPath != null) importedEntities.add(entityName);
    for (final method in methods) {
      for (final typeString in [method.returnType, method.paramsType]) {
        for (final match in RegExp(
          r'\b[A-Z][A-Za-z0-9_]*\b',
        ).allMatches(typeString)) {
          final candidate = match.group(0)!;
          if (EntityAnalyzer.entityFileExists(candidate, outputDir)) {
            importedEntities.add(candidate);
          }
        }
      }
    }

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
      ..writeln("import '$testImport';")
      ..writeln("import 'package:zuraffa/mock.dart';");

    if (entityPath != null && File(entityPath).existsSync()) {
      buffer.writeln("import '${rel(entityPath)}';");
    }
    for (final name
        in importedEntities.where((n) => n != entityName).toList()..sort()) {
      final path = _entityFile(name, outputDir);
      if (path != null) buffer.writeln("import '${rel(path)}';");
    }
    buffer.writeln("import '${rel(interfacePath)}';");
    buffer.writeln("import '${rel(mockPath)}';");
    if (File(mockDataPath).existsSync()) {
      buffer.writeln("import '${rel(mockDataPath)}';");
    }
    // Aggregate seams may reference a foreign entity's mock-data fixture in
    // the behavioral sample (see `_defaultParamsExpr`), so import that
    // fixture too when it exists on disk — otherwise the generated contract
    // test fails to compile with an undefined `…MockData` name (#1941).
    for (final name
        in importedEntities.where((n) => n != entityName).toList()..sort()) {
      final foreignMockDataPath = p.join(
        outputDir,
        'data',
        'mock',
        '${StringUtils.camelToSnake(name)}_mock_data.dart',
      );
      if (File(foreignMockDataPath).existsSync()) {
        buffer.writeln("import '${rel(foreignMockDataPath)}';");
      }
    }
    buffer
      ..writeln()
      ..writeln('void main() {')
      ..writeln(
        '  final ${interfaceName(entityName, service: service)} dataSource =\n'
        '      ${mockClassName(entityName, service: service)}();',
      )
      ..writeln()
      ..writeln("  group('$entityName mock contract (spec 1001)', () {")
      ..writeln(
        '    test(\'mock satisfies the ${interfaceName(entityName, service: service)} '
        'interface\', () {',
      )
      ..writeln(
        '      expect(dataSource, isA<${interfaceName(entityName, service: service)}>());',
      )
      ..writeln('    });');

    for (final method in methods) {
      final invocation = service == null
          ? _behavioralInvocation(
              entityName: entityName,
              method: method,
              outputDir: outputDir,
            )
          : null;
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
          '${method.isZeroArg ? '' : method.paramsType}) ${_safeLocal(method.name)}\$ =\n'
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
      isZeroArg: method.isZeroArg,
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
    bool isZeroArg = false,
  }) {
    final t = paramsType.trim();
    if (isZeroArg || t.isEmpty) return '';
    if (t == 'NoParams') return 'const NoParams()';
    if (t.startsWith('QueryParams<')) return '$t()';
    if (t.startsWith('ListQueryParams<')) return '$t()';
    if (t.startsWith('InitializationParams')) {
      return 'const InitializationParams(timeout: Duration.zero)';
    }
    if (t == entityName) {
      // Only synthesize a sample when the mock data fixture exists;
      // otherwise degrade to the signature pin (issue #1927).
      if (File(
        p.join(
          outputDir,
          'data',
          'mock',
          '${StringUtils.camelToSnake(t)}_mock_data.dart',
        ),
      ).existsSync()) {
        return '${entityName}MockData.sample$entityName';
      }
      return null;
    }
    if (_isEntityDartName(t, outputDir) &&
        File(
          p.join(
            outputDir,
            'data',
            'mock',
            '${StringUtils.camelToSnake(t)}_mock_data.dart',
          ),
        ).existsSync()) {
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
    final collection = StringUtils.pluralize(
      StringUtils.pascalToCamel(entityName),
    );
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
    return EntityAnalyzer.findEntitySourcePath(entityName, outputDir);
  }
}
