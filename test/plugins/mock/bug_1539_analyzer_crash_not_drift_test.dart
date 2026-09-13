// Issue #1539: `mock create --certify` must not convert a transient
// analysis-server crash of its verification TOOL into a drift verdict
// against a mock whose structural certification passed and whose
// `(conforms)` receipt is already persisted.
//
// RED evidence (pre-fix master, dogfood): `mock create --name Task
// --certify` persisted `.zfa/receipts/mock-task.json` (conforms) and then
// exited 1 — the child `dart analyze`'s analysis server crashed ("Bad
// state: The analysis server crashed unexpectedly." / "The analysis
// server shut down unexpectedly."), the raw tail rode a `--> fix:` line,
// and `zfa tdd make` stopped the cycle with `outcome=generation-error` on
// a step whose actual work succeeded.
//
// Contract pinned here (remediation): a crashed analyze is INFRA, not
// drift — detect the crash shape, retry the pass ONCE, and only when the
// retry crashes too AND the structural certification is clean (the
// condition the persisted receipt records as `conforms`) does the gate
// pass on the structural proof alone, exposing `analyzeUnverified` for
// the callers to disclose loudly. Real `error -` diagnostics and
// structural drift keep failing the gate — the safe-failure contract is
// unchanged.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/mock/services/mock_certification.dart';

import 'mock_cli_guard.dart';

/// The dogfood crash output (verbatim signature strings).
const _crashOutput =
    'Bad state: The analysis server crashed unexpectedly.\n'
    'The analysis server shut down unexpectedly.';

MockCertification get _cleanCertification => const MockCertification(
  registryId: 'mock-cert:product@deadbeef',
  interface: 'lib/src/data/datasources/product/product_datasource.dart',
  interfaceClass: 'ProductDataSource',
  mockFile: 'lib/src/data/datasources/product/product_mock_datasource.dart',
  mockClass: 'ProductMockDataSource',
  interfaceMethods: ['get', 'getList'],
  implementedMethods: ['get', 'getList'],
  missingMethods: [],
  inventedMethods: [],
  fixtures: [],
);

MockCertification get _driftedCertification => const MockCertification(
  registryId: 'mock-cert:product@deadbeef',
  interface: 'lib/src/data/datasources/product/product_datasource.dart',
  interfaceClass: 'ProductDataSource',
  mockFile: 'lib/src/data/datasources/product/product_mock_datasource.dart',
  mockClass: 'ProductMockDataSource',
  interfaceMethods: ['get', 'getList', 'update'],
  implementedMethods: ['get', 'getList'],
  missingMethods: ['update'],
  inventedMethods: [],
  fixtures: [],
);

