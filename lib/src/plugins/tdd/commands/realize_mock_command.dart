/// `zfa tdd realize-mock <Entity> --against=firestore` — the differential
/// gate (spec 1009, issue #1009, epic #1014 MOCK-CERTIFICATION).
///
/// The same Tier-1 contract test runs against two subjects:
///
/// 1. **Tier-1** — the committed mock (the contract test's own bytes,
///    unchanged: `zfa mock create <Entity> --certify` committed them);
/// 2. **Tier-2** — a generated Firestore-shaped `Tier2MockProvider`
///    implementing the SAME `<Entity>DataSource` interface behind a fake
///    in-memory `FirebaseFirestore`, swapped into the contract test as
///    the subject ([Tier2FirestoreAdapterWriter.swapSubject] — every pin
///    stays byte-identical).
///
/// Both runs execute in a throwaway sandbox (dart pub get + dart analyze +
/// dart test, the spec-1001 [MockCertificationSandbox]) and the per-method
/// outcomes are compared. Divergence = failure; same green result =
/// certified. The receipt `realize.<Entity>.firestore.receipt.json` is
/// written next to the contract artifacts with per-method
/// `{method, tier1_result, tier2_result, diff}`, and a `proof.v1`
/// generation receipt covers its bytes in `.zfa/receipts/` so
/// `zfa proof check` re-derives the digest (machine-readable + verified).
///
/// Attribution honesty (the [ContractGate] lesson): a red Tier-1 baseline
/// is NEVER blamed on the Tier-2 adapter — the gate refuses with
/// result=tier1-red (exit 2) and the fix hint, because a broken baseline
/// cannot certify anything. Only a green Tier-1 side + failing Tier-2 side
/// is a divergence (exit 1, the methods are named).
///
/// Machine contract (house convention): the LAST stdout line is
///
///     realize-mock: entity=<E> against=<a> methods=<n> tier1-green=<n>
///                   tier2-green=<n> diff-none=<n> mismatch=<n>
///                   [divergence=<m1,m2>] result=<certified|mismatch|tier1-red>
///
/// Exit codes: 0 certified (all methods green on both sides, diff none),
/// 1 mismatch (at least one method diverges — named), 2 refusal (usage,
/// missing contract test, unsupported --against, red Tier-1 baseline).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../../../core/project/receipt_store.dart';
import '../../mock/certification/mock_certification_sandbox.dart';
import '../../mock/certification/mock_contract_test_writer.dart';
import '../models/realize_mock_receipt.dart';
import '../services/tier2_firestore_adapter_writer.dart';
import '../tdd_plugin.dart';

/// The per-tier sandbox runner (injectable for fast-tier tests — the
/// RealizeCommand suite-runner pattern). [tier] is `tier1` or `tier2`.
typedef RealizeMockSandboxRunner =
    Future<MockCertificationRun> Function({
      required String tier,
      required String entityName,
      required String projectRoot,
      required String outputDir,
      required String contractTestSource,
      required List<ContractMethod> methods,
      Map<String, String>? extraFiles,
    });

class RealizeMockCommand extends Command<void> {
  RealizeMockCommand(this.plugin, {RealizeMockSandboxRunner? sandboxRunner})
    : _sandboxRunnerOverride = sandboxRunner {
    argParser.addOption(
      'against',
      help:
          'The Tier-2 adapter backend the mock is realized against for the '
          'differential comparison. Currently supported: firestore. '
          'Required.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, lib/, test/. Defaults to the '
          'current working directory.',
    );
    argParser.addOption(
      'diverge',
      valueHelp: 'method',
      help:
          'Chaos hook (issue #1009 exit criterion): force the named '
          'interface method to diverge on the Tier-2 side (wrong-typed '
          'return). Proves the gate catches divergence — the run exits 1 '
          'naming the method.',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Print the sandbox diagnostic tails.',
    );
  }

  final TddPlugin plugin;

  final RealizeMockSandboxRunner? _sandboxRunnerOverride;

  static const _exitOk = 0;
  static const _exitMismatch = 1;
  static const _exitRefused = 2;

  /// The only supported Tier-2 backend (issue #1009: `--against=firestore`).
  static const supportedBackends = {'firestore'};

