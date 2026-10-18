import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';

void main() {
  late CliRunner runner;
  late Directory tmp;

  setUp(() async {
    runner = CliRunner(exitOnCompletion: false);
    tmp = await Directory.systemTemp.createTemp('budget_cmd_review_');
    await File(p.join(tmp.path, 'pubspec.yaml')).writeAsString(
      'name: sandbox\nenvironment:\n  sdk: \'>=3.0.0 <4.0.0\'\n',
    );
  });

  tearDown(() async {
    exitCode = 0;
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<String> drive(List<String> args) =>
      runner.runCapturing(['-C', tmp.path, 'budget', 'check', ...args]);

  test('JSON verdict passes with no budgets and --skip-tests', () async {
    await File(p.join(tmp.path, 'zfa.yaml')).writeAsString('budgets: {}\n');
    final out = await drive(['--format', 'json', '--skip-tests']);
    final json = jsonDecode(out) as Map<String, dynamic>;
    expect(json['passed'], isTrue);
    expect(CliRunner.lastDispatchedExitCode, ExitProtocol.success);
  });

  test('violation exits 1 when lib output exceeds budget', () async {
    final libDir = Directory(p.join(tmp.path, 'lib'))..createSync();
    await File(p.join(libDir.path, 'a.txt')).writeAsString('hello');
    await File(p.join(tmp.path, 'zfa.yaml'))
        .writeAsString('budgets:\n  generated_output_size_bytes: 0\n');
    final out = await drive(['--format', 'json', '--skip-tests']);
    final json = jsonDecode(out) as Map<String, dynamic>;
    expect(json['passed'], isFalse);
    expect((json['violations'] as List).isNotEmpty, isTrue);
    expect(CliRunner.lastDispatchedExitCode, ExitProtocol.failure);
  });

  test('unknown format exits 2 (usage)', () async {
    await drive(['--format', 'foo', '--skip-tests']);
    expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
  });

  test('malformed zfa.yaml is not masked (non-zero verdict)', () async {
    await File(p.join(tmp.path, 'zfa.yaml')).writeAsString('budgets: [1,2,3]\n');
    final out = await drive(['--format', 'json', '--skip-tests']);
    final json = jsonDecode(out) as Map<String, dynamic>;
    expect(json['passed'], isFalse);
    expect(CliRunner.lastDispatchedExitCode, ExitProtocol.failure);
  });
}
