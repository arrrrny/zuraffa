/// The mock certifier (spec 1001, issue #1001): the single machinery both
/// entry points share.
///
/// - `zfa mock create <Entity> --certify` — generate, then certify via
///   [certify] and write the receipt next to the contract test.
/// - `zfa mock certify <Entity>` — re-run [certify] live (the honest
///   re-proof: registry entries are only added from a green run NOW) and
///   register the receipt in the #832 fixture registry.
///
/// Refusal semantics (errors-are-an-API): every refusal names the
/// missing precondition and its fix; a red contract is reported with the
/// sandbox's diagnostic tail, never a silent pass.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../utils/string_utils.dart';
import 'mock_cert_receipt.dart';
import 'mock_certification_sandbox.dart';
import 'mock_contract_test_writer.dart';

/// The outcome of one certification attempt.
class MockCertificationOutcome {
  const MockCertificationOutcome({
    required this.certified,
    required this.entity,
    required this.contractTestSource,
    required this.receipt,
    required this.methodNames,
    required this.logs,
  });

  final bool certified;
  final String entity;

  /// The rendered contract test (null-safe: non-null when a contract was
  /// extracted; null when certification was refused for a missing
  /// interface).
  final String? contractTestSource;

  final MockCertReceipt? receipt;
  final List<String> methodNames;
  final List<String> logs;
}

class MockCertifier {
  MockCertifier({
    MockContractTestWriter? contractWriter,
    MockCertificationSandbox? sandbox,
  }) : contractWriter = contractWriter ?? const MockContractTestWriter(),
       sandbox = sandbox ?? MockCertificationSandbox();

  final MockContractTestWriter contractWriter;
  final MockCertificationSandbox sandbox;

