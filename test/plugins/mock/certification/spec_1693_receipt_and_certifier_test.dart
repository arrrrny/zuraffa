// Spec 1693 (issue #1693) — the receipt-model + certifier half of the
// format-canonical mock cert digest.
//
// The gate half (spec_1693_gate_format_drift_test.dart) drives
// `CertRegistry.checkEntity` with hand-written receipt JSON so the
// behavioral red predates the seam. This file pins the NEW seam itself:
//
//   - `MockCertReceipt.entityDigest` — the recorded format-canonical
//     entity digest, JSON `entity_digest`, omitted for receipts without
//     one (pre-1693 byte stability);
//   - `MockCertifier.certify` — records the digest of the entity source
//     it certified (computed through the lib-side
//     `formatCanonicalDigest` helper), for both entry points
//     (`mock create --certify` and `mock certify` share `certify`).
//
// The certifier's sandbox is stubbed (green run, no toolchain
// subprocess) — the sandbox itself is not this spec's surface.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/certification/format_canonical_digest.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_cert_receipt.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certification_sandbox.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certifier.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_contract_test_writer.dart';

/// A green sandbox run without any subprocess — the certification
/// PROOF is not this spec's surface; only the digest recording is.
class _GreenSandbox extends MockCertificationSandbox {
  _GreenSandbox();

