// Issue #2010: `zfa mock create <Entity> --certify` in an unresolved
// project (no `.dart_tool/`) reported three mutually contradictory
// signals in one run — `❌ … does not conform` + fix lines from the
// #970 gate, a `✅ Success! Created/Modified:` banner, and a
// `📜 mock-certification: … (conforms)` tail backed by a PERSISTED
// receipt — while the `--json` envelope claimed `verdict: pass` /
// `exit_class: 0` and the process still exited 1.
//
// Root cause (mock_command.dart `_runMockGeneration`): the receipt was
// written BEFORE the gate ran, the gate failure never returned, the
// success banner keyed off file actions only, and `conformanceFailed`
// ignored the gate verdict — so every output surface but the ❌ block
// reported success for a failed gate.
//
// Contract pinned here (remediation): a FAILED gate is the run's single
// signal. The run must not print the success banner, must not print a
// `(conforms)` certification tail, must not persist a receipt that
// claims conformance, and the `--json` envelope must say
// `verdict: fail` / `exit_class: 1`. A PASSING gate keeps every
// existing surface, including the persisted receipt.
//
// The gate failure is produced deterministically through the fast-tier
// analyze seam — the same verdict the real analyzer produced in the
// issue's unresolved-project repro (`uri_does_not_exist` over the
// emitted files), without paying a real `dart analyze` subprocess.
library;

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
    exitCodeAtEntry = CliRunner.lastDispatchedExitCode;
    tempDir = await Directory.systemTemp.createTemp('zfa_2010_');
    _scaffoldProduct(tempDir.path);
  });

  tearDown(() async {
    exitCode = exitCodeAtEntry;
    // Restore the production analyze runner (static test seam).
    MockCertifier.analyzeRunnerOverride = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// The receipt a `--certify` run persists for the Product mock.
  File productReceipt() =>
      File(p.join(tempDir.path, '.zfa', 'receipts', 'mock-product.json'));

  /// Deterministic red analyze stub: the gate's scoped `dart analyze`
  /// fails over the emitted files (the issue's unresolved-project shape —
  /// `package:zuraffa/…` cannot resolve without `dart pub get`).
  void redAnalyze() {
    MockCertifier.analyzeRunnerOverride = (files, cwd) async => (
      exitCode: 3,
      output:
          "  error - lib/src/data/datasources/product/product_datasource.dart:"
          "5:8 - Target of URI doesn't exist: 'package:zuraffa/zuraffa.dart'."
          " - uri_does_not_exist",
    );
  }

  /// Deterministic green analyze stub: the gate's scoped `dart analyze`
  /// is clean.
  void greenAnalyze() {
    MockCertifier.analyzeRunnerOverride = (files, cwd) async =>
        (exitCode: 0, output: 'Analyzing ... No issues found!');
  }

  Future<String> runCli(List<String> args) => CwdGuard.exclusive(
    () => CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['-C', tempDir.path, ...args]),
  );

  group('#2010 — a failed --certify gate is the run\'s single signal', () {
    test('human mode: no ✅ Success banner, no (conforms) tail, no '
        'persisted receipt', () async {
      redAnalyze();
      final out = await runCli(['mock', 'create', 'Product', '--certify']);

      expect(
        CliRunner.lastDispatchedExitCode,
        1,
        reason: 'the gate failure exits 1, output:\n$out',
      );
      expect(
        out,
        contains('❌ mock certification'),
        reason: 'the gate refusal is the failure signal',
      );
      expect(
        out,
        contains('--> fix:'),
        reason: 'the refusal carries the analyzer fix lines',
      );
      expect(
        out,
        isNot(contains('✅ Success!')),
        reason: 'a failed gate must not print the success banner',
      );
      expect(
        out,
        isNot(contains('📜 mock-certification')),
        reason: 'a failed gate must not print the certification tail',
      );
      expect(
        out,
        isNot(contains('(conforms)')),
        reason: 'no output may claim conformance after a failed gate',
      );
      expect(
        productReceipt().existsSync(),
        isFalse,
        reason:
            'a failed gate must not persist a receipt that claims '
            'conformance',
      );
    });

    test('--json: the envelope says verdict fail / exit_class 1 with no '
        'receipt claim', () async {
      redAnalyze();
      final out = await runCli([
        'mock',
        'create',
        'Product',
        '--certify',
        '--json',
      ]);

      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.failure,
        reason: 'the gate failure exits 1, output:\n$out',
      );
      final envelope = VerdictEnvelope.tryParse(out);
      expect(
        envelope,
        isNotNull,
        reason:
            'the stdout must still be exactly one canonical envelope:\n'
            '$out',
      );
      expect(
        envelope!.verdict,
        VerdictKind.fail,
        reason:
            'the gate verdict is part of the machine contract — a '
            'failed gate can never ride a pass envelope',
      );
      expect(envelope.exitClass, ExitProtocol.failure);
      expect(
        envelope.receipts,
        isEmpty,
        reason:
            'the envelope must not claim a receipt the failed gate '
            'never wrote',
      );
      expect(
        productReceipt().existsSync(),
        isFalse,
        reason: 'no persisted receipt on the --json failure path either',
      );
    });

    test(
      'a PASSING gate keeps every existing surface, receipt included',
      () async {
        greenAnalyze();
        final out = await runCli(['mock', 'create', 'Product', '--certify']);

        expect(
          CliRunner.lastDispatchedExitCode,
          0,
          reason: 'a conforming mock passes the gate, output:\n$out',
        );
        expect(out, contains('✅ Success!'));
        expect(out, contains('(conforms)'));
        expect(
          productReceipt().existsSync(),
          isTrue,
          reason: 'the passing gate persists the receipt as before',
        );
      },
    );
  });
}

void _scaffoldProduct(String root) {
  final dir = Directory(
    p.join(root, 'lib', 'src', 'domain', 'entities', 'product'),
  );
  dir.createSync(recursive: true);
  // The same #1747 surface the sibling gate tests scaffold: identity,
  // `copyWithField`, and a `<Type>Patch` companion (the CRUD pair's body
  // calls all three).
  File(p.join(dir.path, 'product.dart')).writeAsStringSync('''
class Product {
  final String id;
  final String name;
  const Product({required this.id, required this.name});

  Product copyWithField(Object field, Object? value) => this;
}

class ProductPatch {}
''');
}
