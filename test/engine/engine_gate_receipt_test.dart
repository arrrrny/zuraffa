// Spec 1110 (issue #1110) — the cert-gate refusal receipt and its
// integration with `zfa engine check` (#1109):
//
//   1. The block writes `engine.gate.<Entity>.refused.json` — a receipt,
//      not an exception — carrying {entity, reason, fix, refs} so
//      `zfa tdd status` and the fix tooling can render the exact fix.
//   2. EngineChecker.check consults the certification registry: a CORE
//      entity wired into the engine tree without a fresh all-satisfied
//      mock-cert receipt fails the check with the refusal receipt path,
//      while `zfa mock create <Entity> --certify`'s receipt unblocks it.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/engine/engine_checker.dart';
import 'package:zuraffa/src/engine/engine_gate_receipt.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1110_gate_');
    projectRoot = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void writeEngineSlice(String entity) {
    // The minimal engine tree the checker walks: the entity source, the
    // mock datasource (the wired double), the seeded mock data, and the
    // datasource interface the mock implements.
    final snake = entity.toLowerCase();
    void write(String rel, String content) {
      final file = File(p.join(projectRoot, rel));
      file.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    write(
      p.join('lib', 'src', 'domain', 'entities', snake, '$snake.dart'),
      'class $entity { final String id; }\n',
    );
    write(
      p.join(
        'lib',
        'src',
        'data',
        'datasources',
        snake,
        '${snake}_mock_datasource.dart',
      ),
      '// GENERATED - DO NOT EDIT\n'
      'class ${entity}MockDataSource {\n'
      '  Future<$entity> get(QueryParams<$entity> params) async => '
      'const $entity(id: "1");\n'
      '}\n',
    );
    write(
      p.join('lib', 'src', 'data', 'mock', '${snake}_mock_data.dart'),
      '// GENERATED - DO NOT EDIT\n',
    );
    write(
      p.join(
        'lib',
        'src',
        'data',
        'datasources',
        snake,
        '${snake}_datasource.dart',
      ),
      'abstract class ${entity}DataSource {\n'
      '  Future<$entity> get(QueryParams<$entity> params);\n'
      '}\n',
    );
  }

  void writeCertReceipt(String entity, {DateTime? modified}) {
    final file = File(
      p.join(
        projectRoot,
        'test',
        'mock',
        entity.toLowerCase(),
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
          {'name': 'get', 'satisfied': true},
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

  group('EngineGateReceipt (spec 1110, the refusal receipt)', () {
    test(
      'write → engine.gate.<Entity>.refused.json with the fix contract',
      () async {
        final path = await EngineGateReceipt.write(
          projectRoot: projectRoot,
          entity: 'Login',
          reason: 'mock-cert.Login.json is missing',
          command: 'zfa engine check Login',
        );

        final file = File(p.join(projectRoot, path));
        expect(file.existsSync(), isTrue, reason: 'receipt at $path');
        final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(doc['schema'], 'engine.gate.v1');
        expect(doc['entity'], 'Login');
        expect(doc['reason'], 'mock-cert.Login.json is missing');
        expect(doc['fix'], 'zfa mock create Login --certify');
        expect(doc['refs'], isA<List<dynamic>>());
        expect(doc['refs'], isNotEmpty);
        expect(doc['command'], 'zfa engine check Login');
        expect(doc['at'], isNotNull);
      },
    );

    test('refusedPath → .zfa/engine.gate.<Entity>.refused.json (project '
        'relative)', () {
      expect(
        EngineGateReceipt.refusedPath('Login'),
        p.join('.zfa', 'engine.gate.Login.refused.json'),
      );
    });

    test('the feature-scoped path lands in the feature tdd dir', () {
      expect(
        EngineGateReceipt.refusedPathInFeature(
          p.join(projectRoot, 'specs', '004-login'),
          'Login',
        ),
        endsWith(
          p.join('specs', '004-login', 'tdd', 'engine.gate.Login.refused.json'),
        ),
      );
    });

    test('load round-trips a written receipt; null when absent', () async {
      expect(
        EngineGateReceipt.load(projectRoot: projectRoot, entity: 'Login'),
        isNull,
      );
      await EngineGateReceipt.write(
        projectRoot: projectRoot,
        entity: 'Login',
        reason: 'stale',
        command: 'zfa engine check Login',
      );
      final doc = EngineGateReceipt.load(
        projectRoot: projectRoot,
        entity: 'Login',
      );
      expect(doc, isNotNull);
      expect(doc!['entity'], 'Login');
      expect(doc['fix'], 'zfa mock create Login --certify');
    });
  });

  group('EngineChecker cert gate (spec 1110 → #1109 integration)', () {
    test('wired entity without a mock-cert receipt → check fails, refusal '
        'receipt written, path surfaced', () async {
      writeEngineSlice('Login');

      final result = await EngineChecker.check(
        entity: 'Login',
        projectRoot: projectRoot,
        methods: const ['get'],
      );

      expect(result.passed, isFalse);
      final gate = result.failures
          .where((f) => f.code == EngineFindingCode.uncertifiedCoreEntity)
          .toList();
      expect(gate, hasLength(1));
      expect(gate.single.typeName, 'Login');
      expect(gate.single.message, contains('--> fix:'));
      expect(gate.single.message, contains('zfa mock create Login --certify'));
      // The refusal receipt is a receipt, not an exception: written to
      // .zfa/engine.gate.Login.refused.json with the fix contract.
      final refusedPath = p.join('.zfa', 'engine.gate.Login.refused.json');
      expect(result.certGateReceiptPath, refusedPath);
      final refused = File(p.join(projectRoot, refusedPath));
      expect(refused.existsSync(), isTrue);
      final doc =
          jsonDecode(refused.readAsStringSync()) as Map<String, dynamic>;
      expect(doc['entity'], 'Login');
      expect(doc['fix'], 'zfa mock create Login --certify');
      expect(doc['reason'], isNotEmpty);
    });

    test('stale receipt (entity newer) → check fails naming stale', () async {
      writeEngineSlice('Login');
      writeCertReceipt('Login', modified: DateTime(2026, 9, 5, 12));
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

      final result = await EngineChecker.check(
        entity: 'Login',
        projectRoot: projectRoot,
        methods: const ['get'],
      );

      expect(result.passed, isFalse);
      final gate = result.failures
          .where((f) => f.code == EngineFindingCode.uncertifiedCoreEntity)
          .toList();
      expect(gate, hasLength(1));
      expect(gate.single.message, contains('stale'));
      expect(result.certGateReceiptPath, isNotNull);
    });

    test(
      'fresh all-satisfied receipt → gate passes (the certify fix works)',
      () async {
        writeEngineSlice('Login');
        writeCertReceipt('Login');

        final result = await EngineChecker.check(
          entity: 'Login',
          projectRoot: projectRoot,
          methods: const ['get'],
        );

        expect(
          result.failures
              .where((f) => f.code == EngineFindingCode.uncertifiedCoreEntity)
              .isEmpty,
          isTrue,
          reason: 'a fresh mock-cert.Login.json unblocks the gate',
        );
        expect(result.certGateReceiptPath, isNull);
        expect(result.passed, isTrue, reason: 'failures: ${result.failures}');
      },
    );

    test(
      'entity without any mock wiring → no cert gate (not referenced)',
      () async {
        final file = File(
          p.join(
            projectRoot,
            'lib',
            'src',
            'domain',
            'entities',
            'billing',
            'billing.dart',
          ),
        );
        file.createSync(recursive: true);
        file.writeAsStringSync('class Billing { final String id; }\n');

        final result = await EngineChecker.check(
          entity: 'Billing',
          projectRoot: projectRoot,
        );

        expect(
          result.failures
              .where((f) => f.code == EngineFindingCode.uncertifiedCoreEntity)
              .isEmpty,
          isTrue,
        );
        expect(result.certGateReceiptPath, isNull);
      },
    );
  });
}