  @override
  String get name => 'realize-mock';

  @override
  String get description =>
      'Differential gate: run the Tier-1 contract test against the mock '
      'AND a Firestore-shaped Tier-2 adapter, compare per-method results, '
      'write realize.<Entity>.firestore.receipt.json (spec 1009).';

  @override
  String get invocation =>
      'zfa tdd realize-mock <Entity> --against=firestore [options]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    final entity = rest.isNotEmpty ? rest.first.trim() : '';
    final against = (argResults?['against'] as String?)?.trim() ?? '';
    final projectFlag = (argResults?['project'] as String?)?.trim() ?? '';
    final diverge = (argResults?['diverge'] as String?)?.trim() ?? '';
    final verbose = argResults?['verbose'] == true;

    if (entity.isEmpty) {
      _fail(
        'zfa tdd realize-mock: an entity name is required. '
        'Usage: $invocation',
        entity: '-',
        against: against.isEmpty ? '-' : against,
        summary: 'missing-entity',
      );
      return;
    }
    if (against.isEmpty) {
      _fail(
        'zfa tdd realize-mock: --against <backend> is required. '
        'Supported: ${supportedBackends.join(', ')}.',
        entity: entity,
        against: '-',
        summary: 'missing-against',
      );
      return;
    }
    if (!supportedBackends.contains(against)) {
      _fail(
        'zfa tdd realize-mock: unsupported --against "$against". '
        'Supported: ${supportedBackends.join(', ')}.',
        entity: entity,
        against: against,
        summary: 'unsupported-against',
      );
      return;
    }

    final projectRoot = projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final outputDir = p.join(projectRoot, 'lib', 'src');

    // ---------------------------------------------------------------
    // The Tier-1 subjects must exist: the committed contract test (the
    // differential loads IT, not a re-render) + the mock datasource it
    // pins + the interface.
    // ---------------------------------------------------------------
    final contractTestPath = p.join(
      projectRoot,
      MockContractTestWriter.contractTestPath(entity),
    );
    if (!File(contractTestPath).existsSync()) {
      _fail(
        'zfa tdd realize-mock: no committed Tier-1 contract test at '
        '${p.relative(contractTestPath, from: projectRoot)} — the '
        'differential gate loads the certified contract, it never '
        're-renders it.\n'
        '--> fix: zfa mock create $entity --certify first, then re-run.',
        entity: entity,
        against: against,
        summary: 'missing-contract-test',
      );
      return;
    }
    final mockPath = MockContractTestWriter.mockDatasourcePath(
      entity,
      outputDir,
    );
    if (!File(mockPath).existsSync()) {
      _fail(
        'zfa tdd realize-mock: no Tier-1 mock datasource at '
        '${p.relative(mockPath, from: projectRoot)}.\n'
        '--> fix: zfa mock create $entity --certify first, then re-run.',
        entity: entity,
        against: against,
        summary: 'missing-mock',
      );
      return;
    }

    final contract = await const MockContractTestWriter().extractContract(
      entity,
      outputDir,
    );
    if (contract == null || contract.isEmpty) {
      _fail(
        'zfa tdd realize-mock: no datasource interface contract found for '
        '$entity under ${p.relative(outputDir, from: projectRoot)} — '
        'nothing to compare.',
        entity: entity,
        against: against,
        summary: 'missing-interface',
      );
      return;
    }

    // The divergence hook must name a real, Future-returning method (a
    // divergent Stream would hang the contract's `.first` await).
    if (diverge.isNotEmpty) {
      final named = contract.where((m) => m.name == diverge).toList();
      if (named.isEmpty) {
        _fail(
          'zfa tdd realize-mock: --diverge "$diverge" names no method of '
          'the ${MockContractTestWriter.interfaceName(entity)} contract '
          '(${contract.map((m) => m.name).join(', ')}).',
          entity: entity,
          against: against,
          summary: 'unknown-diverge-method',
        );
        return;
      }
      if (named.first.returnType.startsWith('Stream<')) {
        _fail(
          'zfa tdd realize-mock: --diverge "$diverge" is Stream-returning — '
          'divergence injection is Future-only (a divergent stream would '
          'hang the contract test).',
          entity: entity,
          against: against,
          summary: 'stream-diverge-refused',
        );
        return;
      }
    }

