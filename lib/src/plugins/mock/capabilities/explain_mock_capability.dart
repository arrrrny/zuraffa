/// MockExplainCapability (spec 1121, issue #1121 order 3): `zfa mock explain
/// <Entity>` — the fleshed-out explanation of a mock's surface, read from
/// the files already on disk (read-only, like `zfa mock verify`):
///
/// - which entity methods the mock covers, and which interface methods it
///   skips (the drift),
/// - the certification status per method — `certified` / `certified-red`
///   from the committed spec-1001 receipt (`test/mock/<snake>/mock-cert.
///   <Entity>.json`), `uncertified` when implemented but never certified,
///   `missing` when the interface member is absent from the mock,
/// - the per-method fixture selector bindings (issue #1034): whether the
///   entity's mock-data class declares a `static ... forMethod(...)` selector
///   and which `<Entity>MockData.forMethod(params.<field>)` bindings the
///   generated mock lane files actually carry.
///
/// Refusals (errors-are-an-API, every one names the fix):
/// - missing positional entity name   → exit 2 (usage)
/// - no mock artifacts for the entity → exit 1 (missing_file)
/// - no interface to explain against  → exit 1 (missing_file)
///
/// `--json` carries the full structured report under the canonical
/// `zuraffa.verdict.v1` envelope's `details.explain` (issue #1105).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../cli/exit_protocol.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../core/verdict_envelope.dart';
import '../../../models/generated_file.dart';
import '../../../plugins/mock/certification/mock_cert_receipt.dart' as cert;
import '../../../plugins/mock/services/mock_certification.dart';
import '../../../utils/method_extractor.dart';
import '../../../utils/string_utils.dart';

/// One per-method row of the explain report.
class MockExplainMethod {
  final String name;
  final bool covered;
  final String certification;

  const MockExplainMethod({
    required this.name,
    required this.covered,
    required this.certification,
  });

  Map<String, dynamic> toJson() => {
    'method': name,
    'covered': covered,
    'certification': certification,
  };
}

/// The #1034 fixture-selector section of the explain report.
class MockExplainSelector {
  final bool declared;
  final String? paramType;
  final String? file;
  final List<Map<String, String>> bindings;

  const MockExplainSelector({
    required this.declared,
    this.paramType,
    this.file,
    this.bindings = const <Map<String, String>>[],
  });

  Map<String, dynamic> toJson() => {
    'declared': declared,
    if (paramType != null) 'paramType': paramType,
    if (file != null) 'file': file,
    'bindings': bindings,
  };
}

/// The full explain report for one entity's mock.
class MockExplainReport {
  final String entity;
  final String? mockFile;
  final String? mockClass;
  final String? interfaceFile;
  final String? interfaceClass;
  final List<MockExplainMethod> methods;
  final List<String> covered;
  final List<String> skipped;
  final List<String> invented;
  final String? registryId;
  final bool conforms;
  final List<String> fixtures;
  final MockExplainSelector selector;

  const MockExplainReport({
    required this.entity,
    this.mockFile,
    this.mockClass,
    this.interfaceFile,
    this.interfaceClass,
    required this.methods,
    required this.covered,
    required this.skipped,
    required this.invented,
    this.registryId,
    required this.conforms,
    required this.fixtures,
    required this.selector,
  });

  Map<String, dynamic> toJson() => {
    'entity': entity,
    if (mockFile != null) 'mock': {'file': mockFile, 'class': mockClass},
    if (interfaceFile != null)
      'interface': {'file': interfaceFile, 'class': interfaceClass},
    'methods': [for (final m in methods) m.toJson()],
    'covered': covered,
    'skipped': skipped,
    'invented': invented,
    if (registryId != null) 'registryId': registryId,
    'conformance': conforms,
    'fixtures': fixtures,
    'selector': selector.toJson(),
  };
}

class MockExplainCapability implements ZuraffaCapability {
  final MockExplainPaths paths;

  MockExplainCapability({MockExplainPaths? paths})
    : paths = paths ?? const MockExplainPaths();

  @override
  String get name => 'explain_mock';

  @override
  String get description =>
      'Explain a mock: method coverage, skipped members, per-method '
      'certification status, and the #1034 fixture-selector bindings '
      '(spec 1121)';

