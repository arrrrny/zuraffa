/// Mock certification (issue #970): the verifiable record that makes
/// "contract-conforming" a checkable artifact.
///
/// Two halves:
///  * [MockCertificationService.certify] — computes the certification for a
///    COMPLETED generation run: which interface the run targeted, which
///    members that interface declares, which members the emitted mock
///    actually implements, and the sha256 digests of the emitted fixtures.
///    From that surface it derives the certification registry id
///    (`mock-cert:<entity>@<digest8>`, the #832 registry-id spirit).
///  * [MockCertificationService.writeReceipt] — persists the record as
///    `.zfa/receipts/mock-<entity>.json` through the existing
///    [ReceiptStore] `proof.v1` contract, so `zfa proof check` re-derives
///    every digest and fails on hand-edited mocks.
///
/// The certification is computed from the FINAL on-disk bytes (post-write),
/// never from the generator's in-memory strings — a hand-edit between
/// generation and certification is still visible to `zfa proof check`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/ast/ast_helper.dart';
import '../../../core/context/file_system.dart';
import '../../../core/project/receipt_store.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/method_extractor.dart';
import '../../../utils/string_utils.dart';
import '../../../version.dart';

/// One fixture (mock data / mock JSON) hashed into the certification.
class MockFixtureHash {
  /// Project-relative POSIX path of the fixture.
  final String path;

  /// SHA-256 (hex) of the fixture's final on-disk bytes.
  final String sha256;

  const MockFixtureHash({required this.path, required this.sha256});

  Map<String, dynamic> toJson() => {'path': path, 'sha256': sha256};
}

/// The mock-certification record for one generation run.
class MockCertification {
  /// Registry id in the #832 spirit: `mock-cert:<entity>@<digest8>` where
  /// the digest covers the certified surface (interface + method sets +
  /// fixture hashes). Deterministic: the same surface certifies to the
  /// same id.
  final String registryId;

  /// Project-relative POSIX path of the interface the mock certifies
  /// against (null for fixture-only modes: data-only, json).
  final String? interface;

  /// The interface class name (e.g. `ProductDataSource`).
  final String? interfaceClass;

  /// Project-relative POSIX path of the emitted mock that implements the
  /// interface.
  final String? mockFile;

  /// The mock class name (e.g. `ProductMockDataSource`).
  final String? mockClass;

  /// Members the interface declares, in declaration order.
  final List<String> interfaceMethods;

  /// Members the emitted mock actually implements, in declaration order.
  final List<String> implementedMethods;

  /// Interface members missing from the mock — the drift that breaks
  /// `implements`.
  final List<String> missingMethods;

  /// Mock members the interface never declared (invented surface).
  final List<String> inventedMethods;

  /// The emitted fixtures and their digests.
  final List<MockFixtureHash> fixtures;

  /// The receipt path once [MockCertificationService.writeReceipt] has
  /// persisted this certification (`.zfa/receipts/mock-<entity>.json`);
  /// null before that (and for dry runs).
  final String? receiptPath;

  const MockCertification({
    required this.registryId,
    required this.interface,
    required this.interfaceClass,
    required this.mockFile,
    required this.mockClass,
    required this.interfaceMethods,
    required this.implementedMethods,
    required this.missingMethods,
    required this.inventedMethods,
    required this.fixtures,
    this.receiptPath,
  });

  /// True when the mock implements exactly the interface surface.
  bool get conformance => missingMethods.isEmpty && inventedMethods.isEmpty;

  /// The envelope-facing view (issue #970 order 2 `certification` object).
  Map<String, dynamic> toEnvelopeJson() => {
    'registryId': registryId,
    'interface': interface,
    'interfaceMethods': List<String>.from(interfaceMethods),
    'implementedMethods': List<String>.from(implementedMethods),
    'conformance': conformance,
    // Filled by [withReceipt] after [MockCertificationService.writeReceipt]
    // persists the record; null until then (dry runs stay null).
    'receipt': receiptPath,
  };

  /// The envelope view with the receipt path filled in (issue #970 T003).
  MockCertification withReceipt(String? receiptPath) => MockCertification(
    registryId: registryId,
    interface: interface,
    interfaceClass: interfaceClass,
    mockFile: mockFile,
    mockClass: mockClass,
    interfaceMethods: interfaceMethods,
    implementedMethods: implementedMethods,
    missingMethods: missingMethods,
    inventedMethods: inventedMethods,
    fixtures: fixtures,
    receiptPath: receiptPath,
  );

