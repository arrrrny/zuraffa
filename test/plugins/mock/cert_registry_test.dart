// Spec 1110 (issue #1110) — the certification registry contract test:
// the cert registry's existence + freshness logic has its own test.
//
// Structural + behavioral: register an entity (mock wired + receipt
// written), mark it stale (entity file touched after certification), and
// verify the gate blocks with the exact cert command to run.
//
// The registry's vocabulary (mirrors the engine-slice boundary gate):
//   - mock datasource on disk            → the entity is REFERENCED by
//     the engine tree and must be certified;
//   - mock-cert.<Entity>.json missing     → blocked (missing);
//   - receipt with an unsatisfied method  → blocked (unsatisfied);
//   - corrupt receipt bytes               → blocked (corrupt);
//   - receipt older than the entity file  → blocked (stale);
//   - fresh all-satisfied receipt         → certified;
//   - no mock + no receipt                → not referenced (gate ok).
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/certification/cert_registry.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1110_registry_');
    projectRoot = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  String snake(String entity) => entity.toLowerCase();

  void writeEntity(String entity, {DateTime? modified}) {
    final file = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'domain',
        'entities',
        snake(entity),
        '${snake(entity)}.dart',
      ),
    );
    file.createSync(recursive: true);
    file.writeAsStringSync('class $entity { final String id; }\n');
    if (modified != null) {
      file.setLastModifiedSync(modified);
    }
  }

  void writeMockDatasource(String entity) {
    final file = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'data',
        'datasources',
        snake(entity),
        '${snake(entity)}_mock_datasource.dart',
      ),
    );
    file.createSync(recursive: true);
    file.writeAsStringSync('// GENERATED - DO NOT EDIT\n');
  }

  void writeReceipt(
    String entity, {
    required bool allSatisfied,
    DateTime? modified,
  }) {
    final file = File(
      p.join(
        projectRoot,
        'test',
        'mock',
        snake(entity),
        'mock-cert.$entity.json',
      ),
    );
    file.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'spec': 1001,
        'entity': entity,
        'interface': '${entity}DataSource',
        'contract_digest': 'abc123',
        'methods': [
          {'name': 'get', 'satisfied': allSatisfied},
          {'name': 'update', 'satisfied': allSatisfied},
        ],
        'sandbox': const {
          'runner': 'dart',
          'analyze_issues': 0,
          'analyze_errors': 0,
        },
        'certified_at': '2026-09-05T00:00:00.000Z',
      }),
    );
    if (modified != null) {
      file.setLastModifiedSync(modified);
    }
  }

  group('CertRegistry.checkEntity (spec 1110, existence)', () {
    test('fresh all-satisfied receipt on a wired entity → certified', () {
      writeEntity('Login');
      writeMockDatasource('Login');
      writeReceipt('Login', allSatisfied: true);

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.status, CertRegistryStatus.certified);
      expect(entry.blocked, isFalse);
      expect(entry.entity, 'Login');
    });

    test('wired entity without a mock-cert receipt → blocked as missing '
        'with the exact cert command', () {
      writeEntity('Login');
      writeMockDatasource('Login');

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isTrue);
      expect(entry.status, CertRegistryStatus.missing);
      expect(entry.fix, 'zfa mock create Login --certify');
      expect(entry.reason, contains('mock-cert.Login.json'));
    });

    test('receipt with an unsatisfied method → blocked as unsatisfied', () {
      writeEntity('Login');
      writeMockDatasource('Login');
      writeReceipt('Login', allSatisfied: false);

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isTrue);
      expect(entry.status, CertRegistryStatus.unsatisfied);
      expect(entry.fix, 'zfa mock create Login --certify');
    });

    test(
      'corrupt receipt bytes → blocked as corrupt (not a certification)',
      () {
        writeEntity('Login');
        writeMockDatasource('Login');
        final dir = Directory(p.join(projectRoot, 'test', 'mock', 'login'))
          ..createSync(recursive: true);
        File(
          p.join(dir.path, 'mock-cert.Login.json'),
        ).writeAsStringSync('not json at all');

        final entry = CertRegistry.checkEntity(
          entity: 'Login',
          projectRoot: projectRoot,
        );

        expect(entry.blocked, isTrue);
        expect(entry.status, CertRegistryStatus.corrupt);
        expect(entry.fix, 'zfa mock create Login --certify');
      },
    );
  });

  group('CertRegistry.checkEntity (spec 1110, freshness)', () {
    test('receipt older than the entity file → blocked as stale', () async {
      // Register the entity: certify at t0…
      writeEntity('Login');
      writeMockDatasource('Login');
      writeReceipt(
        'Login',
        allSatisfied: true,
        modified: DateTime(2026, 9, 5, 12),
      );
      // …then the entity changes at t1 > t0 (the certification no longer
      // describes the entity on disk).
      await File(
        p.join(
          projectRoot,
          'lib',
          'src',
          'domain',
          'entities',
          'login',
          'login.dart',
        ),
      ).setLastModified(DateTime(2026, 9, 6, 12));

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isTrue);
      expect(entry.status, CertRegistryStatus.stale);
      expect(entry.fix, 'zfa mock create Login --certify');
      expect(entry.reason, contains('stale'));
    });

    test('receipt newer than the entity file → certified (fresh)', () async {
      writeEntity('Login', modified: DateTime(2026, 9, 5, 12));
      writeMockDatasource('Login');
      writeReceipt(
        'Login',
        allSatisfied: true,
        modified: DateTime(2026, 9, 6, 12),
      );

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isFalse);
      expect(entry.status, CertRegistryStatus.certified);
    });

    test('entity file absent → freshness is not decidable, receipt stands', () {
      // The entity source moved or was never generated; the receipt is
      // still the last honest certification — no false stale block.
      writeMockDatasource('Login');
      writeReceipt('Login', allSatisfied: true);

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isFalse);
      expect(entry.status, CertRegistryStatus.certified);
    });
  });

  group('CertRegistry.checkEntity (spec 1110, engine-tree reference)', () {
    test('entity with no mock and no receipt → not referenced, gate ok', () {
      writeEntity('Billing');

      final entry = CertRegistry.checkEntity(
        entity: 'Billing',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isFalse);
      expect(entry.status, CertRegistryStatus.notReferenced);
    });

    test('a receipt without a mock datasource is still checked (the '
        'certification artifacts outlived the wiring)', () {
      writeEntity('Login');
      writeReceipt('Login', allSatisfied: true);

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );

      expect(entry.blocked, isFalse);
      expect(entry.status, CertRegistryStatus.certified);
    });
  });

  group('CertRegistry.checkEntities (spec 1110, the gate walk)', () {
    test('names every blocked entity, first is the block, ok when clean', () {
      // Login: certified. Session: wired but uncertified. Billing: not
      // referenced.
      writeEntity('Login');
      writeMockDatasource('Login');
      writeReceipt('Login', allSatisfied: true);
      writeEntity('Session');
      writeMockDatasource('Session');
      writeEntity('Billing');

      final entries = CertRegistry.checkEntities(
        entities: const ['Login', 'Session', 'Billing'],
        projectRoot: projectRoot,
      );

      final blocked = entries.where((e) => e.blocked).toList();
      expect(blocked, hasLength(1));
      expect(blocked.single.entity, 'Session');
      expect(blocked.single.status, CertRegistryStatus.missing);
      expect(blocked.single.fix, 'zfa mock create Session --certify');
    });

    test('the entry serializes for receipts and machine tooling', () {
      writeEntity('Login');
      writeMockDatasource('Login');

      final entry = CertRegistry.checkEntity(
        entity: 'Login',
        projectRoot: projectRoot,
      );
      final json = entry.toJson();

      expect(json['entity'], 'Login');
      expect(json['status'], 'missing');
      expect(json['fix'], 'zfa mock create Login --certify');
      expect(json['reason'], isNotEmpty);
    });
  });
}