    final contractTestSource = await File(contractTestPath).readAsString();
    final runner = _sandboxRunner();

    print('zfa tdd realize-mock: entity $entity --against $against');
    print(
      '   contract: ${p.relative(contractTestPath, from: projectRoot)} '
      '(${contract.length} method(s))',
    );

    // ---------------------------------------------------------------
    // Tier 1: the committed contract test against the mock, unchanged.
    // ---------------------------------------------------------------
    final tier1 = await runner(
      tier: 'tier1',
      entityName: entity,
      projectRoot: projectRoot,
      outputDir: outputDir,
      contractTestSource: contractTestSource,
      methods: contract,
    );

    // ---------------------------------------------------------------
    // Tier 2: the same pins with the Tier-2 Firestore-shaped provider
    // swapped in as the subject.
    // ---------------------------------------------------------------
    final adapterSource = const Tier2FirestoreAdapterWriter().render(
      entityName: entity,
      methods: contract,
      outputDir: outputDir,
      divergeMethod: diverge.isEmpty ? null : diverge,
    );
    final swappedTest = Tier2FirestoreAdapterWriter.swapSubject(
      entityName: entity,
      contractTestSource: contractTestSource,
    );
    final tier2 = await runner(
      tier: 'tier2',
      entityName: entity,
      projectRoot: projectRoot,
      outputDir: outputDir,
      contractTestSource: swappedTest,
      methods: contract,
      extraFiles: {
        Tier2FirestoreAdapterWriter.adapterRelPath(entity): adapterSource,
      },
    );

    if (verbose) {
      _printTail('tier-1', tier1.logs);
      _printTail('tier-2', tier2.logs);
    }

    // ---------------------------------------------------------------
    // The receipt: per-method comparison, committed next to the
    // contract artifacts, covered by a proof.v1 generation receipt.
    // ---------------------------------------------------------------
    final receipt = RealizeMockReceipt(
      entity: entity,
      interfaceName: MockContractTestWriter.interfaceName(entity),
      against: against,
      contractTestPath: MockContractTestWriter.contractTestPath(entity),
      contractDigest: RealizeMockReceipt.digestOf(contractTestSource),
      tier2Subject: Tier2FirestoreAdapterWriter.providerClassName(entity),
      tier2TestDigest: RealizeMockReceipt.digestOf(swappedTest),
      methods: [
        for (final m in contract)
          RealizeMockMethodResult(
            method: m.name,
            tier1Passed: tier1.methodOutcomes[m.name] ?? false,
            tier2Passed: tier2.methodOutcomes[m.name] ?? false,
          ),
      ],
      sandbox: {
        'tier1': _sandboxEvidence(tier1),
        'tier2': _sandboxEvidence(tier2),
        if (diverge.isNotEmpty) 'diverge': diverge,
      },
    );

    final receiptFile = File(
      p.join(projectRoot, realizeMockReceiptPath(entity, against)),
    );
    await receipt.writeTo(receiptFile);
    print('   receipt: ${p.relative(receiptFile.path, from: projectRoot)}');

    await _receiptProof(
      projectRoot: projectRoot,
      entity: entity,
      against: against,
      receiptFile: receiptFile,
      diverge: diverge,
    );