  /// The receipt-facing view (embedded in the GenerationReceipt `input`).
  Map<String, dynamic> toReceiptInput() => {
    'schema': 1,
    'registry_id': registryId,
    if (interface != null) 'interface': interface,
    if (interfaceClass != null) 'interface_class': interfaceClass,
    if (mockFile != null) 'mock_file': mockFile,
    if (mockClass != null) 'mock_class': mockClass,
    'interface_methods': List<String>.from(interfaceMethods),
    'implemented_methods': List<String>.from(implementedMethods),
    'missing_methods': List<String>.from(missingMethods),
    'invented_methods': List<String>.from(inventedMethods),
    'conformance': conformance,
    'fixture_hashes': fixtures.map((f) => f.toJson()).toList(),
  };
}

/// Computes and persists mock certifications.
abstract final class MockCertificationService {
  /// Computes the certification for a COMPLETED generation of [entity].
  ///
  /// The mode flags mirror the generation run: [dataOnly] (`zfa mock
  /// data`), [jsonMode] (`zfa mock json`), [service]/[useService]
  /// (service/provider mode), [methods] (entity-CRUD mode). Everything is
  /// read from the tree under [projectRoot] (default: the current
  /// directory), so the record reflects the final on-disk state.
  static Future<MockCertification> certify({
    required String entity,
    required String outputDir,
    required List<GeneratedFile> files,
    String? projectRoot,
    bool dataOnly = false,
    bool jsonMode = false,
    String? service,
    String? domain,
    List<String> methods = const [],
    bool useService = false,
    String? repo,
    String? params,
    String? returns,
    FileSystem? fileSystem,
  }) async {
    final root = projectRoot ?? Directory.current.path;
    final fs = fileSystem ?? const DefaultFileSystem();

    // Same config the generation run used, so every path getter below
    // resolves EXACTLY like the builders resolved during generation.
    final config = GeneratorConfig(
      name: entity,
      outputDir: outputDir,
      service: service,
      domain: domain,
      methods: methods,
      useService: useService,
      repo: repo,
      paramsType: params,
      returnsType: returns,
      generateMockDataOnly: dataOnly,
      generateMockJson: jsonMode,
    );

    final entitySnake = StringUtils.camelToSnake(entity);
    final hasService = service != null || useService;

    // 1. Resolve the interface/mock pair for the mode.
    String? interfacePath;
    String? interfaceClass;
    String? mockPath;
    String? mockClass;
    if (!dataOnly && !jsonMode) {
      if (hasService) {
        final serviceName = config.effectiveService;
        final serviceSnake = config.serviceSnake;
        final providerName = config.effectiveProvider;
        if (serviceName != null &&
            serviceSnake != null &&
            providerName != null) {
          interfaceClass = serviceName;
          // Mirrors MockProviderBuilder's import resolution.
          interfacePath = config.isEntityBased
              ? p.join(
                  outputDir,
                  'domain',
                  'services',
                  config.effectiveDomain,
                  '${serviceSnake}_service.dart',
                )
              : p.join(
                  outputDir,
                  'domain',
                  'services',
                  '${serviceSnake}_service.dart',
                );
          final mockProviderName = providerName.replaceAll(
            'Provider',
            'MockProvider',
          );
          mockClass = mockProviderName;
          mockPath = p.join(
            outputDir,
            'data',
            'providers',
            config.effectiveDomain,
            '${StringUtils.camelToSnake(mockProviderName)}.dart',
          );
        }
      } else {
        // Mirrors MockBuilder's interface-entity resolution.
        final interfaceEntity = repo != null
            ? repo.replaceAll('Repository', '')
            : entity;
        final interfaceSnake = StringUtils.camelToSnake(interfaceEntity);
        interfaceClass = '${interfaceEntity}DataSource';
        interfacePath = p.join(
          outputDir,
          'data',
          'datasources',
          interfaceSnake,
          '${interfaceSnake}_datasource.dart',
        );
        mockClass = '${interfaceEntity}MockDataSource';
        mockPath = p.join(
          outputDir,
          'data',
          'datasources',
          interfaceSnake,
          '${interfaceSnake}_mock_datasource.dart',
        );
      }
    }

    // 2. Interface members (AST — no package resolution needed).
    var interfaceMethods = const <String>[];
    if (interfacePath != null && interfaceClass != null) {
      final abs = _absolute(root, interfacePath);
      if (await fs.exists(abs)) {
        final parsed = await MethodExtractor.extractMethodsFromInterface(
          abs,
          interfaceClass,
          fileSystem: fs,
        );
        interfaceMethods = parsed.map((m) => m.fieldName).toList();
      }
    }

    // 3. Implemented members (AST parse of the emitted mock class).
    var implementedMethods = const <String>[];
    if (mockPath != null && mockClass != null) {
      final abs = _absolute(root, mockPath);
      if (await fs.exists(abs)) {
        final helper = const AstHelper();
        final parseResult = await helper.parseFile(abs, fileSystem: fs);
        final unit = parseResult.unit;
        if (unit != null) {
          final classNode = helper.findClass(unit, mockClass);
          if (classNode != null) {
            implementedMethods = helper
                .findMethods(classNode)
                .map((m) => m.name.toString())
                .toList();
          }
        }
      }
    }

    // 4. Fixture digests from the FINAL on-disk bytes.
    final fixtures = <MockFixtureHash>[];
    for (final file in files) {
      final isFixture = file.type == 'mock_data' || file.type == 'mock_json';
      if (!isFixture) continue;
      final abs = _absolute(root, file.path);
      if (!await fs.exists(abs)) continue;
      final content = await fs.read(abs);
      final bytes = utf8.encode(content);
      fixtures.add(
        MockFixtureHash(
          path: _projectRelativePosix(root, file.path),
          sha256: crypto.sha256.convert(bytes).toString(),
        ),
      );
    }

    // 5. Drift sets.
    final interfaceSet = interfaceMethods.toSet();
    final implementedSet = implementedMethods.toSet();
    final missing = [
      for (final m in interfaceMethods)
        if (!implementedSet.contains(m)) m,
    ];
    final invented = [
      for (final m in implementedMethods)
        if (!interfaceSet.contains(m)) m,
    ];

    // 6. The registry id: a digest over the certified surface.
    final surface = jsonEncode({
      'entity': entitySnake,
      'interface': interfacePath,
      'interface_methods': interfaceMethods,
      'implemented_methods': implementedMethods,
      'fixtures': [
        for (final f in fixtures) {'path': f.path, 'sha256': f.sha256},
      ],
    });
    final digest8 = crypto.sha256
        .convert(utf8.encode(surface))
        .toString()
        .substring(0, 8);

    return MockCertification(
      registryId: 'mock-cert:$entitySnake@$digest8',
      interface: interfacePath == null
          ? null
          : _projectRelativePosix(root, interfacePath),
      interfaceClass: interfaceClass,
      mockFile: mockPath == null ? null : _projectRelativePosix(root, mockPath),
      mockClass: mockClass,
      interfaceMethods: interfaceMethods,
      implementedMethods: implementedMethods,
      missingMethods: missing,
      inventedMethods: invented,
      fixtures: fixtures,
    );
  }