void main() {
  group('gate — the analysis-server crash is infra, not drift (#1539)', () {
    test('U-1539-1: a crash retried clean passes with no fix line', () async {
      var calls = 0;
      final report = await MockCertifier().gate(
        certification: _cleanCertification,
        projectRoot: Directory.systemTemp.path,
        analyzeRunner: (files, cwd) async {
          calls++;
          return calls == 1
              ? (exitCode: 1, output: _crashOutput)
              : (exitCode: 0, output: 'Analyzing... No issues found!');
        },
      );

      expect(calls, 2, reason: 'a detected crash retries the pass ONCE');
      expect(report.passed, isTrue, reason: 'the clean retry gates normally');
      expect(report.fixLines, isEmpty);
      expect(
        report.analyzeUnverified,
        isNull,
        reason: 'the compiler verdict was obtained on the retry',
      );
    });

    test('U-1539-2: a twice-crashing analyze leaves the clean certification '
        'standing — analyzeUnverified, never a fix line', () async {
      var calls = 0;
      final report = await MockCertifier().gate(
        certification: _cleanCertification,
        projectRoot: Directory.systemTemp.path,
        analyzeRunner: (files, cwd) async {
          calls++;
          return (exitCode: 1, output: _crashOutput);
        },
      );

      expect(calls, 2, reason: 'initial pass + exactly one retry');
      expect(
        report.passed,
        isTrue,
        reason:
            'infra failure must not poison the persisted '
            '(conforms) receipt',
      );
      expect(
        report.fixLines,
        isEmpty,
        reason: 'the crash text must NOT ride a --> fix: line',
      );
      expect(
        report.analyzeUnverified,
        isNotNull,
        reason:
            'the unverified compiler verdict is disclosed, '
            'never silently skipped',
      );
      expect(
        report.analyzeUnverified,
        contains('The analysis server crashed unexpectedly'),
      );
    });

    test('U-1539-3: a twice-crashing analyze does NOT mask real structural '
        'drift — the gate still fails', () async {
      final report = await MockCertifier().gate(
        certification: _driftedCertification,
        projectRoot: Directory.systemTemp.path,
        analyzeRunner: (files, cwd) async =>
            (exitCode: 1, output: _crashOutput),
      );

      expect(
        report.passed,
        isFalse,
        reason: 'the crash must not paper over the missing member',
      );
      expect(
        report.fixLines.join('\n'),
        contains('update'),
        reason: 'the drift fix line names the missing member',
      );
      expect(
        report.analyzeUnverified,
        isNull,
        reason:
            'the certification did not stand, so there is nothing '
            'to disclose as unverified',
      );
    });

    test('U-1539-4: a real analyzer error (no crash signature) is never '
        'retried and still fails the gate', () async {
      var calls = 0;
      final report = await MockCertifier().gate(
        certification: _cleanCertification,
        projectRoot: Directory.systemTemp.path,
        analyzeRunner: (files, cwd) async {
          calls++;
          return (
            exitCode: 3,
            output:
                '  error - lib/src/data/datasources/product/'
                'product_mock_datasource.dart:12:9 - Some compile error - '
                'some_code',
          );
        },
      );

      expect(calls, 1, reason: 'only a detected crash retries');
      expect(report.passed, isFalse);
      expect(report.fixLines.join('\n'), contains('Some compile error'));
      expect(report.analyzeUnverified, isNull);
    });
  });

  group('CLI — the cycle must not stop on a crashed analyze (#1539)', () {
    late Directory tempDir;
    var exitCodeAtEntry = 0;

    setUp(() async {
      exitCodeAtEntry = exitCode;
      tempDir = await Directory.systemTemp.createTemp('mock_certify_1539_');
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
      // The cwd lock: Directory.current is process-wide (issue #970).
      return CwdGuard.exclusive(
        () => runner.runCapturing(['-C', tempDir.path, ...args]),
      );
    }

    test('U-1539-5: mock create --certify exits 0 with a loud UNVERIFIED '
        'disclosure when the analyze crashes on both passes', () async {
      MockCertifier.analyzeRunnerOverride = (files, cwd) async =>
          (exitCode: 1, output: _crashOutput);

      final out = await runCli(['mock', 'create', 'Product', '--certify']);

      expect(
        exitCode,
        0,
        reason:
            'the structural certification stands; a tool crash is '
            'not a generation failure, output:\n$out',
      );
      expect(out, contains('mock-cert:product@'));
      expect(
        out,
        isNot(contains('--> fix:')),
        reason: 'the crash text must not ride a fix line',
      );
      expect(
        out,
        contains('UNVERIFIED'),
        reason: 'the disclosure is loud, never a silent pass',
      );
      expect(
        out,
        contains('zfa mock verify'),
        reason: 'the disclosure names the re-proof path',
      );
      exitCode = exitCodeAtEntry;
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('U-1539-6: mock verify shares the classification — exit 0 + the '
        'disclosure, and no crash-tail analyze_error finding', () async {
      MockCertifier.analyzeRunnerOverride = (files, cwd) async =>
          (exitCode: 0, output: 'ok');
      await runCli(['mock', 'create', 'Product']);
      exitCode = exitCodeAtEntry;

      MockCertifier.analyzeRunnerOverride = (files, cwd) async =>
          (exitCode: 1, output: _crashOutput);
      final out = await runCli(['mock', 'verify', 'Product']);

      expect(
        exitCode,
        0,
        reason:
            'same machinery as mock certify (spec 1121 AC): a tool '
            'crash is not mock drift, output:\n$out',
      );
      expect(out, contains('UNVERIFIED'));
      expect(out, isNot(contains('--> fix:')));
      exitCode = exitCodeAtEntry;
    }, timeout: const Timeout(Duration(minutes: 3)));
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