  @override
  Future<MockCertificationRun> run({
    required String entityName,
    required String projectRoot,
    required String outputDir,
    required String contractTestSource,
    required List<ContractMethod> methods,
    bool verbose = false,
  }) async {
    return MockCertificationRun(
      analyzeIssues: 0,
      analyzeErrors: 0,
      passedTests: const ['mock contract get'],
      failedTests: const [],
      methodOutcomes: {for (final m in methods) m.name: true},
      runner: 'dart',
      logs: const ['_GreenSandbox: stubbed green run'],
    );
  }
}

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  /// The certified shape of the entity source — format-clean.
  const certifiedSource = '''
class Login {
  final String id;
  final String username;
  const Login({required this.id, required this.username});
}
''';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1693_receipt_');
    projectRoot = tempDir.path;
    outputDir = p.join(projectRoot, 'lib', 'src');

    // The entity the receipt certifies.
    final entityFile = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'domain',
        'entities',
        'login',
        'login.dart',
      ),
    );
    entityFile.createSync(recursive: true);
    entityFile.writeAsStringSync(certifiedSource);

    // The datasource interface the contract pins.
    final interfaceFile = File(
      p.join(
        outputDir,
        'data',
        'datasources',
        'login',
        'login_datasource.dart',
      ),
    );
    interfaceFile.createSync(recursive: true);
    interfaceFile.writeAsStringSync('''
abstract interface class LoginDataSource {
  Future<Login> get(Login item);
  Future<Login> update(Login item);
}
''');

    // The mock datasource whose certification is proven.
    final mockFile = File(
      p.join(
        outputDir,
        'data',
        'datasources',
        'login',
        'login_mock_datasource.dart',
      ),
    );
    mockFile.createSync(recursive: true);
    mockFile.writeAsStringSync('// GENERATED - DO NOT EDIT\n');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MockCertReceipt (spec 1693, the recorded entity digest)', () {
    test('G6: entity_digest roundtrips through toJson/fromJson', () {
      final receipt = MockCertReceipt(
        entity: 'Login',
        interfaceName: 'LoginDataSource',
        subjectPath:
            'lib/src/data/datasources/login/'
            'login_mock_datasource.dart',
        contractTestPath: 'test/mock/login/login_mock_contract_test.dart',
        contractDigest: 'deadbeef',
        entityDigest:
            'cafebabecafebabecafebabecafebabecafebabecafebabe'
            'cafebabecafebabe',
        methods: const [MapEntry('get', true)],
        sandbox: const {'runner': 'dart'},
        seed: 42,
      );

      final json = receipt.toJson();
      expect(json['entity_digest'], isNotNull);
      final restored = MockCertReceipt.fromJson(json);
      expect(
        restored!.entityDigest,
        receipt.entityDigest,
        reason:
            'the gate compares the RECORDED digest — it must survive '
            'the disk roundtrip',
      );
    });

    test('G6b: a receipt without an entity digest omits the JSON key '
        '(pre-1693 receipts stay byte-stable)', () {
      final receipt = MockCertReceipt(
        entity: 'Login',
        interfaceName: 'LoginDataSource',
        subjectPath:
            'lib/src/data/datasources/login/'
            'login_mock_datasource.dart',
        contractTestPath: 'test/mock/login/login_mock_contract_test.dart',
        contractDigest: 'deadbeef',
        methods: const [MapEntry('get', true)],
        sandbox: const {'runner': 'dart'},
        seed: 42,
      );

      expect(receipt.toJson().containsKey('entity_digest'), isFalse);
      // And a pre-1693 receipt on disk still parses, digest-less.
      final legacy = MockCertReceipt.fromJson(receipt.toJson());
      expect(legacy!.entityDigest, isNull);
    });

    test('G7: fromRun records the digest when given, omits when null', () {
      final withDigest = MockCertReceipt.fromRun(
        entity: 'Login',
        interfaceName: 'LoginDataSource',
        subjectPath:
            'lib/src/data/datasources/login/'
            'login_mock_datasource.dart',
        contractTestPath: 'test/mock/login/login_mock_contract_test.dart',
        contractTestSource: 'void main() {}',
        run: MockCertificationRun(
          analyzeIssues: 0,
          analyzeErrors: 0,
          passedTests: const ['get'],
          failedTests: const [],
          methodOutcomes: const {'get': true},
          runner: 'dart',
          logs: const [],
        ),
        methodNames: const ['get'],
        entityDigest: 'f00dfeed',
      );
      expect(withDigest.entityDigest, 'f00dfeed');

      final withoutDigest = MockCertReceipt.fromRun(
        entity: 'Login',
        interfaceName: 'LoginDataSource',
        subjectPath:
            'lib/src/data/datasources/login/'
            'login_mock_datasource.dart',
        contractTestPath: 'test/mock/login/login_mock_contract_test.dart',
        contractTestSource: 'void main() {}',
        run: MockCertificationRun(
          analyzeIssues: 0,
          analyzeErrors: 0,
          passedTests: const ['get'],
          failedTests: const [],
          methodOutcomes: const {'get': true},
          runner: 'dart',
          logs: const [],
        ),
        methodNames: const ['get'],
      );
      expect(withoutDigest.entityDigest, isNull);
    });
  });

  group('MockCertifier.certify (spec 1693, digest recorded at cert time)', () {
    test('G8: certify records the format-canonical digest of the entity '
        'source; the written receipt carries entity_digest', () async {
      final certifier = MockCertifier(sandbox: _GreenSandbox());
      final outcome = await certifier.certify(
        entityName: 'Login',
        projectRoot: projectRoot,
        outputDir: outputDir,
      );

      expect(outcome.certified, isTrue, reason: outcome.logs.join('\n'));
      final receipt = outcome.receipt;
      expect(receipt, isNotNull);
      expect(
        receipt!.entityDigest,
        formatCanonicalDigest(certifiedSource),
        reason:
            'the recorded digest must be the lib-side canonical '
            'digest of the entity source bytes',
      );

      // The committed receipt JSON carries the recorded digest.
      final files = await certifier.writeContractArtifacts(
        entityName: 'Login',
        projectRoot: projectRoot,
        outcome: outcome,
      );
      final receiptFile = files.where(
        (f) => f.path.endsWith('mock-cert.Login.json'),
      );
      expect(receiptFile, isNotEmpty);
      final doc =
          jsonDecode(receiptFile.single.readAsStringSync())
              as Map<String, dynamic>;
      expect(doc['entity_digest'], receipt.entityDigest);
    });

    test('G8b: certify without an entity file records NO digest '
        '(honest absence — the gate falls back to mtime)', () async {
      File(
        p.join(
          projectRoot,
          'lib',
          'src',
          'domain',
          'entities',
          'login',
          'login.dart',
        ),
      ).deleteSync();

      final certifier = MockCertifier(sandbox: _GreenSandbox());
      final outcome = await certifier.certify(
        entityName: 'Login',
        projectRoot: projectRoot,
        outputDir: outputDir,
      );

      expect(outcome.certified, isTrue, reason: outcome.logs.join('\n'));
      expect(outcome.receipt!.entityDigest, isNull);
    });
  });
}