  /// Exit-code contract.
  static const exitUsage = ExitProtocol.usage;
  static const exitMissing = ExitProtocol.failure;

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Entity whose mock is explained',
      },
      'project': {
        'type': 'string',
        'description': 'Project root (cwd when omitted)',
      },
      'json': {
        'type': 'boolean',
        'description':
            'Emit the canonical zuraffa.verdict.v1 envelope whose '
            'details.explain carries the report',
        'default': false,
      },
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'report': {
        'type': 'object',
        'description': 'The MockExplainReport structure',
      },
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    throw UnsupportedError(
      'zfa mock explain plans through run() — the CLI owns exit codes '
      '(spec 1121).',
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    throw UnsupportedError('use run() — the CLI owns exit codes');
  }

  /// The CLI entrypoint (`zfa mock explain <Entity>`): owns exit codes.
  /// Returns the process exit code.
  Future<int> run(List<String> args) async {
    var jsonMode = false;
    String? project;
    String? name;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a == '--json') {
        jsonMode = true;
      } else if (a == '--name' && i + 1 < args.length) {
        name = args[++i];
      } else if (a == '--project' && i + 1 < args.length) {
        project = args[++i];
      } else if (!a.startsWith('-') && name == null) {
        name = a;
      }
    }
    if (name == null || name.trim().isEmpty) {
      final fix = ExitProtocol.fixLine(
        're-run with the entity whose mock is explained — '
        '`zfa mock explain <Entity>` (after `zfa mock create <Entity>`)',
      );
      if (jsonMode) {
        stderr.writeln('❌ Usage: zfa mock explain <Entity> [--json]');
        stderr.writeln(fix);
      } else {
        // ignore: avoid_print
        print('❌ Usage: zfa mock explain <Entity> [--json] [--project <dir>]');
        // ignore: avoid_print
        print(fix);
      }
      return exitUsage;
    }

    final root = project == null || project.isEmpty
        ? Directory.current.path
        : p.absolute(project);
    final entity = StringUtils.convertToPascalCase(name.trim());

    final resolution = paths.resolve(root, entity);
    if (resolution == null) {
      // Both artifacts missing — the honest missing_file refusal.
      _emitRefusal(
        jsonMode: jsonMode,
        entity: entity,
        message:
            'no mock artifacts found for $entity under '
            '${paths.outputDir} — nothing to explain',
        fix: 'generate them first — `zfa mock create $entity --certify`',
      );
      return exitMissing;
    }
    final artifacts = resolution;

    // ── The interface surface, as the entity declares it NOW. ──
    final interfaceMethods = <String>[];
    final interfaceFile = artifacts.interfaceFile;
    if (interfaceFile != null) {
      final parsed = await MethodExtractor.extractMethodsFromInterface(
        interfaceFile,
        artifacts.interfaceClass,
      );
      interfaceMethods.addAll(parsed.map((m) => m.fieldName));
    } else {
      _emitRefusal(
        jsonMode: jsonMode,
        entity: entity,
        kind: 'missing_file',
        member: artifacts.interfaceClass,
        file: artifacts.interfacePath,
        message:
            'no interface found for $entity '
            '(${artifacts.interfacePath}) — nothing to explain against',
        fix:
            'restore the entity datasource interface or regenerate — '
            '`zfa mock create $entity --certify`',
      );
      return exitMissing;
    }

    // ── The mock's implemented members (AST). A missing mock file (the
    //    interface-only tree) reports every interface member as missing —
    //    the honest coverage picture. ──
    final implementedMethods = <String>[];
    final mockFile = artifacts.mockFile;
    if (mockFile != null) {
      final helper = const AstHelper();
      final parseResult = await helper.parseFile(mockFile);
      final unit = parseResult.unit;
      if (unit != null) {
        final classNode = helper.findClass(unit, artifacts.mockClass);
        if (classNode != null) {
          implementedMethods.addAll(
            helper.findMethods(classNode).map((m) => m.name.toString()),
          );
        }
      }
    }

    final interfaceSet = interfaceMethods.toSet();
    final implementedSet = implementedMethods.toSet();
    final covered = [
      for (final m in interfaceMethods)
        if (implementedSet.contains(m)) m,
    ];
    final skipped = [
      for (final m in interfaceMethods)
        if (!implementedSet.contains(m)) m,
    ];
    final invented = [
      for (final m in implementedMethods)
        if (!interfaceSet.contains(m)) m,
    ];

    // ── Certification status per method: the committed spec-1001 receipt
    //    (mock-cert.<Entity>.json) pins per-method satisfaction; the
    //    deterministic registry id comes from the shared certification
    //    record (the same shape MockCertify reports). ──
    final receipt = cert.loadMockCertReceipt(root, entity);
    final receiptStatus = <String, bool>{
      for (final m in receipt?.methods ?? const <MapEntry<String, bool>>[])
        m.key: m.value,
    };
    String statusOf(String method) {
      if (!implementedSet.contains(method)) return 'missing';
      final satisfied = receiptStatus[method];
      if (satisfied == null) return 'uncertified';
      return satisfied ? 'certified' : 'certified-red';
    }

    final methods = [
      for (final m in interfaceMethods)
        MockExplainMethod(
          name: m,
          covered: implementedSet.contains(m),
          certification: statusOf(m),
        ),
      for (final m in invented)
        MockExplainMethod(name: m, covered: true, certification: 'invented'),
    ];

    // ── Registry id + conformance from the shared certification record. ──
    final fixtures = <GeneratedFile>[
      if (artifacts.mockDataFile != null)
        GeneratedFile(
          path: artifacts.mockDataFile!,
          type: 'mock_data',
          action: 'created',
        ),
    ];
    final certification = await MockCertificationService.certify(
      entity: entity,
      outputDir: paths.outputDir,
      files: fixtures,
      projectRoot: root,
    );

    // ── The #1034 fixture selector: declared on the mock-data class, bound
    //    in the generated mock lane files. ──
    final selector = _explainSelector(artifacts);

    final report = MockExplainReport(
      entity: entity,
      mockFile: artifacts.mockPath,
      mockClass: artifacts.mockClass,
      interfaceFile: artifacts.interfacePath,
      interfaceClass: artifacts.interfaceClass,
      methods: methods,
      covered: covered,
      skipped: skipped,
      invented: invented,
      registryId: certification.registryId,
      conforms: certification.conformance,
      fixtures: [if (artifacts.mockDataFile != null) artifacts.mockDataFile!],
      selector: selector,
    );

    if (jsonMode) {
      VerdictEnvelope.emit(
        VerdictEnvelope(
          command: 'zfa mock explain $entity',
          verdict: VerdictKind.pass,
          exitClass: ExitProtocol.success,
          subject: VerdictSubject(kind: 'mock', id: entity),
          details: {'explain': report.toJson()},
        ),
      );
    } else {
      _printReport(report);
    }
    return ExitProtocol.success;
  }

  /// The #1034 selector: declared on `<Entity>MockData` (single positional
  /// parameter — the same detection rule
  /// MockProviderBuilder._forMethodSelectorParamType applies), bound where
  /// the generated mock lane files call `<Entity>MockData.forMethod(
  /// params.<field>)`.
  MockExplainSelector _explainSelector(MockArtifacts artifacts) {
    String? paramType;
    if (artifacts.mockDataFile != null) {
      final content = File(
        p.join(artifacts.root, artifacts.mockDataFile!),
      ).readAsStringSync();
      final selectorRegex = RegExp(
        r'static\s+[\w$<>?,\s]+?\sforMethod\s*\(([^)]*)\)',
        multiLine: true,
      );
      final match = selectorRegex.firstMatch(content);
      if (match != null) {
        final parameterList = match.group(1)?.trim() ?? '';
        // Only a single positional parameter carries an unambiguous
        // discriminator; multi-arg and named-parameter selectors are not
        // threaded (the single-fixture shape stays in place).
        if (parameterList.isNotEmpty &&
            !parameterList.contains(',') &&
            !parameterList.contains('{') &&
            !parameterList.contains('}')) {
          final tokens = parameterList.split(RegExp(r'\s+'));
          if (tokens.length >= 2) {
            paramType = tokens.sublist(0, tokens.length - 1).join(' ').trim();
          }
        }
      }
    }

    final bindings = <Map<String, String>>[];
    final bindingRegex = RegExp(r'(\w+)MockData\.forMethod\(params\.(\w+)\)');
    for (final lane in artifacts.bindingFiles) {
      final file = File(p.join(artifacts.root, lane));
      if (!file.existsSync()) continue;
      final content = file.readAsStringSync();
      // Generated overrides carry `@override`; attribute each binding to
      // the nearest preceding override block's method name.
      final segments = content.split('@override');
      final declaredMethod = RegExp(r'^[^;{}()]*\b(\w+)\s*\(', multiLine: true);
      for (final match in bindingRegex.allMatches(content)) {
        var method = '';
        var consumed = 0;
        for (var i = 1; i < segments.length; i++) {
          consumed += '@override'.length + segments[i].length;
          if (consumed >= match.start) {
            final declared = declaredMethod.firstMatch(segments[i]);
            method = declared?.group(1) ?? '';
            break;
          }
        }
        bindings.add({
          'method': method,
          'expression':
              '${match.group(1)}MockData.forMethod('
              'params.${match.group(2)})',
          'field': match.group(2) ?? '',
          'file': lane,
        });
      }
    }
    return MockExplainSelector(
      declared: paramType != null,
      paramType: paramType,
      file: artifacts.mockDataFile,
      bindings: bindings,
    );
  }

  void _printReport(MockExplainReport report) {
    // ignore: avoid_print
    print('Mock Explain — ${report.entity}');
    // ignore: avoid_print
    print('  mock      : ${report.mockFile} (${report.mockClass ?? '-'})');
    // ignore: avoid_print
    print(
      '  interface : ${report.interfaceFile} '
      '(${report.interfaceClass ?? '-'})',
    );
    // ignore: avoid_print
    print(
      '  registry  : ${report.registryId} '
      '(${report.conforms ? 'conforms' : 'DRIFT'})',
    );
    // ignore: avoid_print
    print('  methods (${report.methods.length}):');
    for (final m in report.methods) {
      final mark = m.covered ? '✓' : '✗';
      // ignore: avoid_print
      print('    $mark ${m.name} — ${m.certification}');
    }
    // ignore: avoid_print
    print(
      '  skipped   : '
      '${report.skipped.isEmpty ? '(none)' : report.skipped.join(', ')}',
    );
    // ignore: avoid_print
    print(
      '  invented  : '
      '${report.invented.isEmpty ? '(none)' : report.invented.join(', ')}',
    );
    // ignore: avoid_print
    print(
      '  fixtures  : '
      '${report.fixtures.isEmpty ? '(none)' : report.fixtures.join(', ')}',
    );
    final selector = report.selector;
    if (selector.declared) {
      // ignore: avoid_print
      print(
        '  selector  : MockData.forMethod declared '
        '(discriminator: ${selector.paramType})',
      );
    } else {
      // ignore: avoid_print
      print(
        '  selector  : MockData.forMethod not declared '
        '(single-fixture mocks)',
      );
    }
    for (final binding in selector.bindings) {
      // ignore: avoid_print
      print(
        '    ${binding['method'] == null || binding['method']!.isEmpty ? '-' : binding['method']} '
        '→ ${binding['expression']} '
        '[${binding['file']}]',
      );
    }
  }

  void _emitRefusal({
    required bool jsonMode,
    required String entity,
    required String message,
    required String fix,
    String kind = 'missing_file',
    String? member,
    String? file,
  }) {
    if (jsonMode) {
      VerdictEnvelope.emit(
        VerdictEnvelope(
          command: 'zfa mock explain $entity',
          verdict: VerdictKind.fail,
          exitClass: exitMissing,
          subject: VerdictSubject(kind: 'mock', id: entity),
          findings: [
            VerdictFinding(kind: kind, member: member, file: file, fix: fix),
          ],
          details: {'entity': entity},
        ),
      );
      stderr.writeln(ExitProtocol.fixLine(fix));
    } else {
      // ignore: avoid_print
      print('❌ [$kind] $message');
      // ignore: avoid_print
      print(ExitProtocol.fixLine(fix));
    }
  }
}

