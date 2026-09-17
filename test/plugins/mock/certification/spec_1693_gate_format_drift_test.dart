// Spec 1693 (issue #1693) — the mock-cert gate must not read FORMAT-ONLY
// drift as staleness.
//
// The phase-2b batch refactor (spec 1652) runs `dart format lib/` AFTER
// mid-lane certification, so the entity source's bytes change (mtime
// moves) without changing what it declares. The spec-1110 gate read that
// raw drift as staleness and forced a second full sandbox certification
// per entity (2–17 min under Flutter; hours at zik_zak's 145-entity
// scale).
//
// The receipt records a FORMAT-CANONICAL digest of the entity source
// (SHA-256 over `dart format` output — spec 1693). This file drives the
// GATE half with hand-written receipt JSON so the behavioral red is
// observable against the PRE-FIX tree: pre-fix, the gate ignores the
// recorded digest and reads mtime → G1 and G5 fail for exactly the
// issue's reason. The receipt-model/certifier half lives in
// spec_1693_receipt_and_certifier_test.dart (the new seam).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/certification/cert_registry.dart';

/// The canonical digest the certifier records at certification time:
/// SHA-256 over the entity source's `dart format` output. Mirrored here
/// (not imported) so the gate red runs against a tree that does not
/// export the helper yet — the certifier test pins that the lib-side
/// helper computes the SAME digest.
String canonicalDigestOf(String source) {
  final formatted = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(source);
  return sha256.convert(utf8.encode(formatted)).toString();
}

