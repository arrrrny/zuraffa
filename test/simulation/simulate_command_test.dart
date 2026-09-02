/// Bug #832 — the `zfa simulate` command (VISION §9 simulation worlds).
///
/// `zfa simulate` spins the golden contract world: `--scaffold` commits
/// certified fixtures under `specs/<feature>/tdd/fixtures/` (automated
/// fixture commitment) and hashes them into the cycle-log evidence;
/// `--scenario golden` replays the world and reports a machine-readable
/// verdict; `--verify-guard` self-certifies the network-isolation guard.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

Future<(int, String)> runZfa(List<String> args) async {
  final runner = CliRunner(exitOnCompletion: false);
  final output = await runner.runCapturing(args);
  return (exitCode, output);
}

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa-simulate-cmd');
  });

  tearDown(() async {
    await workspace.delete(recursive: true);
  });

  group('registration', () {
    test('zfa --help lists the simulate command', () async {
      final (code, output) = await runZfa(['--help']);
      expect(code, 0);
      expect(output, contains('simulate'));
    });

    test('zfa simulate --help documents the world options', () async {
      final (code, output) = await runZfa(['simulate', '--help']);
      expect(code, 0);
      expect(output, contains('scaffold'));
      expect(output, contains('scenario'));
      expect(output, contains('family'));
    });
  });

  group('--scaffold (automated fixture commitment)', () {
    test('materializes certified fixtures + manifest + cycle-log evidence',
        () async {
      final featureDir = '${workspace.path}/specs/058-zuraffa-auth-migration';
      final (code, output) = await runZfa([
        'simulate',
        '--scaffold',
        featureDir,
        '--family',
        'firebase-auth',
      ]);
      expect(code, 0, reason: output);

      final fixturesDir = '$featureDir/tdd/fixtures';
      expect(File('$fixturesDir/auth-world.json').existsSync(), isTrue);
      expect(File('$fixturesDir/manifest.json').existsSync(), isTrue);

      // Fixture hashes are recorded in the feature's cycle-log evidence.
      final cycleLog = File('$featureDir/tdd/cycle-log.md');
      expect(cycleLog.existsSync(), isTrue);
      final log = cycleLog.readAsStringSync();
      expect(log, contains('- behavior: 058-zuraffa-auth-migration-fixtures'));
      expect(log, contains('- kind: fixtures'));
      expect(log, contains(RegExp(r'- hash: [0-9a-f]{64}')));
      expect(
        log,
        contains(
          'zfa simulate --scaffold $featureDir --family firebase-auth',
        ),
      );
    });

    test('scaffolds every family by default and is re-runnable with --force',
        () async {
      final featureDir = '${workspace.path}/specs/011-usecase-hook-system';
      final (_, first) = await runZfa([
        'simulate',
        '--scaffold',
        featureDir,
      ]);
      expect(exitCode, 0, reason: first);

      final fixturesDir = '$featureDir/tdd/fixtures';
      expect(File('$fixturesDir/auth-world.json').existsSync(), isTrue);
      expect(File('$fixturesDir/vendure-golden.json').existsSync(), isTrue);
      expect(File('$fixturesDir/rest-world.json').existsSync(), isTrue);
      expect(File('$fixturesDir/admob-world.json').existsSync(), isTrue);
      expect(File('$fixturesDir/otel-world.json').existsSync(), isTrue);

      // Re-run without --force refuses (evidence must not be clobbered).
      final (codeNoForce, _) = await runZfa([
        'simulate',
        '--scaffold',
        featureDir,
      ]);
      expect(codeNoForce, isNot(0));

      // With --force the world re-certifies and the manifest stays valid.
      final (codeForce, _) = await runZfa([
        'simulate',
        '--scaffold',
        featureDir,
        '--force',
      ]);
      expect(codeForce, 0);
      final manifest =
          File('$fixturesDir/manifest.json').readAsStringSync();
      expect(manifest, contains('"digest"'));
    });
  });

  group('--scenario (deterministic golden replay)', () {
    test('replays the world GREEN and reports a machine verdict', () async {
      final featureDir = '${workspace.path}/specs/065-vendure-zuraffa-migration';
      final (scaffoldCode, scaffoldOut) = await runZfa([
        'simulate',
        '--scaffold',
        featureDir,
        '--family',
        'rest',
        '--family',
        'vendure',
      ]);
      expect(scaffoldCode, 0, reason: scaffoldOut);

      final (code, output) = await runZfa([
        'simulate',
        '--feature',
        featureDir,
        '--scenario',
        'golden',
      ]);
      expect(code, 0, reason: output);
      expect(output, contains('GREEN'));
      expect(output, contains('guard=active'));
    });

    test('fails honestly when the world is missing or tampered', () async {
      final (code, output) = await runZfa([
        'simulate',
        '--feature',
        '${workspace.path}/specs/never-scaffolded',
        '--scenario',
        'golden',
      ]);
      expect(code, isNot(0));
      expect(output, contains('RED'));
    });
  });

  group('--verify-guard (certify the isolation)', () {
    test('the guard self-test proves sockets are blocked', () async {
      final (code, output) = await runZfa([
        'simulate',
        '--verify-guard',
      ]);
      expect(code, 0, reason: output);
      expect(output, contains('guard ok'));
    });
  });
}
