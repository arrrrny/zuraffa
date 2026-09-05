/// `zfa simulate` — the VISION §9 simulation worlds command
/// (bug #832; spec 968 — scenario worlds).
///
/// ```text
/// zfa simulate --scaffold specs/<feature> [--family <f>]... [--force]
/// zfa simulate --feature specs/<feature> [--scenario golden|<family>]
/// zfa simulate --fixtures <dir> [--scenario ...]
/// zfa simulate --verify-guard
/// ```
///
/// Spec 968 subcommands — the scenario worlds (committed, diffable,
/// CI-verifiable):
///
/// ```text
/// zfa simulate init <scenario> --feature <feature> [--seed N] [--force]
/// zfa simulate run <scenario> --feature <feature> [--seed N] [--replay]
/// zfa simulate certify <scenario> --feature <feature>
/// zfa simulate verify-world <scenario> --feature <feature>
/// ```
///
/// - `init` scaffolds the world manifest from the feature's declared
///   dependency table (issue #960's output), certifies it
///   (framework-executed contract proof), and writes the committed
///   manifest + certification receipt.
/// - `run` executes the scenario's behavior program against the world
///   (virtual time, latency bands, failure storms), runs the
///   differential gate (#915 composes), and writes the proof-carrying
///   run receipt naming the world hash (#807 composes). A mutated world
///   invalidates the previous green before anything executes.
/// - `certify` re-proves the world's contracts LIVE (registry adds are
///   re-proofs — never copies of old receipts).
/// - `verify-world` is the CI gate: manifest, certification receipt,
///   and run receipt must agree on the world hash.
///
/// Dispatch note (bug #856 / spec #975's grammar lesson): the legacy
/// flag surface (`--scaffold`, `--feature`, `--fixtures`, `--scenario`,
/// `--verify-guard`, `--family`, `--force`) MUST keep working, so the
/// subcommands are registered with `argParser.addCommand` only — NOT
/// `addSubcommand` (registering them as real subcommands would make
/// package:args reject every flag-mode invocation with "Missing
/// subcommand" before `run()` executes). The subcommand tokens parse
/// into `argResults.command`, and `run()` dispatches manually below.
library;

import 'dart:io';

