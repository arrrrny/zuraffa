/// `zfa simulate` — the VISION §9 golden contract world command
/// (bug #832).
///
/// ```text
/// zfa simulate --scaffold specs/<feature> [--family <f>]... [--force]
/// zfa simulate --feature specs/<feature> [--scenario golden|<family>]
/// zfa simulate --fixtures <dir> [--scenario ...]
/// zfa simulate --verify-guard
/// ```
///
/// - `--scaffold` materializes the certified fixture worlds into
///   `<feature>/tdd/fixtures/`, writes the SHA-256 manifest, and hashes
///   the fixtures into the feature's cycle-log evidence (automated
///   fixture commitment).
/// - `--scenario` (default `golden`) loads the committed world, installs
///   the network-isolation guard, replays the golden contract, and
///   prints a machine-readable verdict (`GREEN` / `RED`) with the
///   process exit code as the machine contract.
/// - `--verify-guard` self-certifies the guard: a blocked socket probe
///   must fail with `NetworkIsolationViolation` without dialing.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../simulation/certified_worlds.dart';
import '../simulation/fixture_registry.dart';
import '../simulation/network_isolation_guard.dart';
import '../simulation/simulation_world.dart';

class SimulateCommand extends Command<void> {
  SimulateCommand() {
    argParser.addOption(
      'scaffold',
      valueHelp: 'feature-dir',
      help:
          'Materialize the certified fixture worlds into '
          '<feature-dir>/tdd/fixtures/ and hash them into the cycle-log '
          'evidence.',
    );
    argParser.addMultiOption(
      'family',
      allowed: simulationFamilies,
      help: 'Simulation family for --scaffold (repeatable; default: all).',
    );
    argParser.addOption(
      'feature',
      valueHelp: 'feature-dir',
      help: 'Load the committed world from <feature-dir>/tdd/fixtures/.',
    );
    argParser.addOption(
      'fixtures',
      valueHelp: 'dir',
      help: 'Load the committed world from an explicit fixtures directory '
          '(overrides --feature).',
    );
    argParser.addOption(
      'scenario',
      defaultsTo: 'golden',
      help: 'Golden replay to run: "golden" (every fixture) or one family '
          'name.',
    );
    argParser.addFlag(
      'verify-guard',
      negatable: false,
      help: 'Self-certify the network-isolation guard and exit.',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Re-scaffold over an existing certified world.',
    );
  }

  @override
  String get name => 'simulate';

  @override
  String get description =>
      'Spin a certified simulation world (VISION §9): scaffold fixture '
      'worlds per service family (FirebaseAuth, Vendure, Rest, AdMob, '
      'Otel), replay the golden contract offline, and certify network '
      'isolation.';

  @override
  String get invocation => 'zfa simulate [options]';

  @override
  Future<void> run() async {
    try {
      if (argResults!['verify-guard'] as bool) {
        exitCode = await _verifyGuard();
        return;
      }
      final scaffoldDir = argResults!['scaffold'] as String?;
      if (scaffoldDir != null) {
        exitCode = await _scaffold(scaffoldDir);
        return;
      }
      final fixturesDir = (argResults!['fixtures'] as String?) ??
          (argResults!['feature'] as String?);
      if (fixturesDir != null) {
        exitCode = await _replay(fixturesDir);
        return;
      }
      _usage();
      exitCode = 64;
    } on FixtureMismatch catch (e) {
      print('SIMULATE -> RED (${e.toString()})');
      exitCode = 1;
    } on FormatException catch (e) {
      print('SIMULATE -> RED (bad input: ${e.message})');
      exitCode = 64;
    }
  }

  void _usage() {
    print(invocation);
    print('');
    print(argParser.usage);
  }

  Future<int> _verifyGuard() async {
    NetworkIsolationGuard.install();
    try {
      try {
        await Socket.connect('simulation-guard-probe.invalid', 80);
        print(
          'SIMULATE guard FAILED — Socket.connect dialed a real socket',
        );
        return 1;
      } on NetworkIsolationViolation catch (e) {
        print('SIMULATE guard ok — socket blocked: ${e.toString()}');
        return 0;
      }
    } finally {
      NetworkIsolationGuard.uninstall();
    }
  }

  Future<int> _scaffold(String featureDir) async {
    final families = argResults!['family'] as List<String>;
    final fixturesDir =
        Directory(featureDir).path.endsWith('/tdd/fixtures')
            ? Directory(featureDir).path
            : '${Directory(featureDir).path}/tdd/fixtures';
    final manifest = await SimulationFixtures.scaffold(
      fixturesDir,
      families: families,
      force: argResults!['force'] as bool,
    );
    final selected =
        (manifest['families'] as List).cast<String>().toList();
    final commandLine = StringBuffer('zfa simulate --scaffold $featureDir');
    for (final family in selected) {
      commandLine.write(' --family $family');
    }
    if (argResults!['force'] as bool) commandLine.write(' --force');
    await FixtureRegistry(fixturesDir).appendCycleEvidence(
      featureDir: Directory(featureDir).path,
      families: selected,
      commandLine: commandLine.toString(),
    );
    print(
      'SIMULATED fixtures $fixturesDir families=[${selected.join(', ')}] '
      'digest=${manifest['digest']}',
    );
    return 0;
  }

  Future<int> _replay(String featureOrFixturesDir) async {
    final world = featureOrFixturesDir.endsWith('/tdd/fixtures')
        ? await SimulationWorld.boot(fixturesDir: featureOrFixturesDir)
        : await SimulationWorld.boot(featureDir: featureOrFixturesDir);
    try {
      final scenario = argResults!['scenario'] as String?;
      final results = await world.play(
        family: scenario == 'golden' || scenario == null ? null : scenario,
      );
      if (results.isEmpty) {
        print(
          'SIMULATE ${scenario ?? 'golden'} -> RED (no plays — no certified '
          'fixtures found under ${world.fixturesDir}) guard=active',
        );
        return 1;
      }
      final failures =
          results.where((r) => !r.passed).toList(growable: false);
      final verdict =
          failures.isEmpty ? 'GREEN' : 'RED';
      print(
        'SIMULATE ${scenario ?? 'golden'} -> $verdict '
        '(${results.length - failures.length}/${results.length} plays, '
        'guard=active, digest=${world.manifest['digest']})',
      );
      for (final result in failures) {
        print('  FAIL ${result.family}/${result.name}: '
            '${result.detail}');
      }
      return failures.isEmpty ? 0 : 1;
    } finally {
      world.dispose();
    }
  }
}
