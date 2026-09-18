// Spec 1693 (issue #1693) — the receipt-model + certifier half of the
// format-canonical mock cert digest.
//
// The gate half (spec_1693_gate_format_drift_test.dart) drives
// `CertRegistry.checkEntity` with hand-written receipt JSON so the
// behavioral red predates the seam. This file pins the NEW seam itself:
//
//   - `MockCertReceipt.entityDigest` — the recorded format-canonical
//     entity digest, JSON `entity_digest`, omitted for receipts without
//     one (pre-1693 byte stability), plus `entityDigestStyle` — the
//     canonicalizer identity the gate matches before trusting it
//     (JSON `entity_digest_style`);
//   - `MockCertifier.certify` — records the digest of the entity source
//     it certified (computed through the lib-side
//     `formatCanonicalDigest` helper) and resolves that source through
//     `CertRegistry.locateEntityFile`, the SAME resolver the gate reads
//     with, for both entry points (`mock create --certify` and
//     `mock certify` share `certify`);
//   - `format_canonical_digest.dart` — the helper itself is TOTAL (a
//     `dart_style` failure of any type reads as "no digest") and accepts
//     a null file, so the recording call site stays one expression.
//
// The certifier's sandbox is stubbed (green run, no toolchain
// subprocess) — the sandbox itself is not this spec's surface.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/certification/cert_registry.dart';
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

  /// Format-only drift (the phase-2 `dart format lib/` shape): same AST,
  /// different bytes.
  const formatDriftedSource =
      'class Login {\n'
      '   final String id;\n'
      '      final String username;\n'
      '  const Login({required this.id,   required this.username});\n'
      '}';

  /// A real semantic edit after certification: a new field.
  const semanticDriftSource = '''
class Login {
  final String id;
  final String username;
  final String email;
  const Login({required this.id, required this.username});
}
''';

  /// The non-canonical entity path the gate's resolver tolerates.
  const nestedEntityRel = 'lib/src/domain/entities/nested/login.dart';

  void writeNestedEntity(String source) {
    File(p.join(projectRoot, nestedEntityRel))
      ..createSync(recursive: true)
      ..writeAsStringSync(source);
  }

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
        entityDigestStyle: canonicalizerId,
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
      expect(
        restored.entityDigestStyle,
        canonicalizerId,
        reason:
            'the gate trusts the digest only under the canonicalizer '
            'that recorded it, so the identity must roundtrip too',
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
      expect(
        receipt.toJson().containsKey('entity_digest_style'),
        isFalse,
        reason:
            'the canonicalizer identity is meaningless without the '
            'digest it produced — a legacy receipt must not grow a key',
      );
      // And a pre-1693 receipt on disk still parses, digest-less.
      final legacy = MockCertReceipt.fromJson(receipt.toJson());
      expect(legacy!.entityDigest, isNull);
      expect(legacy.entityDigestStyle, isNull);
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
        entityDigestStyle: 'dart_style/9.9.9/probe',
      );
      expect(withDigest.entityDigest, 'f00dfeed');
      expect(withDigest.entityDigestStyle, 'dart_style/9.9.9/probe');

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
      expect(withoutDigest.entityDigestStyle, isNull);
    });
  });

  group('the canonical digest helper (spec 1693, total and null-safe)', () {
    /// A source on which `DartFormatter.format` fails with something OTHER
    /// than `FormatterException` (a `_TypeError` from dart_style's own
    /// null check, found by fuzzing 3.1.13). The freshness leg used to be
    /// an mtime compare that could not throw; now that it runs the
    /// formatter, a failure like this must still produce a verdict.
    const crashingSource = 'const final => > mixin M b < < @A < void } ';

    test('G12: a formatter failure that is NOT a FormatterException yields '
        'null instead of escaping as a crash', () {
      // Pre-fix this threw out of the helper, out of
      // `CertRegistry.checkEntity`, and out of the whole `zfa tdd run`
      // preflight — a formatter stack trace where the gate promises a
      // verdict and its fix command.
      expect(
        () => formatCanonicalDigest(crashingSource),
        returnsNormally,
        reason: 'a freshness verdict must never become an exception',
      );
      expect(formatCanonicalDigest(crashingSource), isNull);
      // The ordinary unparseable case keeps the same reading.
      expect(formatCanonicalDigest('class A {'), isNull);
    });

    test('G12b: a null (unresolved) entity file yields null, not a throw — '
        'the call site stays a one-expression digest', () {
      expect(formatCanonicalDigestOfFile(null), isNull);
      expect(
        formatCanonicalDigestOfFile(
          File(
            p.join(
              projectRoot,
              'lib',
              'src',
              'domain',
              'entities',
              'nope',
              'nope.dart',
            ),
          ),
        ),
        isNull,
      );
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
      expect(
        doc['entity_digest_style'],
        canonicalizerId,
        reason:
            'the gate only trusts the digest under the canonicalizer '
            'that recorded it — the receipt must name it',
      );
    });

    test('G9: an entity OUTSIDE the canonical layout still gets a digest, '
        'and the gate compares against that same file', () async {
      // The canonical `<entities>/<snake>/<snake>.dart` path is gone; the
      // entity lives one directory deeper, which the gate's resolver has
      // always tolerated. Recording through `entityFileRel` alone would
      // find nothing here, write a digest-less receipt, and hand the
      // entity back to the mtime leg — the #1693 re-certification for
      // exactly the layout the gate accepts.
      File(
        p.join(projectRoot, CertRegistry.entityFileRel('Login')),
      ).deleteSync();
      writeNestedEntity(certifiedSource);

      final certifier = MockCertifier(sandbox: _GreenSandbox());
      final outcome = await certifier.certify(
        entityName: 'Login',
        projectRoot: projectRoot,
        outputDir: outputDir,
      );

      expect(outcome.certified, isTrue, reason: outcome.logs.join('\n'));
      expect(
        outcome.receipt!.entityDigest,
        formatCanonicalDigest(certifiedSource),
        reason:
            'the recording side must resolve the entity the same way '
            'the comparing side does',
      );
      expect(outcome.receipt!.entityDigestStyle, canonicalizerId);

      // Commit the receipt the way the certifier does, then read it back
      // through the gate with the phase-2 format pass applied: the
      // #1693 fix must hold at the nested path, not only at the
      // canonical one.
      await certifier.writeContractArtifacts(
        entityName: 'Login',
        projectRoot: projectRoot,
        outcome: outcome,
      );
      writeNestedEntity(formatDriftedSource);
      expect(
        CertRegistry.checkEntity(
          entity: 'Login',
          projectRoot: projectRoot,
        ).status,
        CertRegistryStatus.certified,
        reason: 'format-only drift at the nested path is not staleness',
      );

      // …and a REAL edit at that path still refuses, which is what
      // proves the gate resolved and compared the nested file instead of
      // quietly skipping the freshness leg.
      writeNestedEntity(semanticDriftSource);
      expect(
        CertRegistry.checkEntity(
          entity: 'Login',
          projectRoot: projectRoot,
        ).status,
        CertRegistryStatus.stale,
        reason:
            'the gate must compare the file the certifier resolved — a '
            'skipped freshness leg would certify a real edit',
      );
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
      expect(
        outcome.receipt!.entityDigestStyle,
        isNull,
        reason: 'no digest, no canonicalizer identity to record',
      );
    });
  });
}