void main() {
  late Directory tempDir;
  late String projectRoot;

  /// The certified shape of the entity source — format-clean.
  const certifiedSource = '''
class Login {
  final String id;
  final String username;
  const Login({required this.id, required this.username});
}
''';

  /// Format-only drift (the phase-2 `dart format lib/` shape): same AST,
  /// different bytes — indentation normalized, inner spacing collapsed,
  /// trailing newline added.
  const formatDriftedSource =
      'class Login {\n'
      '   final String id;\n'
      '      final String username;\n'
      '  const Login({required this.id,   required this.username});\n'
      '}';

  /// A real semantic edit after certification: a new field — a different
  /// declaration the certification never proved.
  const semanticDriftSource = '''
class Login {
  final String id;
  final String username;
  final String email;
  const Login({required this.id, required this.username});
}
''';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1693_gate_');
    projectRoot = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void writeEntity(String source, {DateTime? modified}) {
    final file = File(
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
    file.createSync(recursive: true);
    file.writeAsStringSync(source);
    if (modified != null) {
      file.setLastModifiedSync(modified);
    }
  }

  void writeMockDatasource() {
    final file = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'data',
        'datasources',
        'login',
        'login_mock_datasource.dart',
      ),
    );
    file.createSync(recursive: true);
    file.writeAsStringSync('// GENERATED - DO NOT EDIT\n');
  }

  void writeReceipt({
    bool allSatisfied = true,
    String? entityDigest,
    DateTime? modified,
  }) {
    final file = File(
      p.join(projectRoot, 'test', 'mock', 'login', 'mock-cert.Login.json'),
    );
    file.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'spec': 1001,
        'entity': 'Login',
        'interface': 'LoginDataSource',
        'contract_digest': 'abc123',
        'entity_digest': ?entityDigest,
        'methods': [
          {'name': 'get', 'satisfied': allSatisfied},
          {'name': 'update', 'satisfied': allSatisfied},
        ],
        'sandbox': const {
          'runner': 'dart',
          'analyze_issues': 0,
          'analyze_errors': 0,
        },
        'certified_at': '2026-09-17T00:00:00.000Z',
      }),
    );
    if (modified != null) {
      file.setLastModifiedSync(modified);
    }
  }

  final certifiedAt = DateTime(2026, 9, 17, 12);
  final driftedAt = DateTime(2026, 9, 18, 12);

  group('CertRegistry.checkEntity (spec 1693, format-canonical freshness)', () {
    test('G1: dart format-only drift after certification → certified '
        '(the #1693 bug — pre-fix reads stale)', () {
      // Certify at t0: the certifier digests the source it certified.
      writeEntity(certifiedSource, modified: certifiedAt);
      writeMockDatasource();
      writeReceipt(
        entityDigest: canonicalDigestOf(certifiedSource),
        modified: certifiedAt,
      );
      // Phase 2 reformats the tree at t1: bytes change, mtime moves,
      // the declaration does not.
      writeEntity(formatDriftedSource, modified: driftedAt);

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(
        entry.status,
        CertRegistryStatus.certified,
        reason:
            'format-only drift canonicalizes to the certified bytes — '
            'the certification still describes the entity on disk; '
            'a second sandbox certification is NOT required '
            '(got: ${entry.reason})',
      );
      expect(entry.blocked, isFalse);
    });

    test('G2: a real entity edit after certification → stale, exact fix '
        '(the spec-1110 gate stays intact)', () {
      writeEntity(certifiedSource, modified: certifiedAt);
      writeMockDatasource();
      writeReceipt(
        entityDigest: canonicalDigestOf(certifiedSource),
        modified: certifiedAt,
      );
      // A field is added at t1 — a declaration the certification
      // never proved.
      writeEntity(semanticDriftSource, modified: driftedAt);

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isTrue);
      expect(entry.status, CertRegistryStatus.stale);
      expect(entry.fix, 'zfa mock create Login --certify');
      expect(entry.reason, contains('stale'));
      expect(entry.reason, contains('changed after the mock was certified'));
      // The reason prefixes with the receipt name — the refusal receipt
      // and `zfa tdd status` render it verbatim.
      expect(entry.reason, startsWith('mock-cert.Login.json is stale:'));
    });

    test('G3: an unparseable entity source with a recorded digest → stale '
        '(what cannot be canonicalized cannot be what was certified)', () {
      writeEntity(certifiedSource, modified: certifiedAt);
      writeMockDatasource();
      writeReceipt(
        entityDigest: canonicalDigestOf(certifiedSource),
        modified: certifiedAt,
      );
      writeEntity(
        'class Login { final String id;  // truncated mid-declaration',
        modified: driftedAt,
      );

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isTrue);
      expect(entry.status, CertRegistryStatus.stale);
      expect(entry.fix, 'zfa mock create Login --certify');
    });

    test('G4: pre-1693 receipts (no entity_digest) keep the mtime '
        'freshness semantics — stale when the entity is touched after', () {
      writeEntity(certifiedSource, modified: certifiedAt);
      writeMockDatasource();
      writeReceipt(modified: certifiedAt);
      writeEntity(formatDriftedSource, modified: driftedAt);

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isTrue);
      expect(entry.status, CertRegistryStatus.stale);
      // Legacy mtime staleness keeps the same reason contract.
      expect(entry.reason, startsWith('mock-cert.Login.json is stale:'));
    });

    test('G4b: pre-1693 receipts keep mtime freshness — receipt newer than '
        'the entity → certified', () {
      writeEntity(certifiedSource, modified: certifiedAt);
      writeMockDatasource();
      writeReceipt(modified: driftedAt);

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isFalse);
      expect(entry.status, CertRegistryStatus.certified);
    });

    test('G5: the digest overrides a lying-fresh mtime — a receipt re-touched '
        'after a real edit still refuses (semantic drift is never waived)', () {
      // The entity was edited at t0; the receipt was touched at t1 —
      // mtime alone would call it fresh, the recorded digest says the
      // certified source is NOT what is on disk.
      writeEntity(semanticDriftSource, modified: certifiedAt);
      writeMockDatasource();
      writeReceipt(
        entityDigest: canonicalDigestOf(certifiedSource),
        modified: driftedAt,
      );

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isTrue, reason: entry.reason);
      expect(entry.status, CertRegistryStatus.stale);
    });
  });
}
