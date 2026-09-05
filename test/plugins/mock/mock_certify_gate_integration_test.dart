// T004 integration tier (issue #970, FR-004): the REAL `dart analyze`
// subprocess over the emitted mock files in a pub-resolved fixture — the
// exact CLI default path (no analyzeRunnerOverride).
//
// Validated contract: a conforming service-mode mock analyzes clean
// (exit 0); a mock drifted by one removed method fails the gate with
// exit 1 and a `--> fix:` line naming the missing member
// (`non_abstract_class_inherits_abstract_member` from the analyzer, plus
// the structural check's precise member name).
@Tags(['slow', 'integration'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'mock_cli_guard.dart';

void main() {
  late Directory tempDir;
  var exitCodeAtEntry = 0;

  setUp(() async {
    exitCodeAtEntry = exitCode;
    tempDir = await Directory.systemTemp.createTemp('mock_certify_int_970_');
    // A pub-resolved fixture: the generated mock imports
    // `package:zuraffa/mock.dart`, which resolves through the path dep.
    await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: mock_certify_integration
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: ${p.current}
''');
    await Directory(
      p.join(tempDir.path, 'lib', 'src', 'domain', 'entities', 'payment'),
    ).create(recursive: true);
    await File(
      p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'entities',
        'payment',
        'payment.dart',
      ),
    ).writeAsString('''
class Payment {
  final String id;
  const Payment({required this.id});
}
''');
    await Directory(
      p.join(tempDir.path, 'lib', 'src', 'domain', 'services'),
    ).create(recursive: true);
    await File(
      p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'services',
        'payment_service.dart',
      ),
    ).writeAsString('''
import 'dart:async';

abstract class PaymentService {
  Future<String> processPayment(String params);
  Stream<double> watchRefunds(double params);
}
''');
    final pubGet = await Process.run('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: tempDir.path);
    expect(
      pubGet.exitCode,
      0,
      reason: 'fixture pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
    );
  });

  tearDown(() async {
    exitCode = exitCodeAtEntry;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('A6/A7 (real analyzer): --certify passes on a conforming mock and '
      'fails exit 1 + --> fix: on drift', () async {
    final runner = CliRunner(exitOnCompletion: false);

    // Conforming: fresh generation + the REAL scoped dart analyze.
    final ok = await CwdGuard.exclusive(
      () => runner.runCapturing([
        '-C',
        tempDir.path,
        'mock',
        'create',
        'Payment',
        '--service',
        'Payment',
        '--certify',
      ]),
    );
    expect(
      exitCode,
      0,
      reason: 'conforming mock passes the real analyzer gate:\n$ok',
    );
    expect(ok, contains('mock-cert:payment@'));
    exitCode = exitCodeAtEntry;

    // Drift: remove one method from the emitted mock provider.
    final provider = File(
      p.join(
        tempDir.path,
        'lib',
        'src',
        'data',
        'providers',
        'payment',
        'payment_mock_provider.dart',
      ),
    );
    expect(provider.existsSync(), isTrue, reason: 'the mock provider exists');
    final src = await provider.readAsString();
    final decl = RegExp(r'\w+(?:<[^>(]*>)?\s+processPayment\(');
    final match = decl.firstMatch(src);
    expect(match, isNotNull, reason: 'processPayment exists to drift');
    final methodStart = src.lastIndexOf('  @override', match!.start);
    final nextOverride = src.indexOf('  @override', match.end);
    await provider.writeAsString(
      src.replaceRange(methodStart, nextOverride, ''),
    );

    // Re-run without --force: generation skips the drifted file, the
    // gate must refuse it.
    final refused = await CwdGuard.exclusive(
      () => runner.runCapturing([
        '-C',
        tempDir.path,
        'mock',
        'create',
        'Payment',
        '--service',
        'Payment',
        '--certify',
      ]),
    );
    expect(exitCode, 1, reason: 'drifted mock fails the real analyzer gate');
    expect(refused, contains('--> fix:'));
    expect(
      refused,
      contains('processPayment'),
      reason: 'the fix line names the drifted member',
    );
    exitCode = exitCodeAtEntry;
  }, timeout: const Timeout(Duration(minutes: 5)));
}