    // ---------------------------------------------------------------
    // The gate verdict (attribution-honest, per-entity).
    // ---------------------------------------------------------------
    switch (receipt.gate) {
      case RealizeMockGate.mismatch:
        print(
          '   differential gate MISMATCH: the Tier-2 ($against) adapter '
          'diverges from the Tier-1 mock on: '
          '${receipt.divergences.join(', ')}',
        );
        if (!verbose) {
          _printTail('tier-2', tier2.logs);
        }
        _printSummary(
          entity: entity,
          against: against,
          receipt: receipt,
          result: receipt.gate.label,
        );
        exitCode = _exitMismatch;
      case RealizeMockGate.tier1Red:
        print(
          '   differential gate BLOCKED: the Tier-1 contract itself is red '
          '(${receipt.tier1Failures.join(', ')}) — a broken baseline '
          'cannot certify anything; this is not the Tier-2 adapter\'s '
          'fault.',
        );
        print(
          '--> fix: zfa mock create $entity --certify (or zfa mock certify '
          '$entity), then re-run.',
        );
        if (!verbose) {
          _printTail('tier-1', tier1.logs);
        }
        _printSummary(
          entity: entity,
          against: against,
          receipt: receipt,
          result: receipt.gate.label,
        );
        exitCode = _exitRefused;
      case RealizeMockGate.certified:
        print(
          '   differential gate pass: ${receipt.methods.length} method(s) '
          'green on both tiers, diff none — the $against-shaped Tier-2 '
          'adapter satisfies the same contract as the Tier-1 mock.',
        );
        _printSummary(
          entity: entity,
          against: against,
          receipt: receipt,
          result: receipt.gate.label,
        );
        exitCode = _exitOk;
    }
  }

  void _fail(
    String message, {
    required String entity,
    required String against,
    required String summary,
  }) {
    stderr.writeln(message);
    print(
      'realize-mock: entity=$entity against=$against methods=0 '
      'tier1-green=0 tier2-green=0 diff-none=0 mismatch=0 '
      'result=$summary',
    );
    exitCode = _exitRefused;
  }

  static Map<String, dynamic> _sandboxEvidence(MockCertificationRun run) => {
    'runner': run.runner,
    'analyze_issues': run.analyzeIssues,
    'analyze_errors': run.analyzeErrors,
    'tests_passed': run.passedTests.length,
    'tests_failed': run.failedTests.length,
  };

  static void _printTail(String tier, List<String> logs) {
    for (final line in logs) {
      print('   [$tier] $line');
    }
  }

  void _printSummary({
    required String entity,
    required String against,
    required RealizeMockReceipt receipt,
    required String result,
  }) {
    final tier1Green = receipt.methods.where((m) => m.tier1Passed).length;
    final tier2Green = receipt.methods.where((m) => m.tier2Passed).length;
    final diffNone = receipt.methods.where((m) => m.diff == 'none').length;
    print(
      'realize-mock: entity=$entity against=$against '
      'methods=${receipt.methods.length} tier1-green=$tier1Green '
      'tier2-green=$tier2Green diff-none=$diffNone '
      'mismatch=${receipt.divergences.length}'
      '${receipt.divergences.isEmpty ? '' : ' divergence=${receipt.divergences.join(',')}'} '
      'result=$result',
    );
  }

  /// Write the #807 proof.v1 generation receipt covering the differential
  /// receipt's bytes, so `zfa proof check` re-derives its digest.
  Future<void> _receiptProof({
    required String projectRoot,
    required String entity,
    required String against,
    required File receiptFile,
    required String diverge,
  }) async {
    final bytes = await receiptFile.readAsBytes();
    await ReceiptStore(projectRoot: projectRoot).save(
      GenerationReceipt(
        command: 'zfa tdd realize-mock',
        target: entity,
        repro:
            'zfa tdd realize-mock $entity --against=$against'
            '${diverge.isEmpty ? '' : ' --diverge $diverge'}',
        at: DateTime.now().toUtc(),
        generatorVersion: '6.1.0',
        input: {
          'entity': entity,
          'against': against,
          if (diverge.isNotEmpty) 'diverge': diverge,
        },
        files: [
          GenerationReceiptFile(
            path: p
                .relative(receiptFile.path, from: projectRoot)
                .replaceAll('\\', '/'),
            action: 'create',
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
          ),
        ],
      ),
    );
  }

  /// The sandbox runner: injected for fast-tier tests; the real
  /// [MockCertificationSandbox] in production.
  RealizeMockSandboxRunner _sandboxRunner() {
    final override = _sandboxRunnerOverride;
    if (override != null) return override;
    final sandbox = MockCertificationSandbox();
    return ({
      required tier,
      required entityName,
      required projectRoot,
      required outputDir,
      required contractTestSource,
      required methods,
      extraFiles,
    }) async => sandbox.run(
      entityName: entityName,
      projectRoot: projectRoot,
      outputDir: outputDir,
      contractTestSource: contractTestSource,
      methods: methods,
      extraFiles: extraFiles ?? const {},
    );
  }
}
