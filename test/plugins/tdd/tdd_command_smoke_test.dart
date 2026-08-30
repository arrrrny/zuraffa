@Tags(['slow'])
// Smoke test that `zfa tdd` is registered and lists all eight subcommands
// (spec 041-tdd-setup-plugin Phase 1 / T007).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import '../../helpers/project_root.dart';

void main() {
  // Repo root, resolved once and CWD-independently, so the plan subcommand
  // runs against the real specs/ tree without relying on Directory.current.
  final repoRoot = findProjectRoot();

  test('zfa tdd --help lists all eight subcommands', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(['tdd', '--help']);
    for (final sub in [
      'init',
      'plan',
      'gen',
      'verify-red',
      'make',
      'refactor',
      'run',
      'verify',
    ]) {
      expect(
        out,
        contains(sub),
        reason: '`zfa tdd --help` output must mention subcommand: $sub',
      );
    }
  });

  test('zfa tdd --help describes verify as the mutation audit', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(['tdd', '--help']);
    // Phase 11 (T080) — `zfa tdd verify` is now a real audit, not a stub.
    // The verify line must mention mutation_test and must NOT carry the
    // "NOT YET IMPLEMENTED" misfire-stop suffix that the other subcommands
    // still carry (gen/make/refactor/run/verify-red are still honest
    // stubs pending future PRs).
    expect(out, contains('mutation_test'));
    // Extract the `verify` line specifically.
    final verifyLine = out
        .split('\n')
        .firstWhere(
          (line) => line.trimLeft().startsWith('verify '),
          orElse: () => '',
        );
    expect(verifyLine, isNotEmpty, reason: 'verify subcommand must be listed');
    expect(verifyLine.toLowerCase(), contains('mutation_test'));
    expect(verifyLine.toLowerCase(), isNot(contains('not yet implemented')));
  });

  test(
    'zfa tdd verify rejects a path-shaped --feature before auditing',
    () async {
      final tmpDir = Directory.systemTemp.createTempSync('zfa_tdd_verify_');
      // The fixture root is passed via --project so the command never
      // depends on the process-global Directory.current.
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify',
        '--project',
        tmpDir.path,
        '--feature',
        '../../etc',
      ]);
      expect(out, contains('invalid --feature'));
      // Rejected up front: the runner never announced a start, so no
      // multi-minute audit is spent before an unusable flag is caught.
      expect(out, isNot(contains('running mutation_test')));
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    },
  );

  test('zfa tdd plan on a missing spec exits non-zero', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'plan',
      'does-not-exist',
      '--project',
      await repoRoot,
    ]);
    expect(out.toLowerCase(), contains('spec not found'));
  });

  test('zfa tdd init on an empty directory is idempotent', () async {
    final tmpDir = Directory.systemTemp.createTempSync('zfa_tdd_init_smoke_');
    // The fixture root is passed via --project so the command never depends
    // on the process-global Directory.current.
    await File('${tmpDir.path}/pubspec.yaml').writeAsString('''
name: smoke
environment:
  sdk: ^3.11.0
dependencies: {}
dev_dependencies: {}
''');
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing(['tdd', 'init', '--project', tmpDir.path]);
    final runner2 = CliRunner(exitOnCompletion: false);
    await runner2.runCapturing(['tdd', 'init', '--project', tmpDir.path]);
    final smoke = File('${tmpDir.path}/test/bootstrap_smoke_test.dart');
    expect(smoke.existsSync(), isTrue);
    final profile = File('${tmpDir.path}/.specify/memory/tdd-profile.md');
    expect(profile.existsSync(), isTrue);
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });
}
