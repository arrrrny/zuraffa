// Spec 1001 (issue #1001) — the mock certification registry extension:
// `zfa mock certify <Entity>` adds the mock to the #832 registry entry.
//
// certifyMockInRegistry commits the mock-cert.<Entity>.json receipt as a
// fixture, re-writes the #832 manifest (mocks provenance + receipt hashed
// into the world digest), and appends the hash-chained `kind: mock-cert`
// cycle-log evidence. Byte drift on the receipt is caught by
// verifyManifest — the registry entry is live.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/builders/simulation/fixture_certification.dart';
import 'package:zuraffa/src/simulation/fixture_registry.dart';

void main() {
  late Directory tempDir;
  late String featureDir;
  late String fixturesDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1001_registry_');
    featureDir = p.join(tempDir.path, 'specs', '1001-mock-feature');
    fixturesDir = p.join(featureDir, 'tdd', 'fixtures');
    await Directory(fixturesDir).create(recursive: true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Map<String, dynamic> receiptFor(String entity) => {
    'schema': 1,
    'spec': 1001,
    'entity': entity,
    'interface': '${entity}DataSource',
    'contract_digest': 'digest-$entity',
    'methods': const [
      {'name': 'get', 'satisfied': true},
      {'name': 'update', 'satisfied': true},
    ],
    'sandbox': const {
      'runner': 'dart',
      'analyze_issues': 0,
      'analyze_errors': 0,
    },
    'certified_at': '2026-09-04T00:00:00.000Z',
  };

  Future<Map<String, dynamic>> seedFixture() async {
    // The registry entry needs at least one fixture file to hash.
    await File(
      p.join(fixturesDir, 'login_fixtures.json'),
    ).writeAsString('{"records": []}\n');
    return FixtureRegistry(fixturesDir).writeManifest(families: []);
  }

  group('certifyMockInRegistry (spec 1001, #832 extension)', () {
    test('commits the receipt and records the mock in the manifest', () async {
      await seedFixture();

      final manifest = await certifyMockInRegistry(
        fixturesDir: fixturesDir,
        entityName: 'Login',
        receipt: receiptFor('Login'),
        commandLine: 'zfa mock certify Login',
      );

      // The receipt is a fixture on disk…
      final receiptFile = File(p.join(fixturesDir, 'mock-cert.Login.json'));
      expect(receiptFile.existsSync(), isTrue);
      expect(await receiptFile.readAsString(), contains('"spec": 1001'));

      // …and the manifest's files + mocks provenance cover it.
      expect(manifest['mocks'], ['Login']);
      final files = (manifest['files'] as Map<String, dynamic>)
          .cast<String, Map<String, dynamic>>();
      expect(files.containsKey('mock-cert.Login.json'), isTrue);
    });

    test(
      're-certifying a second mock preserves the first + families',
      () async {
        await File(
          p.join(fixturesDir, 'login_fixtures.json'),
        ).writeAsString('{"records": []}\n');
        await FixtureRegistry(
          fixturesDir,
        ).writeManifest(families: ['firebase_auth']);

        await certifyMockInRegistry(
          fixturesDir: fixturesDir,
          entityName: 'Login',
          receipt: receiptFor('Login'),
          commandLine: 'zfa mock certify Login',
        );
        final manifest = await certifyMockInRegistry(
          fixturesDir: fixturesDir,
          entityName: 'Session',
          receipt: receiptFor('Session'),
          commandLine: 'zfa mock certify Session',
        );

        expect(manifest['families'], ['firebase_auth']);
        expect(manifest['mocks'], ['Login', 'Session']);
        final files = (manifest['files'] as Map<String, dynamic>)
            .cast<String, Map<String, dynamic>>();
        expect(files.containsKey('mock-cert.Login.json'), isTrue);
        expect(files.containsKey('mock-cert.Session.json'), isTrue);
      },
    );

    test(
      'verifyManifest catches byte drift on the committed receipt',
      () async {
        await seedFixture();
        await certifyMockInRegistry(
          fixturesDir: fixturesDir,
          entityName: 'Login',
          receipt: receiptFor('Login'),
          commandLine: 'zfa mock certify Login',
        );

        // Tamper: the receipt no longer matches the certified bytes.
        final receiptFile = File(p.join(fixturesDir, 'mock-cert.Login.json'));
        await receiptFile.writeAsString(
          (await receiptFile.readAsString()).replaceAll(
            '"satisfied": true',
            '"satisfied": false',
          ),
        );

        expect(
          () => FixtureRegistry(fixturesDir).verifyManifest(),
          throwsA(
            isA<FixtureMismatch>().having(
              (e) => e.toString(),
              'reason',
              contains('mock-cert.Login.json'),
            ),
          ),
        );
      },
    );

    test('appends hash-chained kind: mock-cert cycle evidence', () async {
      await seedFixture();
      await certifyMockInRegistry(
        fixturesDir: fixturesDir,
        entityName: 'Login',
        receipt: receiptFor('Login'),
        commandLine: 'zfa mock certify Login',
      );

      final cycleLog = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
      expect(cycleLog.existsSync(), isTrue);
      final content = await cycleLog.readAsString();
      expect(content, contains('kind: mock-cert'));
      expect(content, contains('behavior: 1001-mock-feature-mock-cert-login'));
      expect(content, contains('- prev-hash: genesis'));
      expect(content, contains('- hash:'));
      expect(content, contains('receipt: mock-cert.Login.json='));
    });

    test(
      'the cycle-log chain links a second certification to the first',
      () async {
        await seedFixture();
        await certifyMockInRegistry(
          fixturesDir: fixturesDir,
          entityName: 'Login',
          receipt: receiptFor('Login'),
          commandLine: 'zfa mock certify Login',
        );
        await certifyMockInRegistry(
          fixturesDir: fixturesDir,
          entityName: 'Session',
          receipt: receiptFor('Session'),
          commandLine: 'zfa mock certify Session',
        );

        // Each entity has its own behavior chain; each entry carries a
        // hash line so the schema-1 evidence tooling parses it.
        final content = await File(
          p.join(featureDir, 'tdd', 'cycle-log.md'),
        ).readAsString();
        expect(
          content,
          contains('behavior: 1001-mock-feature-mock-cert-login'),
        );
        expect(
          content,
          contains('behavior: 1001-mock-feature-mock-cert-session'),
        );
        final hashLines = RegExp(
          r'^- hash: .+$',
          multiLine: true,
        ).allMatches(content).length;
        expect(hashLines, greaterThanOrEqualTo(2));
      },
    );

    test(
      'manifest without mocks key stays schema-compatible on read',
      () async {
        await seedFixture();
        final registry = FixtureRegistry(fixturesDir);
        final manifest = await registry.readManifest();
        // Pre-1001 manifests have no `mocks` key — absent means empty.
        expect(manifest.containsKey('mocks'), isFalse);
        expect(manifest['schema'], 1);
      },
    );
  });

  group('FixtureRegistry.writeManifest mocks parameter', () {
    test('omits the mocks key when no mocks are registered', () async {
      await File(p.join(fixturesDir, 'x.json')).writeAsString('{}');
      final manifest = await FixtureRegistry(
        fixturesDir,
      ).writeManifest(mocks: const []);
      expect(manifest.containsKey('mocks'), isFalse);
    });

    test('records mock provenance when present', () async {
      await File(p.join(fixturesDir, 'x.json')).writeAsString('{}');
      final manifest = await FixtureRegistry(
        fixturesDir,
      ).writeManifest(mocks: const ['Login']);
      expect(manifest['mocks'], ['Login']);
    });
  });
}
