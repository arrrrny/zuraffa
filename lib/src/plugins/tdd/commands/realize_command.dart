/// `zfa tdd realize <entity|behavior> --adapter <real>` — the mock→real
/// swap with contract + differential gates and nuance receipts (spec 913,
/// parent #908 Mock-First Realization).
///
/// The honest 90/10 becomes enforced physics: mocks are 100% generatable,
/// real impls are not, so this command is the ONLY sanctioned crossing
/// from the MOCKED era to the REAL era:
///
///   1. rebinds DI from the mock datasource to the real adapter behind
///      the SAME generated interface (never through it),
///   2. runs the MOCK-era suite unchanged against the real binding
///      (contract gate — any red names which side broke the contract),
///   3. runs real vs mock over the same committed fixtures
///      (differential gate — drift report, threshold from `.zfa.json`),
///   4. records hand-written deltas as nuance receipts in the feature's
///      provenance ledger (legal gated; ungated blocked),
///   5. transitions the state MOCKED → REAL with era-tagged cycle-log
///      evidence.
///
/// Summary (house convention): the LAST stdout line is machine-readable:
///
///     realize: entity=<E> adapter=<A> feature=<F> contract=<verdict>
///              era=MOCKED->REAL result=<realized|blocked|runner-error>
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../../../core/project/receipt_store.dart';
import '../services/artifact_registry.dart';
import '../services/entity_lookup.dart' show toSnakeCase;
import '../services/contract_gate.dart';
import '../services/di_rebind.dart';
import '../services/differential_gate.dart';
import '../services/era_tagged_log.dart';
import '../services/nuance_receipts.dart';
import '../services/realize_state.dart';
import '../tdd_plugin.dart';

/// The contract-gate suite spawner (injectable for fast-tier tests — the
/// CorpusDifferentialCommand spawner pattern). Runs the mock-era suite
/// against one binding and reports exit code + combined output.
typedef RealizeSuiteRunner =
    Future<({int exitCode, String output})> Function(
      List<String> testPaths,
      String workingDirectory,
    );

/// Outcome labels for the machine-readable summary line.
enum RealizeOutcome {
  realized('realized'),
  alreadyReal('already-real'),
  blocked('blocked'),
  runnerError('runner-error');

  const RealizeOutcome(this.label);
  final String label;
}