  /// Persists the mock-certification receipt as
  /// `.zfa/receipts/mock-<entity>.json` (schema `proof.v1`), reusing the
  /// existing [ReceiptStore]. Every emitted artifact that exists on disk is
  /// digest-bound, so `zfa proof check` re-derives the proof and a
  /// hand-edit fails the check.
  ///
  /// Returns the project-relative receipt path, or null when nothing was
  /// emitted to disk (dry run / empty run).
  static Future<String?> writeReceipt({
    required String projectRoot,
    required String entity,
    required String commandLine,
    required MockCertification certification,
    required List<GeneratedFile> files,
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    final receiptFiles = <GenerationReceiptFile>[];
    for (final file in files) {
      final abs = _absolute(projectRoot, file.path);
      if (!await fs.exists(abs)) continue;
      final content = await fs.read(abs);
      final bytes = utf8.encode(content);
      final keepSnapshot = bytes.length <= ReceiptStore.maxSnapshotBytes;
      receiptFiles.add(
        GenerationReceiptFile(
          path: _projectRelativePosix(projectRoot, file.path),
          action: _receiptAction(file.action),
          sha256: crypto.sha256.convert(bytes).toString(),
          bytes: bytes.length,
          snapshot: keepSnapshot ? content : null,
        ),
      );
    }
    if (receiptFiles.isEmpty) return null;

    final entitySnake = StringUtils.camelToSnake(entity);
    final receipt = GenerationReceipt(
      command: commandLine,
      target: entity,
      repro: commandLine,
      at: DateTime.now().toUtc(),
      generatorVersion: version,
      input: {'certification': certification.toReceiptInput()},
      files: receiptFiles,
    );
    final store = ReceiptStore(projectRoot: projectRoot);
    final written = await store.saveAs('mock-$entitySnake.json', receipt);
    return _projectRelativePosix(projectRoot, written.path);
  }

  /// Normalizes GenerationFile actions into the receipt's action family.
  static String _receiptAction(String action) {
    switch (action) {
      case 'created':
        return 'create';
      case 'overwritten':
      case 'updated':
        return 'modify';
      case 'deleted':
        return 'delete';
      default:
        return 'create';
    }
  }

  static String _absolute(String root, String path) =>
      p.isAbsolute(path) ? path : p.join(root, path);

  static String _projectRelativePosix(String root, String path) {
    final rel = p.isAbsolute(path) ? p.relative(path, from: root) : path;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}

/// The scoped `dart analyze` runner: (files, workingDirectory) →
/// (exitCode, output). Production spawns the real subprocess; the fast
/// test tier injects a deterministic fake through
/// [MockCertifier.analyzeRunnerOverride] (the realize_command seam
/// pattern).
typedef MockAnalyzeRunner =
    Future<({int exitCode, String output})> Function(
      List<String> files,
      String workingDirectory,
    );

/// The verdict of one `--certify` gate run: passed, or the `--> fix:`
/// lines naming the missing/incorrect members (issue #970 order 4).
class CertifyReport {
  /// True when the mock conforms to its interface AND the scoped analyze
  /// over the emitted mock files is clean.
  final bool passed;

  /// One line per finding, each starting with `--> fix:`.
  final List<String> fixLines;

  const CertifyReport({required this.passed, required this.fixLines});
}

/// `zfa mock create <Entity> --certify` (issue #970 T004): the gate that
/// makes "contract-conforming" a refused-not-claimed property.
///
/// Two checks, either failing → exit 1 with fix lines:
///  1. Structural conformance (AST, deterministic): the interface's
///     members vs the mock class's implemented members — precise member
///     names, no package resolution required.
///  2. A scoped `dart analyze` over the emitted mock files (cwd = the
///     project root) — the authoritative compiler verdict; its errors are
///     surfaced verbatim as fix lines.
class MockCertifier {
  /// Test seam: when non-null, used instead of the real analyze
  /// subprocess. Static per-isolate — `dart test` runs each file in its
  /// own isolate, so the override never leaks across files.
  static MockAnalyzeRunner? analyzeRunnerOverride;

  static MockAnalyzeRunner get _defaultRunner =>
      (files, workingDirectory) async {
        final result = await Process.run('dart', [
          'analyze',
          ...files,
        ], workingDirectory: workingDirectory);
        return (
          exitCode: result.exitCode,
          output: '${result.stdout}${result.stderr}',
        );
      };

  /// Runs the gate for [certification] under [projectRoot].
  Future<CertifyReport> gate({
    required MockCertification certification,
    required String projectRoot,
    MockAnalyzeRunner? analyzeRunner,
  }) async {
    final fixes = <String>[];
    final interfaceName =
        certification.interfaceClass ?? 'the declared interface';

    // 1. Structural drift: interface members the mock never implemented.
    if (certification.missingMethods.isNotEmpty) {
      fixes.add(
        '--> fix: implement the missing $interfaceName member(s): '
        '${certification.missingMethods.join(', ')}',
      );
    }
    // 2. Structural drift: invented surface the interface never declared.
    if (certification.inventedMethods.isNotEmpty) {
      fixes.add(
        '--> fix: correct the member(s) ${certification.mockClass ?? 'the '
                'mock'} does not declare in $interfaceName: '
        '${certification.inventedMethods.join(', ')}',
      );
    }

    // 3. Scoped dart analyze over the emitted mock files.
    final analyzeFiles = <String>[
      if (certification.mockFile != null) certification.mockFile!,
      if (certification.interface != null) certification.interface!,
      for (final fixture in certification.fixtures)
        if (fixture.path.endsWith('.dart')) fixture.path,
    ];
    if (analyzeFiles.isNotEmpty) {
      final runner = analyzeRunner ?? analyzeRunnerOverride ?? _defaultRunner;
      final result = await runner(analyzeFiles, projectRoot);
      if (result.exitCode != 0) {
        for (final line in result.output.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('error -')) {
            fixes.add('--> fix: ${trimmed.substring('error -'.length).trim()}');
          }
        }
        if (!result.output.contains('error -')) {
          // Non-zero exit without parseable error lines (e.g. a crash):
          // surface the raw tail instead of staying silent.
          final tail = result.output.trim().isEmpty
              ? '(no output, exit ${result.exitCode})'
              : result.output.trim();
          fixes.add(
            '--> fix: dart analyze over the emitted mock files '
            'failed (exit ${result.exitCode}): $tail',
          );
        }
      }
    }

    return CertifyReport(passed: fixes.isEmpty, fixLines: fixes);
  }
}