import 'package:args/args.dart' show ArgResults;
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../plugins/mock/services/dependency_declaration_reader.dart';
import '../simulation/certified_worlds.dart';
import '../simulation/fixture_registry.dart';
import '../simulation/network_isolation_guard.dart';
import '../simulation/simulation_world.dart';
import '../simulation/worlds/world_certification.dart';
import '../simulation/worlds/world_differential_gate.dart';
import '../simulation/worlds/world_manifest.dart';
import '../simulation/worlds/world_run_receipt.dart';
import '../simulation/worlds/world_runtime.dart';
import '../simulation/worlds/world_store.dart';

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
      help:
          'Load the committed world from an explicit fixtures directory '
          '(overrides --feature).',
    );
    argParser.addOption(
      'scenario',
      defaultsTo: 'golden',
      help:
          'Golden replay to run: "golden" (every fixture) or one family '
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
    // Parser-only registration (see the library docs): the spec-968
    // subcommands parse into argResults.command and run() dispatches
    // manually, so the legacy flag surface above stays reachable.
    _init = SimulateInitCommand();
    _run = SimulateRunCommand();
    _certify = SimulateCertifyCommand();
    _verifyWorld = SimulateVerifyWorldCommand();
    argParser.addCommand(_init.name, _init.argParser);
    argParser.addCommand(_run.name, _run.argParser);
    argParser.addCommand(_certify.name, _certify.argParser);
    argParser.addCommand(_verifyWorld.name, _verifyWorld.argParser);
  }

  late final SimulateInitCommand _init;
  late final SimulateRunCommand _run;
  late final SimulateCertifyCommand _certify;
  late final SimulateVerifyWorldCommand _verifyWorld;

  @override
  String get name => 'simulate';

  @override
  String get description =>
      'Spin a certified simulation world (VISION §9): scaffold fixture '
      'worlds per service family (FirebaseAuth, Vendure, Rest, AdMob, '
      'Otel), replay the golden contract offline, and certify network '
      'isolation. Spec 968: `simulate init/run <scenario>` — committed '
      'scenario worlds with virtual time, latency, failure storms.';

  @override
  String get invocation =>
      'zfa simulate [options] | zfa simulate <init|run|certify|verify-world> '
      '<scenario> [options]';

  @override
  Future<void> run() async {
    // Spec 968 manual dispatch: a subcommand token parsed into
    // argResults.command routes to the scenario-worlds machinery; the
    // parent's own --feature may carry the feature when it precedes the
    // subcommand token.
    final nested = argResults!.command;
    if (nested != null) {
      final parentFeature = argResults!['feature'] as String?;
      switch (nested.name) {
        case 'init':
          await _init.runWith(nested, parentFeature: parentFeature);
          return;
        case 'run':
          await _run.runWith(nested, parentFeature: parentFeature);
          return;
        case 'certify':
          await _certify.runWith(nested, parentFeature: parentFeature);
          return;
        case 'verify-world':
          await _verifyWorld.runWith(nested, parentFeature: parentFeature);
          return;
        default:
          break;
      }
    }
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
      final fixturesDir =
          (argResults!['fixtures'] as String?) ??
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
        print('SIMULATE guard FAILED — Socket.connect dialed a real socket');
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
    final fixturesDir = Directory(featureDir).path.endsWith('/tdd/fixtures')
        ? Directory(featureDir).path
        : '${Directory(featureDir).path}/tdd/fixtures';
    final manifest = await SimulationFixtures.scaffold(
      fixturesDir,
      families: families,
      force: argResults!['force'] as bool,
    );
    final selected = (manifest['families'] as List).cast<String>().toList();
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
      final failures = results.where((r) => !r.passed).toList(growable: false);
      final verdict = failures.isEmpty ? 'GREEN' : 'RED';
      print(
        'SIMULATE ${scenario ?? 'golden'} -> $verdict '
        '(${results.length - failures.length}/${results.length} plays, '
        'guard=active, digest=${world.manifest['digest']})',
      );
      for (final result in failures) {
        print(
          '  FAIL ${result.family}/${result.name}: '
          '${result.detail}',
        );
      }
      return failures.isEmpty ? 0 : 1;
    } finally {
      world.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// Shared subcommand plumbing
// ---------------------------------------------------------------------------

/// Resolves `--feature`/`--project` into the feature directory + name.
/// `--feature` accepts either a feature name (`968-simulation-worlds`)
/// or a path (`specs/968-simulation-worlds`).
({String featureDir, String featureName, String projectRoot}) _resolveFeature(
  String? featureFlag,
  String? projectFlag,
) {
  final projectRoot = projectFlag != null && projectFlag.isNotEmpty
      ? p.absolute(projectFlag)
      : Directory.current.path;
  var name = featureFlag ?? '';
  var dir = name;
  if (name.isEmpty) {
    throw const _UsageError(
      'no --feature given --> fix: pass --feature <name-or-dir> (the '
      'feature under specs/ whose declared dependency table the world '
      'composes).',
    );
  }
  if (!name.contains('/')) {
    dir = p.join(projectRoot, 'specs', name);
  } else if (!p.isAbsolute(dir)) {
    dir = p.join(projectRoot, dir);
  }
  name = p.basename(p.normalize(dir));
  return (featureDir: dir, featureName: name, projectRoot: projectRoot);
}

final class _UsageError implements Exception {
  const _UsageError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Loads the world manifest for [scenario] (the subcommands' shared
/// gate): refuses honestly when absent or structurally invalid.
WorldManifest _loadManifest({
  required String featureDir,
  required String scenario,
}) {
  final path = worldManifestPath(featureDir, scenario);
  final file = File(path);
  if (!file.existsSync()) {
    throw _UsageError(
      'no world manifest at $path '
      '--> fix: run `zfa simulate init $scenario --feature '
      '<feature>` first.',
    );
  }
  try {
    return WorldManifest.parse(file.readAsBytesSync());
  } on WorldManifestError catch (e) {
    throw _UsageError(e.message);
  }
}

/// Prints the subcommand usage line (the manual-dispatch path's help).
void _printSubUsage(String invocationLine, String usage) {
  print(invocationLine);
  print('');
  print(usage);
}

// ---------------------------------------------------------------------------
// simulate init
// ---------------------------------------------------------------------------

class SimulateInitCommand extends Command<void> {
  SimulateInitCommand() {
    argParser.addOption(
      'feature',
      help:
          'Feature name or directory under specs/ (whose declared '
          'dependency table the world composes).',
    );
    argParser.addOption(
      'project',
      help:
          'Project root containing specs/ (defaults to the current '
          'working directory).',
    );
    argParser.addOption(
      'seed',
      help: 'The world seed (default: 968 — deterministic).',
      defaultsTo: '968',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Re-scaffold over an existing world manifest.',
    );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Scaffold a committed scenario world from the feature\'s declared '
      'dependency table (spec 968; consumes issue #960\'s output), '
      'certify it, and write the manifest + certification receipt.';

  @override
  Future<void> run() async {
    // Only reachable through direct programmatic invocation; the CLI
    // path routes through [runWith] (manual dispatch, see
    // [SimulateCommand.run]).
    await runWith(argResults!);
  }

  /// The manual-dispatch entry: [args] are this subcommand's parsed
  /// results; [parentFeature] carries the parent's `--feature` when it
  /// preceded the subcommand token.
  Future<void> runWith(ArgResults args, {String? parentFeature}) async {
    if (args.flag('help')) {
      _printSubUsage(
        'zfa simulate init <scenario> --feature <feature> [--seed N] '
        '[--force]',
        argParser.usage,
      );
      return;
    }
    final rest = args.rest;
    if (rest.isEmpty) {
      print(
        '❌ Usage: zfa simulate init <scenario> --feature <feature> '
        '[--seed N] [--force]',
      );
      exitCode = 64;
      return;
    }
    final scenario = rest.first;
    try {
      final resolved = _resolveFeature(
        (args['feature'] as String?) ?? parentFeature,
        args['project'] as String?,
      );
      final seed = int.tryParse(args['seed'] as String? ?? '968') ?? 968;

      // 1. Consume the declared dependency table (#960's output).
      final rows = await DependencyDeclarationReader.load(
        projectRoot: resolved.projectRoot,
        feature: resolved.featureName,
      );
      if (rows.isEmpty) {
        print(
          'SIMULATE init -> RED (feature "${resolved.featureName}" declares '
          'no external dependencies — a world without touchpoints is a '
          'silent pass)',
        );
        print(
          '   --> fix: declare the External Dependencies & Contracts table '
          'in the spec, then re-run `zfa tdd plan '
          '${resolved.featureName}`.',
        );
        exitCode = 1;
        return;
      }

      // 2. Scaffold the world (deterministic).
      final manifest = scaffoldWorld(
        scenario: scenario,
        feature: resolved.featureName,
        rows: [
          for (final row in rows)
            DeclaredTouchpointRow(
              name: row.name,
              type: row.type,
              contract: row.contract,
              priority: row.mockPriority ?? 'P2',
            ),
        ],
        seed: seed,
      );

      final manifestPath = worldManifestPath(resolved.featureDir, scenario);
      if (File(manifestPath).existsSync() && !args.flag('force')) {
        print('SIMULATE init -> RED (world already exists at $manifestPath)');
        print('   --> fix: re-scaffold with --force, or edit the manifest.');
        exitCode = 1;
        return;
      }

      // 3. Certify the world (framework-executed contract proof).
      final certification = await const WorldCertifier().certify(manifest);
      if (!certification.certified) {
        print(
          'SIMULATE init -> RED (world certification failed for '
          '"$scenario")',
        );
        for (final proof in certification.proofs.where((x) => !x.satisfied)) {
          print('   ${proof.touchpoint}.${proof.method}: ${proof.evidence}');
        }
        print('   no receipt that lies — the world was not committed.');
        exitCode = 1;
        return;
      }

      // 4. Commit the manifest + certification receipt.
      final worldsDir = Directory(worldsDirOf(resolved.featureDir));
      await worldsDir.create(recursive: true);
      await File(manifestPath).writeAsString(manifest.toFileContents());
      await File(
        worldCertPath(resolved.featureDir, scenario),
      ).writeAsString(certification.toFileContents());

      // 5. Cycle-log evidence (committed, hash-chained).
      await appendWorldCycleEvidence(
        featureDir: resolved.featureDir,
        behaviorId: '${resolved.featureName}-world-$scenario',
        kind: 'world-cert',
        commandLine:
            'zfa simulate init $scenario --feature '
            '${resolved.featureName} --seed $seed',
        hash: manifest.worldHash,
        exitCode: 0,
        criterion:
            'world "$scenario" committed under tdd/worlds/ with '
            '${manifest.touchpoints.length} certified touchpoints; every '
            'declared contract method proven by framework invocation',
        extraLines: {
          'scenario': scenario,
          'touchpoints': [
            for (final t in manifest.touchpoints) t.name,
          ].join(','),
          'certified-methods': '${certification.proofs.length}',
        },
      );

      print(
        'SIMULATE init -> GREEN world=$manifestPath '
        'scenario=$scenario feature=${resolved.featureName} '
        'touchpoints=${manifest.touchpoints.length} '
        'certified=${certification.proofs.length} '
        'world-hash=${manifest.worldHash.substring(0, 12)}',
      );
      print(
        '   storms: ${manifest.storms.isEmpty ? '(none declared)' : manifest.storms.map((s) => s.name).join(', ')}',
      );
      print(
        '   refine the corpus fixtures, latency bands, and storm windows '
        'in the manifest, then re-certify: '
        '`zfa simulate certify $scenario --feature '
        '${resolved.featureName}`',
      );
      exitCode = 0;
    } on DependencyDeclarationError catch (e) {
      print('SIMULATE init -> RED (${e.message})');
      print('   ${e.fix}');
      exitCode = 1;
    } on WorldManifestError catch (e) {
      print('SIMULATE init -> RED (${e.message})');
      exitCode = 1;
    } on _UsageError catch (e) {
      print('❌ ${e.message}');
      exitCode = 64;
    }
  }
}

// ---------------------------------------------------------------------------
// simulate run
// ---------------------------------------------------------------------------

class SimulateRunCommand extends Command<void> {
  SimulateRunCommand() {
    argParser.addOption(
      'feature',
      help: 'Feature name or directory under specs/.',
    );
    argParser.addOption(
      'project',
      help: 'Project root containing specs/ (defaults to CWD).',
    );
    argParser.addOption(
      'seed',
      help:
          'Override the world seed (deterministic replay uses the '
          'recorded seed by default).',
    );
    argParser.addFlag(
      'replay',
      negatable: false,
      help:
          'Re-execute deterministically and prove the run digest '
          'matches the recorded receipt (#806 composes).',
    );
    argParser.addFlag(
      'no-differential',
      negatable: false,
      help: 'Skip the differential gate (debug only; CI runs it).',
    );
  }

  @override
  String get name => 'run';

  @override
  String get description =>
      'Execute the scenario\'s behavior program against the world '
      '(virtual time, latency bands, failure storms), run the '
      'differential gate, and write the proof-carrying run receipt '
      'naming the world hash.';

  @override
  Future<void> run() async {
    await runWith(argResults!);
  }

  Future<void> runWith(ArgResults args, {String? parentFeature}) async {
    if (args.flag('help')) {
      _printSubUsage(
        'zfa simulate run <scenario> --feature <feature> [--seed N] '
        '[--replay]',
        argParser.usage,
      );
      return;
    }
    final rest = args.rest;
    if (rest.isEmpty) {
      print(
        '❌ Usage: zfa simulate run <scenario> --feature <feature> '
        '[--seed N] [--replay]',
      );
      exitCode = 64;
      return;
    }
    final scenario = rest.first;
    try {
      final resolved = _resolveFeature(
        (args['feature'] as String?) ?? parentFeature,
        args['project'] as String?,
      );
      final manifest = _loadManifest(
        featureDir: resolved.featureDir,
        scenario: scenario,
      );
      final worldHash = manifest.worldHash;

      // 1. Receipt invalidation (acceptance criterion 2): a previous
      //    GREEN receipt naming a DIFFERENT world hash is invalidated by
      //    the mutation — rewrite it as the invalidation record (no
      //    stale green survives), report it, and continue: whether the
      //    mutated world may run at all is the certification gate's
      //    verdict (below), not the receipt's.
      final receiptStore = WorldRunReceiptStore(
        projectRoot: resolved.projectRoot,
      );
      final prior = receiptStore.load(scenario);
      if (prior != null && prior.passed && prior.worldHash != worldHash) {
        await receiptStore.save(
          WorldRunReceipt(
            scenario: scenario,
            feature: manifest.feature,
            worldHash: worldHash,
            seed: prior.seed,
            verdict: 'RED',
            passed: false,
            worldValid: false,
            plays: 0,
            runDigest: '',
            virtualElapsedMs: 0,
            at: DateTime.now().toUtc().toIso8601String(),
            path: prior.path,
            invalidatedBy: 'world-mutation',
          ),
        );
        print(
          'SIMULATE run $scenario (world mutated since the green receipt: '
          '${prior.worldHash.substring(0, 12)} -> '
          '${worldHash.substring(0, 12)}; the previous receipt is '
          'INVALIDATED)',
        );
      }

      // 2. Certification gate: the world's certification receipt must
      //    match the CURRENT world hash (a mutated world never runs on
      //    stale proof — the re-run exits red until re-certified).
      final cert = loadWorldCertification(
        worldsDirOf(resolved.featureDir),
        scenario,
      );
      if (cert == null || !cert.certified || cert.worldHash != worldHash) {
        print(
          'SIMULATE run $scenario -> RED (world certification is missing, '
          'red, or stale for world hash ${worldHash.substring(0, 12)})',
        );
        print(
          '   --> fix: re-certify the world: `zfa simulate certify '
          '$scenario --feature ${resolved.featureName}`.',
        );
        exitCode = 1;
        return;
      }

      // 3. Replay seed: the recorded seed (deterministic replay) unless
      //    explicitly overridden.
      final seed =
          int.tryParse(args['seed'] as String? ?? '') ??
          (args.flag('replay') && prior != null ? prior.seed : manifest.seed);

      // 4. Execute the scenario against the world (virtual time,
      //    latency, storms).
      final runtime = WorldRuntime(
        manifest,
        binding: WorldBinding.world,
        seedOverride: seed,
      );
      final results = await runtime.executeScenario();
      final failures = results.where((r) => !r.passed).toList(growable: false);
      final verdict = failures.isEmpty ? 'GREEN' : 'RED';
      final runDigest = runtime.runDigest;

      // 5. Differential gate (#915 composes): same behaviors against the
      //    mock world AND the real-adapter harness.
      var differential = 'skipped';
      var diffOk = true;
      if (!args.flag('no-differential')) {
        final gate = await const WorldDifferentialGate().run(
          manifest,
          resolved.featureDir,
        );
        differential = gate.verdict.name;
        diffOk = gate.verdict != WorldDiffVerdict.drift;
        if (!diffOk) {
          for (final row in gate.rows.where(
            (r) => r.clazz == DiffClass.drift,
          )) {
            print('   DIFF drift: ${row.behavior}: ${row.detail}');
          }
          for (final storm in gate.unrehearsedStorms) {
            print('   DIFF unrehearsed storm: $storm');
          }
        }
      }

      // 6. The proof-carrying run receipt (names the world hash).
      final now = DateTime.now().toUtc().toIso8601String();
      await receiptStore.save(
        WorldRunReceipt(
          scenario: scenario,
          feature: manifest.feature,
          worldHash: worldHash,
          seed: seed,
          verdict: verdict == 'GREEN' && diffOk ? 'GREEN' : 'RED',
          passed: verdict == 'GREEN' && diffOk,
          worldValid: true,
          plays: runtime.plays.length,
          runDigest: runDigest,
          virtualElapsedMs: runtime.virtualElapsedMs,
          at: now,
          path: '',
        ),
      );

      // 7. Committed cycle-log evidence (hash-chained).
      await appendWorldCycleEvidence(
        featureDir: resolved.featureDir,
        behaviorId: '${resolved.featureName}-world-run-$scenario',
        kind: 'world-run',
        commandLine:
            'zfa simulate run $scenario --feature ${resolved.featureName}'
            '${seed != manifest.seed ? ' --seed $seed' : ''}',
        hash: runDigest,
        exitCode: verdict == 'GREEN' && diffOk ? 0 : 1,
        criterion:
            'scenario "$scenario" executed against world '
            '${worldHash.substring(0, 12)} under virtual time: '
            '${runtime.plays.length} plays, '
            '${runtime.virtualElapsedMs} virtual ms, verdict $verdict, '
            'differential $differential',
        extraLines: {
          'scenario': scenario,
          'world-hash': worldHash,
          'seed': '$seed',
          'plays': '${runtime.plays.length}',
          'run-digest': runDigest,
          'virtual-ms': '${runtime.virtualElapsedMs}',
          'differential': differential,
        },
      );

      // 8. Replay proof (#806 composes): the re-executed digest must
      //    match the recorded receipt.
      if (args.flag('replay') && prior != null) {
        final matches =
            prior.runDigest == runDigest && prior.worldHash == worldHash;
        print(
          '   replay: ${matches ? 'deterministic (digest match)' : 'DIGEST MISMATCH — the world run is not replayable'}'
          ' (${runDigest.substring(0, 12)} vs '
          '${prior.runDigest.isEmpty ? 'none' : prior.runDigest.substring(0, 12)})',
        );
        if (!matches) {
          print('SIMULATE run $scenario -> RED');
          exitCode = 1;
          return;
        }
      }

      print(
        'simulate-run: scenario=$scenario '
        'world-hash=${worldHash.substring(0, 12)} verdict=$verdict '
        'plays=${runtime.plays.length} drift=$differential '
        'virtual-ms=${runtime.virtualElapsedMs} seed=$seed',
      );
      for (final failure in failures) {
        print(
          '  FAIL ${failure.behavior}: ${failure.detail} '
          '(ledger: ${failure.failureLedger.join(', ')})',
        );
      }
      exitCode = verdict == 'GREEN' && diffOk ? 0 : 1;
    } on WorldManifestError catch (e) {
      print('SIMULATE run -> RED (${e.message})');
      exitCode = 1;
    } on WorldProgramError catch (e) {
      print('SIMULATE run -> RED (${e.message})');
      exitCode = 1;
    } on _UsageError catch (e) {
      print('❌ ${e.message}');
      exitCode = 64;
    }
  }
}

// ---------------------------------------------------------------------------
// simulate certify
// ---------------------------------------------------------------------------

class SimulateCertifyCommand extends Command<void> {
  SimulateCertifyCommand() {
    argParser.addOption('feature', help: 'Feature name or directory.');
    argParser.addOption('project', help: 'Project root (defaults to CWD).');
  }

  @override
  String get name => 'certify';

  @override
  String get description =>
      'Re-prove the world\'s contracts LIVE (registry adds are re-proofs, '
      'never copies of old receipts) and refresh the certification '
      'receipt.';

  @override
  Future<void> run() async {
    await runWith(argResults!);
  }

  Future<void> runWith(ArgResults args, {String? parentFeature}) async {
    if (args.flag('help')) {
      _printSubUsage(
        'zfa simulate certify <scenario> --feature <feature>',
        argParser.usage,
      );
      return;
    }
    final rest = args.rest;
    if (rest.isEmpty) {
      print('❌ Usage: zfa simulate certify <scenario> --feature <feature>');
      exitCode = 64;
      return;
    }
    final scenario = rest.first;
    try {
      final resolved = _resolveFeature(
        (args['feature'] as String?) ?? parentFeature,
        args['project'] as String?,
      );
      final manifest = _loadManifest(
        featureDir: resolved.featureDir,
        scenario: scenario,
      );
      final certification = await const WorldCertifier().certify(manifest);
      await File(
        worldCertPath(resolved.featureDir, scenario),
      ).writeAsString(certification.toFileContents());
      await appendWorldCycleEvidence(
        featureDir: resolved.featureDir,
        behaviorId: '${resolved.featureName}-world-$scenario',
        kind: 'world-cert',
        commandLine:
            'zfa simulate certify $scenario --feature '
            '${resolved.featureName}',
        hash: manifest.worldHash,
        exitCode: certification.certified ? 0 : 1,
        criterion:
            'world "$scenario" re-certified live: '
            '${certification.proofs.where((x) => x.satisfied).length}/'
            '${certification.proofs.length} declared methods satisfied',
        extraLines: {
          'scenario': scenario,
          'certified-methods': '${certification.proofs.length}',
        },
      );
      print(
        'simulate-certify: scenario=$scenario '
        'world-hash=${manifest.worldHash.substring(0, 12)} '
        'certified=${certification.certified} '
        'methods=${certification.proofs.where((x) => x.satisfied).length}/'
        '${certification.proofs.length}',
      );
      for (final proof in certification.proofs.where((x) => !x.satisfied)) {
        print('   RED ${proof.touchpoint}.${proof.method}: ${proof.evidence}');
      }
      exitCode = certification.certified ? 0 : 1;
    } on WorldManifestError catch (e) {
      print('SIMULATE certify -> RED (${e.message})');
      exitCode = 1;
    } on _UsageError catch (e) {
      print('❌ ${e.message}');
      exitCode = 64;
    }
  }
}

// ---------------------------------------------------------------------------
// simulate verify-world (the CI gate)
// ---------------------------------------------------------------------------

class SimulateVerifyWorldCommand extends Command<void> {
  SimulateVerifyWorldCommand() {
    argParser.addOption('feature', help: 'Feature name or directory.');
    argParser.addOption('project', help: 'Project root (defaults to CWD).');
  }

  @override
  String get name => 'verify-world';

  @override
  String get description =>
      'CI gate: the world manifest parses, the recomputed world hash '
      'matches the committed certification receipt (and the local run '
      'receipt, when present), and the declared contracts are provable. '
      'Any drift exits 1 naming the delta.';

  @override
  Future<void> run() async {
    await runWith(argResults!);
  }

  Future<void> runWith(ArgResults args, {String? parentFeature}) async {
    if (args.flag('help')) {
      _printSubUsage(
        'zfa simulate verify-world <scenario> --feature <feature>',
        argParser.usage,
      );
      return;
    }
    final rest = args.rest;
    if (rest.isEmpty) {
      print(
        '❌ Usage: zfa simulate verify-world <scenario> --feature <feature>',
      );
      exitCode = 64;
      return;
    }
    final scenario = rest.first;
    try {
      final resolved = _resolveFeature(
        (args['feature'] as String?) ?? parentFeature,
        args['project'] as String?,
      );
      final manifest = _loadManifest(
        featureDir: resolved.featureDir,
        scenario: scenario,
      );
      final worldHash = manifest.worldHash;
      var ok = true;

      // 1. Certification receipt agreement.
      final cert = loadWorldCertification(
        worldsDirOf(resolved.featureDir),
        scenario,
      );
      if (cert == null || !cert.certified) {
        print(
          'verify-world $scenario -> RED (no green certification receipt '
          'at ${worldCertPath(resolved.featureDir, scenario)})',
        );
        ok = false;
      } else if (cert.worldHash != worldHash) {
        print(
          'verify-world $scenario -> RED (world mutated since '
          'certification: cert=${cert.worldHash.substring(0, 12)} '
          'manifest=$worldHash)',
        );
        ok = false;
      }

      // 2. Local run receipt agreement (when present — .zfa/receipts is
      //    gitignored, CI re-runs deterministically instead).
      final runReceipt = WorldRunReceiptStore(
        projectRoot: resolved.projectRoot,
      ).load(scenario);
      if (runReceipt != null && runReceipt.worldHash != worldHash) {
        print(
          'verify-world $scenario -> RED (run receipt names a different '
          'world: receipt=${runReceipt.worldHash.substring(0, 12)} '
          'manifest=${worldHash.substring(0, 12)}; '
          'invalidated-by=${runReceipt.invalidatedBy ?? "drift"})',
        );
        ok = false;
      }

      // 3. The declared contracts are still provable (live re-proof).
      final certification = await const WorldCertifier().certify(manifest);
      if (!certification.certified) {
        print('verify-world $scenario -> RED (live contract re-proof failed)');
        for (final proof in certification.proofs.where((x) => !x.satisfied)) {
          print('   ${proof.touchpoint}.${proof.method}: ${proof.evidence}');
        }
        ok = false;
      }

      if (ok) {
        print(
          'verify-world: scenario=$scenario '
          'world-hash=${worldHash.substring(0, 12)} '
          'certified=${certification.proofs.length} methods '
          'run-receipt=${runReceipt == null ? 'absent (CI re-runs)' : (runReceipt.passed ? 'green' : 'red')} '
          'verdict=GREEN',
        );
      }
      exitCode = ok ? 0 : 1;
    } on WorldManifestError catch (e) {
      print('verify-world -> RED (${e.message})');
      exitCode = 1;
    } on _UsageError catch (e) {
      print('❌ ${e.message}');
      exitCode = 64;
    }
  }
}
