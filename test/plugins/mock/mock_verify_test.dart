// SPEC 1121 (issue #1121): `zfa mock verify` + fleshed-out `MockExplainCapability`.
//
// RED evidence (pre-fix master): `mock verify` and `mock explain` are not
// recognized grammar — package:args rejects the subcommand ("Could not find
// an option or command named ...") — so a drifted mock can never be re-proven
// read-only and a mock's coverage/status/fixtures can only be learned by
// reading generated Dart by hand.
//
// Contract pinned here (remediation):
//  - `zfa mock verify <Entity>` re-runs the SAME certification gate
//    `zfa mock create <Entity> --certify` uses (MockCertificationService.certify
//    + MockCertifier.gate — the shared conformance shape) against the mock
//    files already on disk and the current entity source. Read-only. Exit 0
//    conforming, 1 with `--> fix:` lines on drift/missing artifacts, 2 usage.
//    `--json` emits one canonical `zuraffa.verdict.v1` envelope (issue #1105).
//  - `zfa mock explain <Entity>` reports method coverage, skipped/invented
//    lists, per-method certification status (spec-1001 receipt), and the
//    `MockData.forMethod` selector bindings (issue #1034). `--json` carries
//    the report under the envelope's `details.explain`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';
import 'package:zuraffa/src/core/verdict_envelope.dart';
import 'package:zuraffa/src/plugins/mock/services/mock_certification.dart';

import 'mock_cli_guard.dart';