class RealizeCommand extends Command<void> {
  RealizeCommand(
    this.plugin, {
    RealizeSuiteRunner? suiteRunner,
    RealizeFixtureDriver? fixtureDriver,
  }) : _suiteRunnerOverride = suiteRunner,
       _fixtureDriverOverride = fixtureDriver {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'adapter',
      help:
          'The real adapter class to bind (must already exist in lib/ — '
          'realize never generates real implementations). Required.',
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 047-tdd-make). Restricts state + registry '
          'resolution to specs/<feature>. When omitted, feature registries '
          'are scanned for the target.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, lib/, test/. Defaults to the '
          'current working directory.',
    );
    argParser.addMultiOption(
      'hand-delta',
      valueHelp: 'file',
      help:
          'A hand-written delta to gate with a nuance receipt (repeatable; '
          'project-relative POSIX path). Required together with --reason '
          'when realize detects an unrecorded hand-delta.',
    );
    argParser.addOption(
      'reason',
      help:
          'The reason the hand-delta(s) are legal (required with '
          '--hand-delta; recorded verbatim in the provenance ledger).',
    );
  }

  final TddPlugin plugin;

  final RealizeSuiteRunner? _suiteRunnerOverride;

  final RealizeFixtureDriver? _fixtureDriverOverride;

  @override
  String get name => 'realize';

  @override
  String get description =>
      'Swap the mock datasource for a real adapter behind the same '
      'generated interface, gated by the contract suite and the '
      'real-vs-mock differential (spec 913).';

  @override
  String get invocation =>
      'zfa tdd realize <entity|behavior> --adapter <real> [options]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    final target = rest.isNotEmpty ? rest.first.trim() : '';
    final adapter = (argResults?['adapter'] as String?)?.trim() ?? '';
    final featureFlag = (argResults?['feature'] as String?)?.trim() ?? '';
    final projectFlag = (argResults?['project'] as String?)?.trim() ?? '';

    // ---------------------------------------------------------------
    // Argument validation (misfire-stop, never a guess).
    // ---------------------------------------------------------------
    if (target.isEmpty) {
      _fail(
        'zfa tdd realize: an entity or behavior id is required. Usage: '
        '$invocation',
        entity: '-',
        adapter: '-',
        feature: featureFlag,
      );
      return;
    }
    if (adapter.isEmpty) {
      _fail(
        'zfa tdd realize: --adapter <RealAdapter> is required — the swap '
        'binds a named real adapter class that already exists in lib/ '
        '(realize never generates real implementations).',
        entity: target,
        adapter: '-',
        feature: featureFlag,
      );
      return;
    }

    final cwd = projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    _resolvedRoot = cwd;

    final handDeltaFlags =
        (argResults?['hand-delta'] as List<String>? ?? const <String>[])
            .map((f) => f.trim())
            .where((f) => f.isNotEmpty)
            .map(_normalizeRel)
            .toList();
    final handDeltaReason = (argResults?['reason'] as String?)?.trim() ?? '';

    // ---------------------------------------------------------------
    // Resolve the feature + entity behind the target.
    // ---------------------------------------------------------------
    _Target? resolved;
    try {
      resolved = await _resolveTarget(cwd, target, featureFlag);
    } on _ResolveError catch (e) {
      _fail(
        'zfa tdd realize: ${e.message}',
        entity: target,
        adapter: adapter,
        feature: featureFlag,
      );
      return;
    }
    if (resolved == null) {
      _fail(
        'zfa tdd realize: unknown target "$target". No matching behavior '
        'record in any specs/<feature>/tdd/artifacts.json. Pass '
        '--feature <name> to pin the feature home for an entity target.',
        entity: target,
        adapter: adapter,
        feature: featureFlag,
      );
      return;
    }
    final feature = resolved.feature;
    final entity = resolved.entity;
    final featureDir = p.join(cwd, 'specs', feature);
    print('zfa tdd realize: entity $entity -> adapter $adapter');
    print('   feature: $feature');

    // ---------------------------------------------------------------
    // Era state: MOCKED is the default (mock-first realization).
    // ---------------------------------------------------------------
    final stateStore = RealizeStateStore(featureDir);
    final state = await stateStore.loadOrDefault(
      feature: feature,
      entity: entity,
    );
    print('   era: ${state.era.name.toUpperCase()}');
    if (state.era == RealizeEra.real && state.adapter == adapter) {
      print(
        '   already realized: $entity is bound to $adapter — nothing to '
        'swap.',
      );
      _printSummary(
        entity: entity,
        adapter: adapter,
        feature: feature,
        contract: 'green',
        era: 'REAL',
        outcome: RealizeOutcome.alreadyReal,
      );
      exitCode = 0;
      return;
    }

    // ---------------------------------------------------------------
    // The nuance-receipts gate (#807 proof-carrying): hand-deltas are
    // legal, ungated hand-deltas are not. The realization surface (the
    // mock binding files + the mock implementation itself) is compared
    // against its last provenance baseline; every drift must be
    // recorded with --hand-delta <file> --reason <text> or reverted.
    // ---------------------------------------------------------------
    final rebinder = DiRebinder(projectRoot: cwd);
    final receipts = NuanceReceipts(featureDir: featureDir, projectRoot: cwd);
    final surface = <String>[
      for (final site in await rebinder.scan(entity: entity)) site.file,
      ...await rebinder.mockImplementationFiles(entity: entity),
    ].map((f) => _normalizeRel(p.relative(f, from: cwd))).toList();
    final unrecorded = await receipts.detect(files: surface);
    final ungated = unrecorded
        .where((d) => !handDeltaFlags.contains(d.file))
        .toList();
    if (ungated.isNotEmpty) {
      print(
        '   nuance gate BLOCKED: ${ungated.length} unrecorded '
        'hand-delta(s) on the realization surface — hand-deltas are '
        'legal, ungated hand-deltas are not:',
      );
      for (final delta in ungated) {
        print('   hand-delta: ${delta.file} (${delta.detail})');
      }
      print(
        '   Record each one with --hand-delta <file> --reason "<why>" or '
        'revert it, then re-run.',
      );
      _printSummary(
        entity: entity,
        adapter: adapter,
        feature: feature,
        contract: '-',
        handDeltas: ungated.length,
        era: state.era.name.toUpperCase(),
        outcome: RealizeOutcome.blocked,
      );
      exitCode = 1;
      return;
    }
    final gatedDeltas = unrecorded
        .where((d) => handDeltaFlags.contains(d.file))
        .toList();
    if (handDeltaFlags.isNotEmpty && handDeltaReason.isEmpty) {
      print(
        '   nuance gate BLOCKED: --hand-delta requires a non-empty '
        '--reason — reason metadata is enforced, not optional.',
      );
      _printSummary(
        entity: entity,
        adapter: adapter,
        feature: feature,
        contract: '-',
        handDeltas: gatedDeltas.length,
        era: state.era.name.toUpperCase(),
        outcome: RealizeOutcome.blocked,
      );
      exitCode = 1;
      return;
    }
    for (final delta in gatedDeltas) {
      final entry = await receipts.record(
        file: delta.file,
        reason: handDeltaReason,
        adapter: adapter,
      );
      print(
        '   nuance receipt: ${delta.file} recorded '
        '(diff-hash ${entry.diffHash.substring(0, 12)}...) — '
        '"$handDeltaReason"',
      );
    }

    // ---------------------------------------------------------------
    // The contract gate, part 1: the BASELINE run — the mock-era suite
    // against the CURRENT (mock) binding, recorded BEFORE the rebind so
    // a red baseline blames the mock era, never the real impl.
    // ---------------------------------------------------------------
    final suitePaths = await _mockEraSuitePaths(cwd, featureDir);
    final suiteRunner = _suiteRunner();
    final baselineRun = await suiteRunner(suitePaths, cwd);
    final baseline = ContractRun(
      exitCode: baselineRun.exitCode,
      output: baselineRun.output,
    );
    final baselineGate = const ContractGate().evaluate(
      baseline: baseline,
      realRun: const ContractRun(exitCode: 0, output: '(not yet run)'),
    );
    if (baselineGate.verdict == ContractVerdict.mockBrokeContract) {
      print('   contract gate RED (baseline): ${baselineGate.attribution}');
      _printSummary(
        entity: entity,
        adapter: adapter,
        feature: feature,
        contract: _contractLabel(baselineGate.verdict),
        era: state.era.name.toUpperCase(),
        outcome: RealizeOutcome.blocked,
      );
      exitCode = 1;
      return;
    }

    // ---------------------------------------------------------------
    // The DI rebind: mock -> real behind the same generated interface.
    // The rebind is a generation step: its own writes are provenanced
    // with a #807 receipt so they are never mistaken for hand-deltas.
    // ---------------------------------------------------------------
    DiRebindResult rebind;
    try {
      rebind = await rebinder.rebind(entity: entity, adapterClass: adapter);
    } on DiRebindException catch (e) {
      _fail(
        'zfa tdd realize: ${e.message}',
        entity: entity,
        adapter: adapter,
        feature: feature,
      );
      return;
    }
    for (final site in rebind.sites) {
      print(
        '   rebound: ${p.relative(site.file, from: cwd)} '
        '(${site.occurrences} site(s))',
      );
    }
    print(
      '   interface preserved: ${rebind.interfaceFilesUntouched.length} '
      'domain file(s) byte-identical',
    );

    // ---------------------------------------------------------------
    // The contract gate, part 2: the mock-era suite runs UNCHANGED
    // against the real binding — must stay green. Any red rolls the
    // rebind back so the tree is exactly the mock-era tree again.
    // ---------------------------------------------------------------
    final realBindingRun = await suiteRunner(suitePaths, cwd);
    final gate = const ContractGate().evaluate(
      baseline: baseline,
      realRun: ContractRun(
        exitCode: realBindingRun.exitCode,
        output: realBindingRun.output,
      ),
    );
    if (!gate.isGreen) {
      print('   contract gate RED: ${gate.attribution}');
      if (gate.verdict == ContractVerdict.realBrokeContract) {
        await DiRebinder(projectRoot: cwd).rollback(rebind);
        print(
          '   rolled back: ${rebind.sites.length} binding file(s) '
          'restored to the mock-era bytes',
        );
      }
      print('   suite output (tail):');
      print(realBindingRun.output.split('\n').take(20).join('\n'));
      _printSummary(
        entity: entity,
        adapter: adapter,
        feature: feature,
        contract: _contractLabel(gate.verdict),
        era: state.era.name.toUpperCase(),
        outcome: RealizeOutcome.blocked,
      );
      exitCode = 1;
      return;
    }
    print('   contract gate green: ${gate.attribution}');

    // ---------------------------------------------------------------
    // The differential gate: real vs mock run the same committed
    // fixtures; the output diff becomes a drift report judged against
    // the .zfa.json threshold. Drift beyond it rolls the rebind back.
    // ---------------------------------------------------------------
    final diffGate = DifferentialGate(
      featureDir: featureDir,
      projectRoot: cwd,
      driver: _fixtureDriver(),
    );
    final differential = await diffGate.run(entity: entity);
    switch (differential.verdict) {
      case DifferentialVerdict.skipped:
        print(
          '   differential gate skipped: no committed fixtures under '
          '${p.relative(p.join(featureDir, 'tdd', 'fixtures'), from: cwd)} — '
          'the gate is marked skipped, never silently passed',
        );
      case DifferentialVerdict.pass:
        print(
          '   differential gate pass: drift ${differential.driftLabel} '
          '<= threshold ${differential.threshold}',
        );
      case DifferentialVerdict.drift:
        await DiRebinder(projectRoot: cwd).rollback(rebind);
        print(
          '   differential gate DRIFT: drift ${differential.driftLabel} > '
          'threshold ${differential.threshold} — the rebind was rolled '
          'back. Raise tdd.realizeDifferentialThreshold in .zfa.json only '
          'if the drift is intended.',
        );
        _printSummary(
          entity: entity,
          adapter: adapter,
          feature: feature,
          contract: _contractLabel(gate.verdict),
          differential: 'drift',
          drift: differential.driftLabel,
          threshold: '${differential.threshold}',
          era: state.era.name.toUpperCase(),
          outcome: RealizeOutcome.blocked,
        );
        exitCode = 1;
        return;
      case DifferentialVerdict.runnerError:
        await DiRebinder(projectRoot: cwd).rollback(rebind);
        print(
          '   differential gate RUNNER-ERROR: ${differential.error} — the '
          'rebind was rolled back (the gate fails closed).',
        );
        _printSummary(
          entity: entity,
          adapter: adapter,
          feature: feature,
          contract: _contractLabel(gate.verdict),
          differential: 'runner-error',
          drift: '-',
          threshold: '${differential.threshold}',
          era: state.era.name.toUpperCase(),
          outcome: RealizeOutcome.blocked,
        );
        exitCode = 1;
        return;
    }

    // ---------------------------------------------------------------
    // The state transition MOCKED -> REAL, persisted. The rebind is a
    // generation step: a #807 receipt covers its writes only once every
    // gate passed (a rolled-back swap writes no receipt — the restored
    // tree stays exactly the mock-era provenance). The transition leaves
    // era-tagged, hash-chained evidence in the cycle log.
    // ---------------------------------------------------------------
    await _receiptRebind(cwd, rebind);
    final next = await stateStore.transitionToReal(
      state: state,
      adapter: adapter,
      evidence: {
        'contract': _contractLabel(gate.verdict),
        'suitePaths': suitePaths.length,
        'differential': differential.verdict.name,
        'drift': differential.driftLabel,
        'threshold': differential.threshold,
        'fixtures': differential.fixturesRun,
        'handDeltas': gatedDeltas.length,
      },
    );
    await stateStore.save(next);
    print('   state: MOCKED -> REAL (${stateStore.path})');

    await EraTaggedLog(featureDir).append(
      EraTaggedLogEntry(
        behaviorId: '${toSnakeCase(entity)}-realize',
        kind: 'realize',
        era: RealizeEra.real,
        criterion: 'SC-1..SC-5',
        test: suitePaths.isEmpty
            ? '-'
            : 'mock-era suite (${suitePaths.length} file(s))',
        command:
            'zfa tdd realize $entity --adapter $adapter'
            '${featureFlag.isEmpty ? '' : ' --feature $featureFlag'}',
        exitCode: 0,
        output:
            'contract=${_contractLabel(gate.verdict)} '
            'differential=${differential.verdict.name} '
            'drift=${differential.driftLabel} '
            'handDeltas=$gatedDeltas'
            ' era=MOCKED->REAL result=realized',
      ),
    );
    print('   evidence: era-tagged cycle-log entry appended (era REAL)');

    _printSummary(
      entity: entity,
      adapter: adapter,
      feature: feature,
      contract: _contractLabel(gate.verdict),
      differential: differential.verdict.name,
      drift: differential.driftLabel,
      threshold: '${differential.threshold}',
      era: 'MOCKED->REAL',
      outcome: RealizeOutcome.realized,
    );
    exitCode = 0;
  }

  /// The machine-summary label for a contract verdict.
  static String _contractLabel(ContractVerdict verdict) {
    switch (verdict) {
      case ContractVerdict.green:
        return 'green';
      case ContractVerdict.realBrokeContract:
        return 'real-broke-contract';
      case ContractVerdict.mockBrokeContract:
        return 'mock-broke-contract';
    }
  }

  /// The fixture driver: injected for fast-tier tests, the project's
  /// `tool/realize_driver.dart` subprocess protocol in production (the
  /// input JSON travels on stdin, the output JSON returns on stdout).
  RealizeFixtureDriver _fixtureDriver() {
    final override = _fixtureDriverOverride;
    if (override != null) return override;
    return (binding, entity, input) async {
      final driverScript = File(
        p.join(_resolvedRoot, 'tool', 'realize_driver.dart'),
      );
      if (!driverScript.existsSync()) {
        throw StateError(
          'tool/realize_driver.dart not found — the differential gate '
          'needs the project-owned driver (see the realize command docs).',
        );
      }
      final process = await Process.start('dart', [
        'run',
        'tool/realize_driver.dart',
        '--binding',
        binding,
        '--entity',
        entity,
      ], workingDirectory: _resolvedRoot);
      process.stdin.write(jsonEncode(input));
      await process.stdin.close();
      final stdoutText = await process.stdout.transform(utf8.decoder).join();
      final stderrText = await process.stderr.transform(utf8.decoder).join();
      final driverExit = await process.exitCode;
      if (driverExit != 0) {
        throw StateError(
          'driver failed (exit $driverExit): $stdoutText$stderrText',
        );
      }
      final decoded = jsonDecode(stdoutText);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('driver printed non-object JSON');
      }
      return decoded;
    };
  }

  /// The project root this invocation resolved (the driver spawn cwd).
  String _resolvedRoot = '';

  /// The suite runner: injected for fast-tier tests, real `dart test`
  /// subprocess in production.
  RealizeSuiteRunner _suiteRunner() {
    final override = _suiteRunnerOverride;
    if (override != null) return override;
    return (paths, workingDirectory) async {
      if (paths.isEmpty) {
        return (exitCode: 0, output: '(no mock-era suite registered)');
      }
      final result = await Process.run('dart', [
        'test',
        ...paths,
      ], workingDirectory: workingDirectory);
      return (
        exitCode: result.exitCode,
        output: '${result.stdout}${result.stderr}',
      );
    };
  }

  /// The mock-era suite scope: the feature's registered test files that
  /// exist on disk. The suite runs UNCHANGED — realize never edits a test.
  Future<List<String>> _mockEraSuitePaths(String cwd, String featureDir) async {
    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    final paths = <String>[];
    for (final record in records) {
      final path = p.normalize(
        p.isAbsolute(record.testPath)
            ? record.testPath
            : p.join(cwd, record.testPath),
      );
      if (await File(path).exists()) paths.add(path);
    }
    return paths;
  }

  /// Resolve the target: a behavior id through the registry, or an entity
  /// name via the `create entity <Name>` convention in the descriptions.
  Future<_Target?> _resolveTarget(
    String cwd,
    String target,
    String featureFlag,
  ) async {
    final entries = <_RegistryEntry>[];
    if (featureFlag.isNotEmpty) {
      final featureDir = p.join(cwd, 'specs', featureFlag);
      if (await File(p.join(featureDir, 'tdd', 'artifacts.json')).exists()) {
        entries.add(
          _RegistryEntry(featureFlag, ArtifactRegistry(featureDir: featureDir)),
        );
      }
    } else {
      final specsDir = Directory(p.join(cwd, 'specs'));
      if (await specsDir.exists()) {
        final dirs = specsDir.listSync().whereType<Directory>().toList()
          ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
        for (final dir in dirs) {
          if (await File(p.join(dir.path, 'tdd', 'artifacts.json')).exists()) {
            entries.add(
              _RegistryEntry(
                p.basename(dir.path),
                ArtifactRegistry(featureDir: dir.path),
              ),
            );
          }
        }
      }
    }

    // 1. A registered behavior id: the record's feature is the home, and
    //    its description names the entity (the `create entity X`
    //    convention the planner emits).
    for (final entry in entries) {
      final record = await entry.registry.findRecord(target);
      if (record != null) {
        final entity = _entityFromDescription(record.descriptionSegment);
        if (entity == null) {
          throw _ResolveError(
            'behavior "$target" carries no entity in its description '
            '("${record.descriptionSegment}") — pass the entity name as '
            'the target instead.',
          );
        }
        return _Target(entry.feature, entity);
      }
    }

    // 2. An entity target: find the feature whose records mention it.
    for (final entry in entries) {
      for (final record in await entry.registry.loadAll()) {
        if (_entityFromDescription(record.descriptionSegment) == target) {
          return _Target(entry.feature, target);
        }
      }
    }

    // 3. An entity target with exactly one feature home carrying a
    //    registry: the unambiguous default.
    if (featureFlag.isEmpty && entries.length == 1) {
      return _Target(entries.single.feature, target);
    }
    return null;
  }

  /// `create entity User with email` -> `User` (the planner's description
  /// convention; null when no entity is named).
  static String? _entityFromDescription(String description) {
    final m = RegExp(
      r'entity\s+([A-Za-z_][A-Za-z0-9_]*)',
      caseSensitive: true,
    ).firstMatch(description);
    return m?.group(1);
  }

  void _fail(
    String message, {
    required String entity,
    required String adapter,
    required String feature,
  }) {
    print(message);
    _printSummary(
      entity: entity,
      adapter: adapter,
      feature: feature,
      contract: '-',
      era: '-',
      outcome: RealizeOutcome.runnerError,
    );
    exitCode = 1;
  }

  void _printSummary({
    required String entity,
    required String adapter,
    required String feature,
    required String contract,
    String differential = '-',
    String drift = '-',
    String threshold = '-',
    int handDeltas = 0,
    required String era,
    required RealizeOutcome outcome,
  }) {
    print(
      'realize: entity=$entity adapter=$adapter feature=$feature '
      'contract=$contract differential=$differential drift=$drift '
      'threshold=$threshold handDeltas=$handDeltas era=$era '
      'result=${outcome.label}',
    );
  }

  /// Write the #807 generation receipt covering the rebind's writes so
  /// the swap itself is provenanced (never a hand-delta).
  Future<void> _receiptRebind(String cwd, DiRebindResult rebind) async {
    final files = <GenerationReceiptFile>[];
    for (final site in rebind.sites) {
      final bytes = await File(site.file).readAsBytes();
      files.add(
        GenerationReceiptFile(
          path: _normalizeRel(p.relative(site.file, from: cwd)),
          action: 'update',
          sha256: _sha256(bytes),
          bytes: bytes.length,
        ),
      );
    }
    await ReceiptStore(projectRoot: cwd).save(
      GenerationReceipt(
        command: 'zfa tdd realize',
        target: rebind.entity,
        repro:
            'zfa tdd realize ${rebind.entity} '
            '--adapter ${rebind.adapterClass}',
        at: DateTime.now().toUtc(),
        generatorVersion: '6.1.0',
        input: {
          'entity': rebind.entity,
          'mockClass': rebind.mockClass,
          'adapter': rebind.adapterClass,
        },
        files: files,
      ),
    );
  }

  String _sha256(List<int> bytes) {
    return crypto.sha256.convert(bytes).toString();
  }

  static String _normalizeRel(String rel) =>
      p.posix.normalize(p.posix.joinAll(p.split(rel))).replaceAll('\\', '/');
}

class _ResolveError implements Exception {
  _ResolveError(this.message);
  final String message;
  @override
  String toString() => message;
}

class _RegistryEntry {
  const _RegistryEntry(this.feature, this.registry);
  final String feature;
  final ArtifactRegistry registry;
}

class _Target {
  const _Target(this.feature, this.entity);
  final String feature;
  final String entity;
}
