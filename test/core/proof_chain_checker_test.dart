import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/proof/proof_chain_checker.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/core/project/test_receipt.dart';

/// Issue #1148 — `ProofChainChecker` unit contract (spec 1334).
///
/// Every fixture is a temp-dir project; the checker is driven directly
/// (pure core, no CLI) so each of the six checks is asserted in
/// isolation. The CLI surface (exit codes, --json) is covered by
/// `test/commands/proof_chain_command_test.dart`.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zfa_proof_chain_');
  });

  tearDown(() {
    if (root.existsSync()) {
      try {
        root.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  String path(String relative) => p.join(root.path, relative);

  Future<File> write(String relative, String content) async {
    final file = File(path(relative));
    await file.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  Future<void> seedReceipt(GenerationReceipt receipt) async {
    await ReceiptStore(projectRoot: root.path).save(receipt);
  }

  GenerationReceiptFile fileEntry(String relative, String content) {
    final bytes = const Utf8Encoder().convert(content);
    return GenerationReceiptFile(
      path: relative,
      action: 'create',
      sha256: crypto.sha256.convert(bytes).toString(),
      bytes: bytes.length,
      snapshot: content,
    );
  }

  GenerationReceipt receipt(
    String command,
    String target,
    List<GenerationReceiptFile> files,
  ) => GenerationReceipt(
    command: command,
    target: target,
    repro: 'zfa $command $target',
    at: DateTime.utc(2026, 9, 9, 10),
    generatorVersion: '6.2.2',
    input: const {},
    files: files,
  );

  /// A minimal green cycle-log entry (the machine format CycleEvidence
  /// parses) for [behaviorId], naming [testPath] on its `- test:` line.
  Future<void> seedGreenEvidence(
    String feature,
    String behaviorId,
    String testPath,
  ) async {
    await write(
      p.posix.join('specs', feature, 'tdd', 'cycle-log.md'),
      '# Cycle Log\n'
      '\n'
      '## Cycle: $behaviorId (green)\n'
      '\n'
      '- behavior: $behaviorId\n'
      '- kind: green\n'
      '- test: $testPath\n'
      '- exit: 0\n'
      '- at: 2026-09-09T00:00:00.000Z\n',
    );
    // The green evidence names a real test file by default.
    await write(testPath, 'void main() {}\n');
  }

  const driftSev = ProofChainSeverity.drift;
  const gapSev = ProofChainSeverity.gap;

  group('B1 — verdict model invariants', () {
    test(
      'item JSON carries category, severity, file, expected, actual, fix',
      () async {
        final item = ProofChainItem(
          check: ProofChainCheckKind.receiptDigest,
          severity: ProofChainSeverity.drift,
          category: 'receipt_digest',
          file: 'lib/a.dart',
          expected: 'digest-expected',
          actual: 'digest-actual',
          fix: 'zfa make',
        );
        final json = item.toJson();
        expect(json['category'], 'receipt_digest');
        expect(json['severity'], 'drift');
        expect(json['file'], 'lib/a.dart');
        expect(json['expected'], 'digest-expected');
        expect(json['actual'], 'digest-actual');
        expect(json['fix'], 'zfa make');
        expect(json['check'], 'receipt_digest');
      },
    );

    test('report JSON: schema, ok, exitClass, counts, items', () async {
      final report = ProofChainReport(
        items: [
          ProofChainItem(
            check: ProofChainCheckKind.receiptDigest,
            severity: ProofChainSeverity.drift,
            category: 'receipt_digest',
            file: 'f',
            expected: 'e',
            actual: 'a',
            fix: 'fix',
          ),
          ProofChainItem(
            check: ProofChainCheckKind.behaviorCoverage,
            severity: ProofChainSeverity.gap,
            category: 'behavior_coverage',
            file: 'g',
            expected: 'green evidence',
            actual: 'none',
            fix: 'zfa tdd run x',
          ),
        ],
      );
      final json = report.toJson();
      expect(json['schema'], 'proof-chain.v1');
      expect(json['ok'], isFalse);
      expect(json['exitClass'], 'drift');
      expect(json['exitCode'], 1);
      expect((json['counts'] as Map<String, dynamic>)['receiptDigest'], 1);
      expect((json['counts'] as Map<String, dynamic>)['behaviorCoverage'], 1);
      expect((json['items'] as List), hasLength(2));
      expect(report.driftCount, 1);
      expect(report.gapCount, 1);
    });

    test('gap-only report keeps ok true and exit 0', () {
      final report = ProofChainReport(
        items: [
          ProofChainItem(
            check: ProofChainCheckKind.behaviorCoverage,
            severity: ProofChainSeverity.gap,
            category: 'behavior_coverage',
            file: 'g',
            expected: 'green evidence',
            actual: 'none',
            fix: 'zfa tdd run x',
          ),
        ],
      );
      expect(report.ok, isTrue);
      expect(report.exitCode, 0);
    });

    test('infra errors set exit 2', () {
      final report = ProofChainReport(
        items: const [],
        infraErrors: const ['receipts directory unreadable'],
      );
      expect(report.ok, isFalse);
      expect(report.exitCode, 2);
      expect(report.toJson()['exitClass'], 'infra');
    });
  });

  group('B2 — clean project vacuous green', () {
    test('no .zfa and no specs -> ok, zero items, zero counts', () async {
      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(report.ok, isTrue);
      expect(report.items, isEmpty);
      expect(report.infraErrors, isEmpty);
      expect(report.exitCode, 0);
      final counts = report.toJson()['counts'] as Map<String, dynamic>;
      for (final value in counts.values) {
        expect(value, 0);
      }
    });
  });

  group('B3 — receipt digest drift', () {
    test(
      'edited artifact -> receipt_digest drift with expected/actual',
      () async {
        final entry = fileEntry('lib/src/product.dart', 'class Product {}\n');
        await write(entry.path, entry.snapshot!);
        await seedReceipt(receipt('entity create', 'Product', [entry]));
        // Hand-edit after generation.
        await write(entry.path, 'class Product { /* drifted */ }\n');

        final report = await ProofChainChecker(projectRoot: root.path).check();

        final drift = report.items
            .where((i) => i.severity == driftSev)
            .toList();
        expect(drift, isNotEmpty);
        final digestItem = drift.firstWhere(
          (i) => i.category == 'receipt_digest',
        );
        expect(digestItem.file, entry.path);
        expect(digestItem.expected, entry.sha256);
        final actual = crypto.sha256
            .convert(File(path(entry.path)).readAsBytesSync())
            .toString();
        expect(digestItem.actual, actual);
        expect(digestItem.fix, contains('zfa entity create Product'));
        expect(report.exitCode, 1);
      },
    );

    test('deleted receipted artifact -> drift', () async {
      final entry = fileEntry('lib/src/product.dart', 'class Product {}\n');
      await write(entry.path, entry.snapshot!);
      await seedReceipt(receipt('entity create', 'Product', [entry]));
      File(path(entry.path)).deleteSync();

      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(
        report.items.any(
          (i) =>
              i.category == 'receipt_digest' &&
              i.severity == driftSev &&
              i.file == entry.path,
        ),
        isTrue,
        reason: 'deleted artifact must surface as drift: ${report.items}',
      );
      expect(report.exitCode, 1);
    });

    test('matching artifact -> no receipt_digest item', () async {
      final entry = fileEntry('lib/src/product.dart', 'class Product {}\n');
      await write(entry.path, entry.snapshot!);
      await seedReceipt(receipt('entity create', 'Product', [entry]));

      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(
        report.items.where((i) => i.category == 'receipt_digest'),
        isEmpty,
      );
    });

    test('test.v1 receipts join the digest walk', () async {
      final testPath = 'test/product_usecase_test.dart';
      final content = 'void main() {}\n';
      await write(testPath, content);
      final entry = TestReceiptEntry(
        name: 'get succeeds',
        testPath: testPath,
        method: 'get',
        acceptancePath: 'success',
        testSha256: crypto.sha256.convert(utf8.encode(content)).toString(),
      );
      await TestReceiptStore(projectRoot: root.path).write(
        TestReceipt(
          entity: 'Product',
          command: 'zfa test gen',
          at: DateTime.utc(2026, 9, 9, 10),
          tests: [entry],
        ),
      );
      // Drift the test file.
      await write(testPath, 'void main() { print("drift"); }\n');

      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(
        report.items.any(
          (i) =>
              i.category == 'receipt_digest' &&
              i.file == testPath &&
              i.severity == driftSev,
        ),
        isTrue,
      );
    });
  });

  group('B5 — behavior coverage', () {
    test('green-covered behavior -> no item', () async {
      await write(
        p.posix.join('specs', 'f1', 'tdd', 'test-list.md'),
        '# Test List\n\n## Behaviors\n\n'
        '| # | Behavior | Trace | Test file |\n'
        '|---|----------|-------|-----------|\n'
        '| B1 | does x | FR-1 | test/x_test.dart |\n',
      );
      await seedGreenEvidence('f1', 'B1', 'test/x_test.dart');

      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(
        report.items.where((i) => i.category == 'behavior_coverage'),
        isEmpty,
      );
    });

    test('behavior without green evidence -> gap with tdd run fix', () async {
      await write(
        p.posix.join('specs', 'f1', 'tdd', 'test-list.md'),
        '# Test List\n\n## Behaviors\n\n'
        '| # | Behavior | Trace | Test file |\n'
        '|---|----------|-------|-----------|\n'
        '| B2 | does y | FR-2 | test/y_test.dart |\n',
      );

      final report = await ProofChainChecker(projectRoot: root.path).check();
      final gaps = report.items
          .where(
            (i) =>
                i.category == 'behavior_coverage' &&
                i.severity == ProofChainSeverity.gap,
          )
          .toList();
      expect(gaps, hasLength(1));
      expect(gaps.single.file, contains('specs/f1/tdd/test-list.md'));
      expect(gaps.single.expected, contains('B2'));
      expect(gaps.single.fix, contains('zfa tdd run f1'));
      // Gap-only verdict stays exit 0.
      expect(report.exitCode, 0);
      expect(report.ok, isTrue);
    });

    test(
      'green evidence naming a missing test file -> test_integrity drift',
      () async {
        await write(
          p.posix.join('specs', 'f1', 'tdd', 'test-list.md'),
          '# Test List\n\n## Behaviors\n\n'
          '| # | Behavior | Trace | Test file |\n'
          '|---|----------|-------|-----------|\n'
          '| B1 | does x | FR-1 | test/gone_test.dart |\n',
        );
        // Green evidence for B1 whose - test: file does NOT exist.
        await write(
          p.posix.join('specs', 'f1', 'tdd', 'cycle-log.md'),
          '# Cycle Log\n\n## Cycle: B1 (green)\n\n'
          '- behavior: B1\n'
          '- kind: green\n'
          '- test: test/gone_test.dart\n'
          '- exit: 0\n'
          '- at: 2026-09-09T00:00:00.000Z\n',
        );

        final report = await ProofChainChecker(projectRoot: root.path).check();
        expect(
          report.items.any(
            (i) =>
                i.category == 'test_integrity' &&
                i.severity == driftSev &&
                i.file == 'test/gone_test.dart',
          ),
          isTrue,
          reason: 'evidence-without-artifact is drift: ${report.items}',
        );
        expect(report.exitCode, 1);
      },
    );
  });

  group('B6 — generated test integrity', () {
    Future<void> seedRegistry(String testPath) => write(
      p.posix.join('specs', 'f1', 'tdd', 'artifacts.json'),
      jsonEncode({
        'feature': 'f1',
        'records': [
          {
            'behavior_id': 'B1',
            'feature': 'f1',
            'source_criterion': 'FR-1',
            'test_path': testPath,
            'subject_path': 'lib/subject.dart',
            'runnable_test_name': '$testPath::B1::does x',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-09-09T00:00:00.000Z',
          },
        ],
      }),
    );

    test('registered test file missing from disk -> drift', () async {
      await seedRegistry('test/missing_test.dart');

      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(
        report.items.any(
          (i) =>
              i.category == 'test_integrity' &&
              i.severity == driftSev &&
              i.file == 'test/missing_test.dart',
        ),
        isTrue,
      );
    });

    test('unresolved import -> drift naming the URI', () async {
      await seedRegistry('test/import_test.dart');
      await write(
        'test/import_test.dart',
        "import '../gone/helper.dart';\n\nvoid main() {}\n",
      );

      final report = await ProofChainChecker(projectRoot: root.path).check();
      final drift = report.items.where(
        (i) =>
            i.category == 'test_integrity' &&
            i.severity == driftSev &&
            i.file == 'test/import_test.dart',
      );
      expect(drift, isNotEmpty);
      expect(drift.first.actual, contains('../gone/helper.dart'));
    });

    test('healthy registration -> no item', () async {
      await seedRegistry('test/healthy_test.dart');
      await write(
        'test/healthy_test.dart',
        "import 'package:test/test.dart';\n\nvoid main() {}\n",
      );

      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(
        report.items.where((i) => i.category == 'test_integrity'),
        isEmpty,
        reason: '${report.items}',
      );
    });
  });

  group('B7 — --run-tests execution', () {
    test('injected runner exit 0 -> no item', () async {
      await write(
        p.posix.join('specs', 'f1', 'tdd', 'artifacts.json'),
        jsonEncode({
          'feature': 'f1',
          'records': [
            {
              'behavior_id': 'B1',
              'feature': 'f1',
              'source_criterion': 'FR-1',
              'test_path': 'test/ok_test.dart',
              'subject_path': 'lib/subject.dart',
              'runnable_test_name': 'test/ok_test.dart::B1::x',
              'test_ownership': 'created',
              'subject_ownership': 'created',
              'created_at': '2026-09-09T00:00:00.000Z',
            },
          ],
        }),
      );
      await write('test/ok_test.dart', 'void main() {}\n');

      var invoked = 0;
      final report = await ProofChainChecker(
        projectRoot: root.path,
        testRunner: (executable, args, {String? workingDirectory}) async {
          invoked++;
          return ProcessResult(1, 0, 'All tests passed!', '');
        },
      ).check(runTests: true);

      expect(invoked, 1, reason: 'the registered test must be executed');
      expect(report.items.where((i) => i.category == 'test_runtime'), isEmpty);
    });

    test(
      'injected runner non-zero -> test_runtime drift with exit code',
      () async {
        await write(
          p.posix.join('specs', 'f1', 'tdd', 'artifacts.json'),
          jsonEncode({
            'feature': 'f1',
            'records': [
              {
                'behavior_id': 'B1',
                'feature': 'f1',
                'source_criterion': 'FR-1',
                'test_path': 'test/fail_test.dart',
                'subject_path': 'lib/subject.dart',
                'runnable_test_name': 'test/fail_test.dart::B1::x',
                'test_ownership': 'created',
                'subject_ownership': 'created',
                'created_at': '2026-09-09T00:00:00.000Z',
              },
            ],
          }),
        );
        await write('test/fail_test.dart', 'void main() {}\n');

        final report = await ProofChainChecker(
          projectRoot: root.path,
          testRunner: (executable, args, {String? workingDirectory}) async =>
              ProcessResult(1, 1, 'some test failed', 'stderr tail'),
        ).check(runTests: true);

        final runtime = report.items
            .where(
              (i) => i.category == 'test_runtime' && i.severity == driftSev,
            )
            .toList();
        expect(runtime, hasLength(1));
        expect(runtime.single.file, 'test/fail_test.dart');
        expect(runtime.single.actual, contains('exit 1'));
        expect(runtime.single.actual, contains('some test failed'));
        expect(report.exitCode, 1);
      },
    );

    test('flag off -> info item, runtime never claimed', () async {
      await write(
        p.posix.join('specs', 'f1', 'tdd', 'artifacts.json'),
        jsonEncode({
          'feature': 'f1',
          'records': [
            {
              'behavior_id': 'B1',
              'feature': 'f1',
              'source_criterion': 'FR-1',
              'test_path': 'test/skip_test.dart',
              'subject_path': 'lib/subject.dart',
              'runnable_test_name': 'test/skip_test.dart::B1::x',
              'test_ownership': 'created',
              'subject_ownership': 'created',
              'created_at': '2026-09-09T00:00:00.000Z',
            },
          ],
        }),
      );
      await write('test/skip_test.dart', 'void main() {}\n');

      var invoked = 0;
      final report = await ProofChainChecker(
        projectRoot: root.path,
        testRunner: (executable, args, {String? workingDirectory}) async {
          invoked++;
          return ProcessResult(1, 0, '', '');
        },
      ).check(); // runTests defaults to false.

      expect(invoked, 0, reason: 'default must spawn nothing');
      final info = report.items
          .where(
            (i) =>
                i.category == 'test_runtime' &&
                i.severity == ProofChainSeverity.info,
          )
          .toList();
      expect(info, isNotEmpty);
      expect(info.first.actual, contains('not exercised'));
      expect(report.exitCode, 0);
    });
  });

  group('B8 — route verification', () {
    Future<void> seedRouteTable({
      bool verify = false,
      String verdict = 'pass',
      bool ok = true,
    }) async {
      await ReceiptStore(projectRoot: root.path).saveNamed(
        'routes-Product.json',
        receipt('zfa route create', 'Product', const []),
      );
      if (verify) {
        await ReceiptStore(projectRoot: root.path).saveNamed(
          'routes-Product-verify.json',
          GenerationReceipt(
            command: 'zfa route verify',
            target: 'Product',
            repro: 'zfa route verify Product',
            at: DateTime.utc(2026, 9, 9, 11),
            generatorVersion: '6.2.2',
            input: {
              'verdict': verdict,
              if (verdict == 'skip') 'reason': 'no router yet',
            },
            files: const [],
          ),
          extra: {
            'verdict': {
              'ok': ok,
              'routes': const <String>[],
              'findings': const <String>[],
            },
          },
        );
      }
    }

    test('failed verify verdict -> route_verify drift', () async {
      await seedRouteTable(verify: true, verdict: 'fail', ok: false);

      final report = await ProofChainChecker(projectRoot: root.path).check();
      final drift = report.items.where(
        (i) => i.category == 'route_verify' && i.severity == driftSev,
      );
      expect(drift, isNotEmpty);
      expect(drift.single.file, contains('routes-Product-verify.json'));
      expect(drift.single.fix, contains('zfa route verify Product'));
      expect(report.exitCode, 1);
    });

    test('missing verify receipt -> route_verify gap', () async {
      await seedRouteTable();

      final report = await ProofChainChecker(projectRoot: root.path).check();
      final gap = report.items.where(
        (i) => i.category == 'route_verify' && i.severity == gapSev,
      );
      expect(gap, isNotEmpty);
      expect(gap.single.file, contains('routes-Product.json'));
      expect(gap.single.fix, contains('zfa route verify Product'));
      expect(report.exitCode, 0, reason: 'gaps never fail');
    });

    test('skip-with-reason -> info, never drift', () async {
      await seedRouteTable(verify: true, verdict: 'skip', ok: false);

      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(
        report.items.where(
          (i) => i.category == 'route_verify' && i.severity == driftSev,
        ),
        isEmpty,
      );
      final info = report.items.where(
        (i) =>
            i.category == 'route_verify' &&
            i.severity == ProofChainSeverity.info,
      );
      expect(info, isNotEmpty);
      expect(info.single.actual, contains('no router yet'));
      expect(report.exitCode, 0);
    });

    test('passing verify -> no route_verify item', () async {
      await seedRouteTable(verify: true, verdict: 'pass', ok: true);

      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(report.items.where((i) => i.category == 'route_verify'), isEmpty);
    });
  });

  group('B9 — usecase verification', () {
    Future<void> seedUsecaseReceipt() async {
      await ReceiptStore(projectRoot: root.path).saveCapability(
        GenerationReceipt(
          command: 'zfa usecase create',
          target: 'Product',
          repro: 'zfa usecase create Product',
          at: DateTime.utc(2026, 9, 9, 12),
          generatorVersion: '6.2.2',
          input: const {},
          files: const [],
          plugin: 'usecase',
          capability: 'create',
          entity: 'Product',
          methodset: const ['get', 'create'],
        ),
      );
    }

    test('no usecase receipts -> vacuous green', () async {
      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(
        report.items.where((i) => i.category == 'usecase_verify'),
        isEmpty,
      );
    });

    test('receipt entity with no generated usecase tree -> gap', () async {
      await seedUsecaseReceipt();
      final report = await ProofChainChecker(projectRoot: root.path).check();
      final items = report.items.where((i) => i.category == 'usecase_verify');
      expect(items, isNotEmpty);
      expect(
        items.every((i) => i.severity != driftSev),
        isTrue,
        reason: 'missing artifacts are gaps, not errors: ${report.items}',
      );
      expect(items.first.fix, contains('Product'));
      expect(report.exitCode, 0);
    });
  });

  group('B10 — xray coverage traceability', () {
    Future<void> seedLedger(String rows) => write(
      p.posix.join('specs', 'f1', 'tdd', 'ui-ledger.md'),
      '# UI Surface Ledger\n\n'
      '| surface | kind | proven by | state |\n'
      '| --- | --- | --- | --- |\n'
      '$rows',
    );

    test('row with a green prover -> traced, no item', () async {
      await seedLedger('| Sign In | text | B1 | DONE |\n');
      await write(
        p.posix.join('specs', 'f1', 'tdd', 'test-list.md'),
        '# Test List\n\n## Behaviors\n\n'
        '| # | Behavior | Trace | Test file |\n'
        '|---|----------|-------|-----------|\n'
        '| B1 | sees Sign In | FR-1 | test/signin_test.dart |\n',
      );
      await seedGreenEvidence('f1', 'B1', 'test/signin_test.dart');

      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(
        report.items.where((i) => i.category == 'xray_coverage'),
        isEmpty,
        reason: '${report.items}',
      );
    });

    test(
      'row without green prover -> xray_coverage gap naming kind+surface',
      () async {
        await seedLedger('| Sign In | text | B1 | DONE |\n');
        // No green evidence anywhere.

        final report = await ProofChainChecker(projectRoot: root.path).check();
        final gaps = report.items.where(
          (i) => i.category == 'xray_coverage' && i.severity == gapSev,
        );
        expect(gaps, hasLength(1));
        expect(gaps.single.file, contains('specs/f1/tdd/ui-ledger.md'));
        expect(gaps.single.expected, contains('Sign In'));
        expect(gaps.single.expected, contains('text'));
        expect(gaps.single.actual, contains('no green'));
        expect(report.exitCode, 0);
      },
    );

    test('no ledger file -> no items', () async {
      final report = await ProofChainChecker(projectRoot: root.path).check();
      expect(report.items.where((i) => i.category == 'xray_coverage'), isEmpty);
    });
  });

  group('B11 — read-only auditor', () {
    test('check() leaves every input file unchanged', () async {
      final entry = fileEntry('lib/src/product.dart', 'class Product {}\n');
      await write(entry.path, entry.snapshot!);
      await seedReceipt(receipt('entity create', 'Product', [entry]));
      final ledger = await write(
        p.posix.join('specs', 'f1', 'tdd', 'ui-ledger.md'),
        '# UI Surface Ledger\n\n| surface | kind | proven by | state |\n'
        '| --- | --- | --- | --- |\n| Sign In | text | B1 | DONE |\n',
      );
      final before = {
        path(entry.path): File(path(entry.path)).readAsBytesSync(),
        ledger.path: ledger.readAsBytesSync(),
      };
      final mtimes = {
        for (final f in before.keys) f: File(f).lastModifiedSync(),
      };

      await ProofChainChecker(projectRoot: root.path).check();

      for (final file in before.keys) {
        expect(
          File(file).readAsBytesSync(),
          before[file],
          reason: 'checker must not modify $file',
        );
        expect(
          File(file).lastModifiedSync(),
          mtimes[file],
          reason: 'checker must not touch mtime of $file',
        );
      }
    });
  });
}