void main() {
  late Directory tempDir;
  var exitCodeAtEntry = 0;

  setUp(() async {
    exitCodeAtEntry = exitCode;
    tempDir = await Directory.systemTemp.createTemp('mock_verify_1121_');
    await _scaffoldProduct(tempDir.path);
  });

  tearDown(() async {
    exitCode = exitCodeAtEntry;
    // Restore the production analyze runner (static test seam).
    MockCertifier.analyzeRunnerOverride = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return CwdGuard.exclusive(
      () => runner.runCapturing(['-C', tempDir.path, ...args]),
    );
  }

  /// Deterministic green analyze stub for the fast tier.
  void greenAnalyze() {
    MockCertifier.analyzeRunnerOverride = (files, cwd) async {
      return (exitCode: 0, output: 'Analyzing ... No issues found!');
    };
  }

  /// The mock provider/datasource path for the scaffolded Product.
  File mockDatasource() => File(
    p.join(
      tempDir.path,
      'lib',
      'src',
      'data',
      'datasources',
      'product',
      'product_mock_datasource.dart',
    ),
  );

  /// Removes one `@override ... <type> <method>(...) {...}` block from the
  /// mock datasource — the deliberate drift.
  Future<void> driftMockByRemoving(String method) async {
    final file = mockDatasource();
    final src = await file.readAsString();
    final decl = RegExp('\\w+(?:<[^>(]*>)?\\s+$method\\(');
    final match = decl.firstMatch(src);
    expect(
      match,
      isNotNull,
      reason: 'the method $method must exist to drift it',
    );
    final methodLineStart = src.lastIndexOf('  @override', match!.start);
    final nextOverride = src.indexOf('  @override', match.end);
    final classEnd = src.lastIndexOf('}');
    final methodEnd = nextOverride == -1 ? classEnd : nextOverride;
    await file.writeAsString(src.replaceRange(methodLineStart, methodEnd, ''));
  }

  /// Relative-path → size snapshot of the fixture tree (the read-only probe).
  Map<String, int> treeSnapshot() {
    final snapshot = <String, int>{};
    for (final entity in tempDir.listSync(recursive: true)) {
      if (entity is File) {
        snapshot[p.relative(entity.path, from: tempDir.path)] = entity
            .lengthSync();
      }
    }
    return snapshot;
  }

  /// Augments the generated `<Product>MockData` class with the #1034
  /// per-method fixture selector, and binds it inside the mock datasource's
  /// `get` method — the shapes the explain surface must see on disk.
  Future<void> addSelectorAndBinding() async {
    final dataFile = File(
      p.join(
        tempDir.path,
        'lib',
        'src',
        'data',
        'mock',
        'product_mock_data.dart',
      ),
    );
    expect(
      dataFile.existsSync(),
      isTrue,
      reason: 'mock create emits the mock data fixture',
    );
    final dataSrc = await dataFile.readAsString();
    final lastBrace = dataSrc.lastIndexOf('}');
    await dataFile.writeAsString(
      dataSrc.replaceRange(
        lastBrace,
        lastBrace,
        '\n  static Product forMethod(String status) => sampleProduct;\n',
      ),
    );

    final dsSrc = await mockDatasource().readAsString();
    final firstBrace = dsSrc.indexOf('{');
    await mockDatasource().writeAsString(
      dsSrc.replaceRange(
        firstBrace + 1,
        firstBrace + 1,
        '\n  // binding: ProductMockData.forMethod(params.status)\n'
        '  final binding = ProductMockData.forMethod(params.status);\n',
      ),
    );
  }

  group('zfa mock verify (spec 1121)', () {
    test(
      'A1: exits 0 on a conforming on-disk mock and writes nothing',
      () async {
        greenAnalyze();
        await runCli(['mock', 'create', 'Product']);
        exitCode = exitCodeAtEntry;

        final before = treeSnapshot();
        final out = await runCli(['mock', 'verify', 'Product']);

        expect(
          exitCode,
          0,
          reason: 'a conforming mock passes the gate, output:\n$out',
        );
        expect(out, contains('ProductDataSource'));
        expect(out, contains('mock-cert:product@'));
        expect(out, isNot(contains('--> fix:')));
        expect(
          treeSnapshot(),
          before,
          reason: 'verify is read-only — certify stays the gen+certify combo',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'A2: exit 1 + --> fix: on a deliberately drifted mock (missing member)',
      () async {
        greenAnalyze();
        await runCli(['mock', 'create', 'Product']);
        exitCode = exitCodeAtEntry;
        await driftMockByRemoving('update');

        final out = await runCli(['mock', 'verify', 'Product']);

        expect(
          exitCode,
          1,
          reason: 'drift must fail the gate with exit 1, output:\n$out',
        );
        expect(out, contains('--> fix:'));
        expect(out, contains('update'), reason: 'the fix names the member');
        expect(
          out,
          contains('ProductDataSource'),
          reason: 'the fix names the interface the mock violates',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'A3: no mock on disk → exit 1 + missing_file + fix names create',
      () async {
        final out = await runCli(['mock', 'verify', 'Ghost']);

        expect(exitCode, 1, reason: 'a missing artifact is an honest refusal');
        expect(out, contains('missing_file'));
        expect(
          out,
          contains('zfa mock create Ghost'),
          reason: 'the fix line names the remediation',
        );
      },
    );

    test('A4: --json on a conforming mock → canonical pass envelope', () async {
      greenAnalyze();
      await runCli(['mock', 'create', 'Product']);
      exitCode = exitCodeAtEntry;

      final out = await runCli(['mock', 'verify', 'Product', '--json']);

      expect(exitCode, 0, reason: 'conforming: exit 0, output:\n$out');
      final envelope = VerdictEnvelope.tryParse(out);
      expect(
        envelope,
        isNotNull,
        reason: 'the last stdout line must be the canonical envelope:\n$out',
      );
      expect(
        envelope!.toJson()['schema'],
        VerdictEnvelope.canonicalSchema,
        reason: 'the canonical zuraffa.verdict.v1 envelope (issue #1105)',
      );
      expect(envelope.verdict, VerdictKind.pass);
      expect(envelope.exitClass, ExitProtocol.success);
      expect(envelope.subject!.kind, 'mock');
      expect(envelope.subject!.id, 'Product');
      expect(envelope.findings, isEmpty);
      expect(envelope.drifts, isEmpty);
    });

    test('A4b: --json on a drifted mock → canonical fail envelope', () async {
      greenAnalyze();
      await runCli(['mock', 'create', 'Product']);
      exitCode = exitCodeAtEntry;
      await driftMockByRemoving('update');

      final out = await runCli(['mock', 'verify', 'Product', '--json']);

      expect(exitCode, 1);
      final envelope = VerdictEnvelope.tryParse(out);
      expect(envelope, isNotNull, reason: 'envelope must still emit:\n$out');
      expect(envelope!.verdict, VerdictKind.fail);
      expect(envelope.exitClass, ExitProtocol.failure);
      expect(envelope.findings, isNotEmpty);
      expect(
        envelope.findings.map((f) => f.member),
        contains('update'),
        reason: 'findings name the drifted member',
      );
      expect(
        envelope.drifts.join('\n'),
        contains('--> fix:'),
        reason: 'drifts carry the fix lines',
      );
    });

    test('A4c: usage error (no entity) → exit 2 + fix line', () async {
      final out = await runCli(['mock', 'verify']);
      expect(exitCode, ExitProtocol.usage);
      expect(out, contains('--> fix:'));
    });
  });

  group('zfa mock explain (spec 1121, MockExplainCapability)', () {
    test(
      'A5: coverage, per-method certification status, skipped, registry',
      () async {
        greenAnalyze();
        await runCli(['mock', 'create', 'Product']);
        exitCode = exitCodeAtEntry;

        // A committed spec-1001 receipt (the `--certify` artifact) makes the
        // per-method certification status visible to explain.
        final receipt = File(
          p.join(
            tempDir.path,
            'test',
            'mock',
            'product',
            'mock-cert.Product.json',
          ),
        );
        await receipt.parent.create(recursive: true);
        await receipt.writeAsString(
          jsonEncode({
            'schema': 1,
            'spec': 1001,
            'entity': 'Product',
            'interface': 'ProductDataSource',
            'subject':
                'lib/src/data/datasources/product/'
                'product_mock_datasource.dart',
            'contract_test': 'test/mock/product/product_contract_test.dart',
            'contract_digest': 'aa'.padRight(64, 'a'),
            'methods': [
              {'name': 'get', 'satisfied': true},
              {'name': 'update', 'satisfied': true},
              {'name': 'toggle', 'satisfied': true},
            ],
            'sandbox': {},
            'certified_at': '2026-09-07T00:00:00.000Z',
          }),
        );

        final out = await runCli(['mock', 'explain', 'Product']);

        expect(exitCode, 0, reason: 'explain is informational, output:\n$out');
        expect(out, contains('product_mock_datasource.dart'));
        expect(out, contains('ProductDataSource'));
        expect(out, contains('mock-cert:product@'));
        for (final method in ['get', 'update', 'toggle']) {
          expect(out, contains(method), reason: 'coverage lists $method');
        }
        expect(
          out,
          contains('certified'),
          reason: 'per-method status from the committed receipt',
        );
        expect(out, contains('skipped'));
        expect(
          out,
          contains('forMethod'),
          reason: 'the #1034 selector section',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'A5b: after drift, explain lists the skipped method as missing',
      () async {
        greenAnalyze();
        await runCli(['mock', 'create', 'Product']);
        exitCode = exitCodeAtEntry;
        await driftMockByRemoving('update');

        final out = await runCli(['mock', 'explain', 'Product']);

        expect(exitCode, 0, reason: 'explain still reports on a drifted mock');
        expect(out, contains('update'));
        expect(out, contains('missing'), reason: 'the skipped method is named');
      },
    );

    test('A5c: usage error (no entity) → exit 2 + fix line', () async {
      final out = await runCli(['mock', 'explain']);
      expect(exitCode, ExitProtocol.usage);
      expect(out, contains('--> fix:'));
    });

    test('A6: --json carries the full report under details.explain', () async {
      greenAnalyze();
      await runCli(['mock', 'create', 'Product']);
      exitCode = exitCodeAtEntry;
      await addSelectorAndBinding();

      final out = await runCli(['mock', 'explain', 'Product', '--json']);

      expect(exitCode, 0, reason: 'output:\n$out');
      final envelope = VerdictEnvelope.tryParse(out);
      expect(envelope, isNotNull, reason: 'canonical envelope required:\n$out');
      expect(envelope!.verdict, VerdictKind.pass);
      final explain = envelope.details['explain'];
      expect(explain, isA<Map<String, dynamic>>());
      final report = explain! as Map<String, dynamic>;
      final methods = report['methods'] as List;
      expect(methods.length, 3, reason: 'one entry per interface method');
      expect(
        report['selector'],
        isA<Map<String, dynamic>>(),
        reason: 'the #1034 selector section is structured',
      );
      final selector = report['selector']! as Map<String, dynamic>;
      expect(selector['declared'], isTrue);
      expect(selector['paramType'], 'String');
      final bindings = selector['bindings'] as List;
      expect(bindings, isNotEmpty, reason: 'the on-disk binding is reported');
      expect(
        (bindings.first as Map)['expression'],
        contains('ProductMockData.forMethod(params.status)'),
      );
    });
  });
}

Future<void> _scaffoldProduct(String root) async {
  final dir = Directory(
    p.join(root, 'lib', 'src', 'domain', 'entities', 'product'),
  );
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;
  final String name;
  const Product({required this.id, required this.name});
}
''');
}