  /// Certify the mock for [entityName] under [projectRoot]/[outputDir]:
  ///
  /// 1. extract the interface contract (methods + signatures) from the
  ///    datasource interface on disk — refusal when absent;
  /// 2. determine the contract test source:
  ///    - [rePin] (the `create --certify` path, regenerating against the
  ///      CURRENT interface) → render a fresh contract test;
  ///    - otherwise (the `zfa mock certify` path) → run the COMMITTED
  ///      contract test bytes when they exist — interface drift breaks
  ///      their compilation, so the certification goes red instead of
  ///      silently absorbing the change (the certification is live);
  /// 3. run it in the temp sandbox (dart analyze + dart test);
  /// 4. build the `mock-cert.<Entity>.json` receipt (per-method
  ///    `satisfied`, contract digest).
  ///
  /// This does NOT write anything — the caller owns where artifacts land
  /// ([writeContractArtifacts] commits both files to the project).
  Future<MockCertificationOutcome> certify({
    required String entityName,
    required String projectRoot,
    required String outputDir,
    int? seed,
    bool rePin = false,
    bool verbose = false,
  }) async {
    final logs = <String>[];

    // 1. The mock subject must exist.
    final mockPath = MockContractTestWriter.mockDatasourcePath(
      entityName,
      outputDir,
    );
    if (!File(mockPath).existsSync()) {
      return MockCertificationOutcome(
        certified: false,
        entity: entityName,
        contractTestSource: null,
        receipt: null,
        methodNames: const [],
        logs: logs
          ..add(
            'no mock datasource at ${p.relative(mockPath, from: projectRoot)} '
            '— generate it first with '
            '`zfa mock create $entityName --certify`',
          ),
      );
    }

    // 2. The interface contract — what the interface declares NOW.
    final contract = await contractWriter.extractContract(
      entityName,
      outputDir,
    );
    if (contract == null || contract.isEmpty) {
      return MockCertificationOutcome(
        certified: false,
        entity: entityName,
        contractTestSource: null,
        receipt: null,
        methodNames: const [],
        logs: logs
          ..add(
            'no datasource interface contract found for $entityName under '
            '$outputDir — nothing to certify',
          ),
      );
    }

    // The method names the contract pins — for the re-pin path these are
    // the fresh extraction; for the committed path the COMMITTED test's
    // own pinned methods (parse them from the existing receipt when
    // present so per-method outcomes stay truthful).
    List<String> pinnedMethodNames = [for (final m in contract) m.name];

    // 3. The contract test source: committed bytes unless re-pinning.
    String contractTestSource;
    final committedTest = File(
      p.join(projectRoot, MockContractTestWriter.contractTestPath(entityName)),
    );
    final committedReceipt = loadMockCertReceipt(projectRoot, entityName);
    if (!rePin && committedTest.existsSync()) {
      contractTestSource = await committedTest.readAsString();
      final receiptMethods = committedReceipt?.methods
          .map((m) => m.key)
          .toList();
      if (receiptMethods != null && receiptMethods.isNotEmpty) {
        pinnedMethodNames = receiptMethods;
      }
      // Drift diagnostics BEFORE the red: name what changed between
      // the certified contract and the interface as it stands now.
      final receiptMethodSet = receiptMethods?.toSet() ?? <String>{};
      final currentMethodSet = contract.map((m) => m.name).toSet();
      final removed = receiptMethodSet.difference(currentMethodSet).toList()
        ..sort();
      final added = currentMethodSet.difference(receiptMethodSet).toList()
        ..sort();
      if (removed.isNotEmpty) {
        logs.add(
          'interface drift: the certified contract pins '
          '${removed.join(', ')} but the interface no longer declares '
          'them — the committed contract test goes red',
        );
      }
      if (added.isNotEmpty) {
        logs.add(
          'interface drift: the interface declares new methods '
          '(${added.join(', ')}) the certified contract does not pin — '
          're-pin with `zfa mock create $entityName --certify --force`',
        );
      }
      // Tamper check: the committed test must match the receipt's
      // recorded contract digest.
      if (committedReceipt != null &&
          committedReceipt.contractDigest.isNotEmpty &&
          committedReceipt.contractDigest !=
              MockCertReceipt.digestOf(contractTestSource)) {
        logs.add(
          'the committed contract test does not match the certified '
          'receipt digest — regenerate with '
          '`zfa mock create $entityName --certify --force`',
        );
      }
    } else {
      // Fresh pin: render the contract test for the CURRENT interface
      // (identical bytes project + sandbox).
      contractTestSource = contractWriter.render(
        entityName: entityName,
        methods: contract,
        projectRoot: projectRoot,
        outputDir: outputDir,
      );
    }

    // 4. Prove it in the sandbox.
    final run = await sandbox.run(
      entityName: entityName,
      projectRoot: projectRoot,
      outputDir: outputDir,
      contractTestSource: contractTestSource,
      methods: [
        for (final name in pinnedMethodNames)
          ContractMethod(name: name, returnType: '', paramsType: ''),
      ],
      verbose: verbose,
    );
    logs.addAll(run.logs);

    final receipt = MockCertReceipt.fromRun(
      entity: entityName,
      interfaceName: MockContractTestWriter.interfaceName(entityName),
      subjectPath: p.relative(
        MockContractTestWriter.mockDatasourcePath(entityName, outputDir),
        from: projectRoot,
      ),
      contractTestPath: MockContractTestWriter.contractTestPath(entityName),
      contractTestSource: contractTestSource,
      run: run,
      methodNames: pinnedMethodNames,
      seed: seed,
    );

    return MockCertificationOutcome(
      certified: run.analyzeClean && run.allMethodsSatisfied,
      entity: entityName,
      contractTestSource: contractTestSource,
      receipt: receipt,
      methodNames: pinnedMethodNames,
      logs: logs,
    );
  }

  /// Commit the contract test + receipt into the target project under
  /// `test/mock/<snake>/`. Returns the written files.
  Future<List<File>> writeContractArtifacts({
    required String entityName,
    required String projectRoot,
    required MockCertificationOutcome outcome,
  }) async {
    final files = <File>[];
    final source = outcome.contractTestSource;
    if (source != null) {
      final testFile = File(
        p.join(
          projectRoot,
          MockContractTestWriter.contractTestPath(entityName),
        ),
      );
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString(source);
      files.add(testFile);
    }
    final receipt = outcome.receipt;
    if (receipt != null) {
      final receiptFile = File(p.join(projectRoot, _receiptPath(entityName)));
      await receiptFile.parent.create(recursive: true);
      await receipt.writeTo(receiptFile);
      files.add(receiptFile);
    }
    return files;
  }
}

String _receiptPath(String entityName) => p.join(
  'test',
  'mock',
  StringUtils.camelToSnake(entityName),
  'mock-cert.$entityName.json',
);