/// Path resolution for the explain surface — injectable so tests (and the
/// capability's programmatic callers) can pin a root/output layout.
class MockExplainPaths {
  final String outputDir;

  const MockExplainPaths({this.outputDir = 'lib/src'});

  /// Resolves the entity-mode mock artifacts under [root]. Returns null when
  /// NEITHER the mock datasource nor the interface exists (nothing at all to
  /// explain); the caller refuses on a missing interface itself.
  MockArtifacts? resolve(String root, String entity) {
    final entitySnake = StringUtils.camelToSnake(entity);
    final interfacePath = p.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
      '${entitySnake}_datasource.dart',
    );
    final mockPath = p.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
      '${entitySnake}_mock_datasource.dart',
    );
    final mockDataPath = p.join(
      outputDir,
      'data',
      'mock',
      '${entitySnake}_mock_data.dart',
    );
    final mockExists = File(p.join(root, mockPath)).existsSync();
    final interfaceExists = File(p.join(root, interfacePath)).existsSync();
    if (!mockExists && !interfaceExists) return null;
    return MockArtifacts(
      root: root,
      interfacePath: interfacePath,
      interfaceClass: '${entity}DataSource',
      interfaceFile: interfaceExists ? interfacePath : null,
      mockPath: mockPath,
      mockClass: '${entity}MockDataSource',
      mockFile: mockExists ? mockPath : null,
      mockDataFile: File(p.join(root, mockDataPath)).existsSync()
          ? mockDataPath
          : null,
      bindingFiles: [if (mockExists) mockPath],
    );
  }
}

class MockArtifacts {
  final String root;
  final String interfacePath;
  final String interfaceClass;
  final String? interfaceFile;
  final String mockPath;
  final String mockClass;
  final String? mockFile;
  final String? mockDataFile;
  final List<String> bindingFiles;

  const MockArtifacts({
    required this.root,
    required this.interfacePath,
    required this.interfaceClass,
    required this.interfaceFile,
    required this.mockPath,
    required this.mockClass,
    required this.mockFile,
    required this.mockDataFile,
    required this.bindingFiles,
  });
}
