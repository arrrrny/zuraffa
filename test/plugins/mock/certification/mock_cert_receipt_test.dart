import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_cert_receipt.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_mock_receipt_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  MockCertReceipt buildReceipt({List<MapEntry<String, bool>>? methods}) {
    return MockCertReceipt(
      entity: 'Login',
      interfaceName: 'LoginDataSource',
      subjectPath:
          'lib/src/data/datasources/login/'
          'login_mock_datasource.dart',
      contractTestPath: 'test/mock/login/login_mock_contract_test.dart',
      contractDigest: 'deadbeef',
      methods:
          methods ?? const [MapEntry('get', true), MapEntry('update', true)],
      sandbox: const {
        'runner': 'dart',
        'analyze_issues': 0,
        'analyze_errors': 0,
        'tests_passed': 3,
        'tests_failed': 0,
      },
      seed: 42,
      certifiedAt: DateTime.utc(2026, 9, 4),
    );
  }

  group('MockCertReceipt (spec 1001)', () {
    test('allSatisfied is true only when every method is satisfied', () {
      expect(buildReceipt().allSatisfied, isTrue);
      expect(
        buildReceipt(
          methods: const [MapEntry('get', true), MapEntry('update', false)],
        ).allSatisfied,
        isFalse,
      );
      expect(
        buildReceipt(methods: const []).allSatisfied,
        isFalse,
        reason: 'an empty contract certifies nothing',
      );
    });

    test('toJson/fromJson roundtrip preserves the per-method proof', () {
      final receipt = buildReceipt(
        methods: const [MapEntry('get', true), MapEntry('update', false)],
      );
      final restored = MockCertReceipt.fromJson(receipt.toJson());

      expect(restored, isNotNull);
      expect(restored!.entity, 'Login');
      expect(restored.interfaceName, 'LoginDataSource');
      expect(restored.contractDigest, 'deadbeef');
      expect(restored.seed, 42);
      expect(restored.methods, hasLength(2));
      // MapEntry has no == override — compare key/value pairs.
      expect(restored.methods[0].key, 'get');
      expect(restored.methods[0].value, isTrue);
      expect(restored.methods[1].key, 'update');
      expect(restored.methods[1].value, isFalse);
      expect(restored.allSatisfied, isFalse);
      expect(restored.sandbox['runner'], 'dart');
    });

    test('digestOf is a stable SHA-256 of the contract bytes', () {
      const source = 'void main() {}';
      final digest = MockCertReceipt.digestOf(source);
      expect(digest, hasLength(64));
      expect(digest, MockCertReceipt.digestOf(source));
      expect(digest, isNot(MockCertReceipt.digestOf('void main() { }')));
    });

    test('writeTo writes pretty JSON with the spec provenance', () async {
      final receipt = buildReceipt();
      final file = File(
        p.join(tempDir.path, 'test', 'mock', 'login', 'mock-cert.Login.json'),
      );
      await receipt.writeTo(file);

      final doc = await file.readAsString();
      expect(doc, contains('"schema": 1'));
      expect(doc, contains('"spec": 1001'));
      expect(doc, contains('"entity": "Login"'));
      expect(doc, contains('"contract_digest"'));
      expect(doc, contains('"satisfied": true'));
      expect(
        doc.endsWith('\n'),
        isTrue,
        reason: 'POSIX trailing newline for diffable receipts',
      );
    });
  });

  group('loadMockCertReceipt (spec 1001)', () {
    test('null when the receipt is absent', () {
      expect(loadMockCertReceipt(tempDir.path, 'Login'), isNull);
    });

    test('roundtrips through disk', () async {
      final receipt = buildReceipt();
      final file = File(
        p.join(tempDir.path, 'test', 'mock', 'login', 'mock-cert.Login.json'),
      );
      await receipt.writeTo(file);

      final loaded = loadMockCertReceipt(tempDir.path, 'Login');
      expect(loaded, isNotNull);
      expect(loaded!.allSatisfied, isTrue);
      expect(loaded.methods, hasLength(2));
    });

    test('null when the receipt is corrupt (not a certification)', () async {
      final file = File(
        p.join(tempDir.path, 'test', 'mock', 'login', 'mock-cert.Login.json'),
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('not json at all');

      expect(loadMockCertReceipt(tempDir.path, 'Login'), isNull);
    });

    test('loads an unsatisfied receipt as a failed certification', () async {
      final receipt = buildReceipt(
        methods: const [MapEntry('get', true), MapEntry('update', false)],
      );
      final file = File(
        p.join(tempDir.path, 'test', 'mock', 'login', 'mock-cert.Login.json'),
      );
      await receipt.writeTo(file);

      final loaded = loadMockCertReceipt(tempDir.path, 'Login');
      expect(loaded, isNotNull);
      expect(loaded!.allSatisfied, isFalse);
    });
  });
}
