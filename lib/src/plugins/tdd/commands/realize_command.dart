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
///      (differential gate — the #1195 harness: contract-relevant
///      outputs (entity shapes, state transitions, error kinds) diff
///      with NAMED rows; a divergence blocks with the row's input,
///      mock output, real output, and contract clause),
///   4. records hand-written deltas as nuance receipts in the feature's
///      provenance ledger (legal gated; ungated blocked),
///   5. transitions the state MOCKED → REAL with era-tagged cycle-log
///      evidence,
///   6. LOCATES the certified mock behind the interface (the #1110 cert
///      registry — a red certification blocks the crossing; the honest
///      ladder never lies about which tier it is in),
///   7. SCAFFOLDS a missing real adapter behind the SAME interface with
///      --scaffold (the hand-delta seam: stamped and receipted in the
///      provenance ledger, NEVER pretended generated),
///   8. advances the behavior's ladder state MOCKED → REAL → DONE in the
///      unified journal (#1113) — behavior states to `done` in
///      tdd/run-state.json, the era to REAL in realize-state.json, a
///      schema-valid meta entry in tdd/journal.json,
///   9. writes the hand-delta receipt (`tdd/realize-receipt.v1`): files,
///      digests, gate outcomes, and the generated/mock/hand ratios,
///  10. previews the ENTIRE swap with --dry-run — every write named,
///      nothing written.
///
/// Summary (house convention): the LAST stdout line is machine-readable:
///
///     realize: entity=<E> adapter=<A> feature=<F> contract=<verdict>
///              era=MOCKED->REAL result=<realized|blocked|dry-run|...>
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../../../core/project/receipt_store.dart';
import '../../../version.dart';
import '../../mock/certification/cert_registry.dart';
import '../services/artifact_registry.dart';
import '../services/entity_lookup.dart' show toSnakeCase;
import '../services/adapter_scaffolder.dart';
import '../services/contract_gate.dart';
import '../services/di_rebind.dart';
import '../services/era_tagged_log.dart';
import '../services/journal.dart';
import '../services/nuance_receipts.dart';
import '../services/realize_receipt.dart';
import '../services/realize_state.dart';
import '../services/run_state_store.dart';
import '../services/differential_harness.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
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
  runnerError('runner-error'),
  diffClean('diff-clean'),
  diffDivergence('diff-divergence'),
  diffSkipped('diff-skipped'),

  /// The --dry-run preview (spec 1193): the plan was named, nothing was
  /// written. Exit code carries the would-refuse verdict.
  dryRun('dry-run');

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
          'Emit a canonical zuraffa.verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addFlag(
      'diff-only',
      negatable: false,
      help:
          'Run ONLY the differential harness (spec 1195): replay the '
          'committed fixtures through the certified mock side and the '
          'real adapter, diff the contract-relevant outputs (entity '
          'shapes, state transitions, error kinds), and write the '
          'deterministic, journal-consumable receipt. Nothing is '
          'rebound, no suite runs, no state transitions — the receipt '
          'and an era-tagged entry are the only writes.',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help:
          'Preview the swap (spec 1193): name every write the swap would '
          'make — the rebinding sites, the contract suite, the '
          'differential replay, the scaffold plan, the journal advance '
          'and its hand-delta receipt — and write NOTHING. Exit 0 when '
          'the swap would proceed, 1 with the reason named when it would '
          'be refused.',
    );
    argParser.addFlag(
      'scaffold',
      negatable: false,
      help:
          'Scaffold a MISSING real adapter behind the SAME interface the '
          'certified mock implements (spec 1193): an UnimplementedError '
          'stub stamped as the hand-delta seam and receipted in the '
          'provenance ledger — never pretended generated. Without this '
          'flag a missing adapter class is still a refusal.',
    );
    argParser.addOption(
      'adapter',
      help:
          'The real adapter class to bind (must already exist in lib/ — '
          'realize never generates real implementations). Required for the '
          'swap flow; optional receipt metadata with --diff-only.',
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

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  final RealizeSuiteRunner? _suiteRunnerOverride;

  final RealizeFixtureDriver? _fixtureDriverOverride;

  @override
  String get name => 'realize';

  @override
  String get description =>
      'Run the mock-to-real swap flow (spec 913; --adapter required), gated '
      'by the contract suite and real-vs-mock differential; --diff-only '
      'replays ONLY the standalone differential harness (spec 1195; '
      '--adapter optional) without touching the tree. Spec 1193 adds the '
      'certified-mock location, --scaffold (the hand-delta seam), '
      '--dry-run (preview, zero writes), the unified-journal ladder '
      'advance MOCKED->REAL->DONE, and the realize hand-delta receipt '
      'with generated/mock/hand ratios.';

  @override
  String get invocation =>
      'zfa tdd realize <entity|behavior> [--adapter <real>] [--diff-only] '
      '[--dry-run] [--scaffold] [options]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final startedAt = DateTime.now().toUtc().toIso8601String();
    final rest = argResults?.rest ?? const <String>[];
    final target = rest.isNotEmpty ? rest.first.trim() : '';
    final adapter = (argResults?['adapter'] as String?)?.trim() ?? '';
    final featureFlag = (argResults?['feature'] as String?)?.trim() ?? '';
    final projectFlag = (argResults?['project'] as String?)?.trim() ?? '';
    final diffOnly = (argResults?['diff-only'] as bool? ?? false);
    final dryRun = (argResults?['dry-run'] as bool? ?? false);
    final scaffold = (argResults?['scaffold'] as bool? ?? false);

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
    // --diff-only replays the differential WITHOUT binding anything, so
    // --adapter is optional metadata there (named in the receipt when
    // given); the swap path still refuses to guess.
    if (adapter.isEmpty && !diffOnly) {
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
    // --dry-run previews the SWAP; --diff-only replays the standalone
    // differential. Both are read-only, but they are different lenses —
    // one invocation, one lens (misfire-stop, never a guess).
    if (dryRun && diffOnly) {
      _fail(
        'zfa tdd realize: --dry-run and --diff-only are mutually exclusive '
        '— --dry-run previews the swap, --diff-only replays the standalone '
        'differential. Pick one.',
        entity: target,
        adapter: adapter,
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
    print(
      'zfa tdd realize${diffOnly
          ? ' --diff-only'
          : dryRun
          ? ' --dry-run'
          : ''}: '
      'entity $entity '
      '${diffOnly ? 'replayed against' : '-> adapter'} '
      '${adapter.isEmpty ? 'the real binding' : adapter}',
    );
    print('   feature: $feature');
    if (dryRun) {
      print('   mode: dry-run (preview — nothing will be written)');
    }

    // ---------------------------------------------------------------
    // Era state: MOCKED is the default (mock-first realization).
    // ---------------------------------------------------------------
    final stateStore = RealizeStateStore(featureDir);
    final state = await stateStore.loadOrDefault(
      feature: feature,
      entity: entity,
    );
    print('   era: ${state.era.name.toUpperCase()}');

    // ---------------------------------------------------------------
    // The standalone differential replay (spec 1195): the harness runs
    // ALONE — no nuance scan, no baseline suite, no rebind, no contract
    // suite, no state transition. The receipt (mode diff-only) and an
    // era-tagged entry are the only writes; the tree is untouched.
    // ---------------------------------------------------------------
    if (diffOnly) {
      await _runDiffOnly(
        cwd: cwd,
        entity: entity,
        adapter: adapter,
        feature: feature,
        featureDir: featureDir,
        state: state,
        featureFlag: featureFlag,
      );
      return;
    }

    // ---------------------------------------------------------------
    // The certified-mock location (spec 1193, step 1): the #1110 cert
    // registry answers whether the mock behind the interface is
    // certified. A RED certification (unsatisfied/corrupt/stale) blocks
    // the crossing — the honest ladder never crosses on a mock whose own
    // certification is red. A MISSING certification is named, never
    // silently assumed.
    // ---------------------------------------------------------------
    final rebinder = DiRebinder(projectRoot: cwd);
    final receipts = NuanceReceipts(featureDir: featureDir, projectRoot: cwd);
    final certEntry = CertRegistry.checkEntity(
      entity: entity,
      projectRoot: cwd,
    );
    final mockImplFiles = await rebinder.mockImplementationFiles(
      entity: entity,
    );
    final mocksTotal = mockImplFiles.length;
    final mocksCertified = certEntry.status == CertRegistryStatus.certified
        ? 1
        : 0;
    switch (certEntry.status) {
      case CertRegistryStatus.certified:
        print('   certified mock located: mocks $mocksCertified/$mocksTotal');
      case CertRegistryStatus.missing:
      case CertRegistryStatus.notReferenced:
        print(
          '   mock not certified (${certEntry.status.name}): mocks '
          '$mocksCertified/$mocksTotal — named, never assumed. '
          'Fix: ${certEntry.fix.isEmpty ? CertRegistry.certifyFixCommand(entity) : certEntry.fix}',
        );
      case CertRegistryStatus.unsatisfied:
      case CertRegistryStatus.corrupt:
      case CertRegistryStatus.stale:
        print('   mock certification is RED: ${certEntry.reason}');
        if (dryRun) {
          print(
            '   would refuse: the certified mock behind the interface is '
            'red — a red certification never crosses to REAL.',
          );
          _printSummary(
            entity: entity,
            adapter: adapter,
            feature: feature,
            contract: '-',
            mocks: '$mocksCertified/$mocksTotal',
            era: state.era.name.toUpperCase(),
            outcome: RealizeOutcome.dryRun,
          );
          exitCode = 1;
          return;
        }
        print(
          '   Fix: ${certEntry.fix} — a red certification never crosses to REAL.',
        );
        _printSummary(
          entity: entity,
          adapter: adapter,
          feature: feature,
          contract: '-',
          mocks: '$mocksCertified/$mocksTotal',
          era: state.era.name.toUpperCase(),
          outcome: RealizeOutcome.blocked,
        );
        exitCode = 1;
        return;
    }

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
    final sites = await rebinder.scan(entity: entity);
    final surface = <String>[
      for (final site in sites) site.file,
      ...mockImplFiles,
    ].map((f) => _normalizeRel(p.relative(f, from: cwd))).toList();
    final unrecorded = await receipts.detect(files: surface);
    final ungated = unrecorded
        .where((d) => !handDeltaFlags.contains(d.file))
        .toList();

    // ---------------------------------------------------------------
    // The --dry-run preview (spec 1193): name every write the swap
    // would make — and make NONE. Runs AFTER the read-only nuance
    // detection so a would-be refusal is part of the preview.
    // ---------------------------------------------------------------
    if (dryRun) {
      await _runDryRun(
        cwd: cwd,
        entity: entity,
        adapter: adapter,
        feature: feature,
        featureDir: featureDir,
        state: state,
        scaffold: scaffold,
        sites: sites,
        mockImplFiles: mockImplFiles,
        suitePaths: await _mockEraSuitePaths(cwd, featureDir),
        ungated: ungated,
        mocksCertified: mocksCertified,
        mocksTotal: mocksTotal,
      );
      return;
    }
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
    // The adapter seam (spec 1193, step 2): the swap binds a named real
    // adapter class. A missing class WITH --scaffold is scaffolded
    // behind the SAME interface the certified mock implements — the
    // hand-delta seam, stamped and receipted in the provenance ledger,
    // never pretended generated. A missing class WITHOUT --scaffold
    // keeps the spec 913 refusal.
    // ---------------------------------------------------------------
    ScaffoldResult? scaffoldResult;
    final scaffoldLedgerBefore = await _ledgerBytes(receipts.path);
    Future<void> rollbackScaffold() async {
      if (scaffoldResult?.created != true) return;
      await File(scaffoldResult!.file).delete();
      final ledgerFile = File(receipts.path);
      if (scaffoldLedgerBefore == null) {
        if (await ledgerFile.exists()) await ledgerFile.delete();
      } else {
        await ledgerFile.writeAsBytes(scaffoldLedgerBefore);
      }
    }

    try {
      await rebinder.locateAdapter(adapterClass: adapter);
    } on DiRebindException catch (_) {
      if (!scaffold) {
        _fail(
          'zfa tdd realize: no file under lib/ declares "class $adapter" — '
          'pass --scaffold to scaffold it as the hand-delta seam behind the '
          'SAME interface (receipted in the provenance ledger, never '
          'pretended generated), or write the adapter first. Realize never '
          'silently generates real implementations.',
          entity: entity,
          adapter: adapter,
          feature: feature,
        );
        return;
      }
      if (mockImplFiles.isEmpty) {
        _fail(
          'zfa tdd realize: cannot scaffold $adapter — no mock '
          'implementation file declares the interface to scaffold behind. '
          'Write the adapter by hand.',
          entity: entity,
          adapter: adapter,
          feature: feature,
        );
        return;
      }
      try {
        scaffoldResult = await AdapterScaffolder(
          projectRoot: cwd,
        ).scaffold(adapterClass: adapter, mockFile: mockImplFiles.first);
      } on ScaffoldException catch (e) {
        _fail(
          'zfa tdd realize: ${e.message}',
          entity: entity,
          adapter: adapter,
          feature: feature,
        );
        return;
      }
      final scaffoldRel = _normalizeRel(
        p.relative(scaffoldResult.file, from: cwd),
      );
      if (scaffoldResult.created) {
        print(
          '   scaffolded: $scaffoldRel behind ${scaffoldResult.interfaceName} '
          '(${scaffoldResult.methods.length} method(s), hand-delta seam — '
          'receipted, never pretended generated)',
        );
        final scaffoldEntry = await receipts.record(
          file: scaffoldRel,
          reason:
              'scaffolded by zfa tdd realize (spec 1193) — the hand-delta '
              'seam behind ${scaffoldResult.interfaceName}; fill in the '
              'real implementation. Never pretended generated.',
          adapter: adapter,
          recordedBy: 'zfa tdd realize --scaffold',
        );
        print(
          '   nuance receipt: $scaffoldRel recorded as the hand-delta seam '
          '(diff-hash ${scaffoldEntry.diffHash.substring(0, 12)}...)',
        );
      } else {
        print(
          '   scaffold exists: $scaffoldRel (left untouched — a re-scaffold '
          'never clobbers filled-in work)',
        );
      }
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
      await rollbackScaffold();
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
        await rollbackScaffold();
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
    // The differential gate (spec 1195, the REAL tier's honesty gate):
    // the same committed fixtures replay through the certified mock
    // side and the real adapter, the contract-relevant outputs (entity
    // shapes, state transitions, error kinds) diff with NAMED rows, and
    // a divergence blocks the promotion with the row's input, mock
    // output, real output, and contract clause. The receipt lands in
    // the feature's tdd/ directory (journal-consumable, #1113).
    // ---------------------------------------------------------------
    final harness = DifferentialHarness(
      featureDir: featureDir,
      projectRoot: cwd,
      driver: _fixtureDriver(),
      mode: 'embedded',
    );
    final differential = await harness.run(entity: entity, adapter: adapter);
    switch (differential.verdict) {
      case DifferentialVerdict.skipped:
        print(
          '   differential gate skipped: no committed fixtures under '
          '${p.relative(p.join(featureDir, 'tdd', 'fixtures'), from: cwd)} — '
          'the gate is marked skipped (not_assessed), never silently '
          'passed',
        );
      case DifferentialVerdict.pass:
        print(
          '   differential gate pass: ${differential.rows.length} row(s) / '
          '${differential.compared} compared field(s) <= threshold '
          '${differential.threshold}',
        );
        _printNamedRows(differential, withinThreshold: true);
      case DifferentialVerdict.divergence:
        await DiRebinder(projectRoot: cwd).rollback(rebind);
        await rollbackScaffold();
        print(
          '   differential gate DIVERGENCE: ${differential.rows.length} '
          'named row(s) — the rebind was rolled back. The mock and the '
          'real adapter disagree on contract behavior; fix the real side '
          'or raise tdd.realizeDifferentialThreshold in .zfa.json only '
          'if the divergence is intended.',
        );
        _printNamedRows(differential, withinThreshold: false);
        _printSummary(
          entity: entity,
          adapter: adapter,
          feature: feature,
          contract: _contractLabel(gate.verdict),
          differential: 'divergence',
          drift: differential.divergenceLabel,
          threshold: '${differential.threshold}',
          era: state.era.name.toUpperCase(),
          outcome: RealizeOutcome.blocked,
        );
        exitCode = 1;
        return;
      case DifferentialVerdict.runnerError:
        await DiRebinder(projectRoot: cwd).rollback(rebind);
        await rollbackScaffold();
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
        'rows': differential.rows.length,
        'compared': differential.compared,
        'drift': differential.divergenceLabel,
        'threshold': differential.threshold,
        'fixtures': differential.replayed,
        'handDeltas': gatedDeltas.length,
      },
    );
    await stateStore.save(next);
    print('   state: MOCKED -> REAL (${stateStore.path})');

    // ---------------------------------------------------------------
    // The journal advance (spec 1193, step 6): the behavior's ladder
    // state MOCKED → (era REAL) → DONE in the unified journal — the
    // behavior states advance in tdd/run-state.json (only behaviors in
    // the mocked state; pending/red stay honest) and a schema-valid
    // meta entry records the advance in tdd/journal.json (#1113).
    // ---------------------------------------------------------------
    final behaviorIds = await _collectBehaviorIds(featureDir, entity, target);
    final advanced = await _advanceBehaviorStates(featureDir, behaviorIds);
    if (behaviorIds.isNotEmpty) {
      print(
        '   ladder: ${behaviorIds.length} behavior(s) MOCKED -> DONE'
        '${advanced.isEmpty ? '' : ' (${advanced.join(', ')})'}',
      );
    }

    // The hand-delta receipt (spec 1193): files, digests, gate outcomes,
    // and the generated/mock/hand ratios over the swap's surface. The
    // rebind's writes are bucketed `generated` (they carry the #807
    // receipt), the mock's own files `mock`, the adapter seam and the
    // gated deltas `hand`.
    Future<RealizeReceiptFile> receiptFile(
      String absPath,
      String action,
      RealizeFileBucket bucket,
    ) async {
      final bytes = await File(absPath).readAsBytes();
      return RealizeReceiptFile(
        path: _normalizeRel(p.relative(absPath, from: cwd)),
        action: action,
        bucket: bucket,
        sha256: _sha256(bytes),
        bytes: bytes.length,
      );
    }

    final receiptFiles = <RealizeReceiptFile>[
      for (final site in rebind.sites)
        await receiptFile(site.file, 'update', RealizeFileBucket.generated),
      for (final mockFile in mockImplFiles)
        await receiptFile(mockFile, 'mock', RealizeFileBucket.mock),
      if (scaffoldResult != null)
        await receiptFile(
          scaffoldResult.file,
          scaffoldResult.created ? 'scaffold' : 'adapter',
          RealizeFileBucket.hand,
        )
      else
        await receiptFile(
          rebind.adapterFile,
          'adapter',
          RealizeFileBucket.hand,
        ),
      for (final delta in gatedDeltas)
        RealizeReceiptFile(
          path: delta.file,
          action: 'hand-delta',
          bucket: RealizeFileBucket.hand,
          sha256: delta.actualHash ?? '-',
          bytes: 0,
        ),
    ];
    final ratios = RealizeRatios(
      generated: receiptFiles
          .where((f) => f.bucket == RealizeFileBucket.generated)
          .length,
      mock: receiptFiles
          .where((f) => f.bucket == RealizeFileBucket.mock)
          .length,
      hand: receiptFiles
          .where((f) => f.bucket == RealizeFileBucket.hand)
          .length,
    );
    final swapReceipt = RealizeReceipt(
      feature: feature,
      entity: entity,
      adapter: adapter,
      ladderFrom: 'MOCKED',
      ladderTo: 'REAL',
      behaviorState: behaviorIds.isEmpty ? null : 'done',
      contract: _contractLabel(gate.verdict),
      differential: differential.verdict.name,
      threshold: '${differential.threshold}',
      rows: differential.rows.length,
      compared: differential.compared,
      handDeltas: gatedDeltas.length,
      files: receiptFiles,
      ratios: ratios,
      mocksTotal: mocksTotal,
      mocksCertified: mocksCertified,
      scaffolded: (scaffoldResult?.created ?? false)
          ? _normalizeRel(p.relative(scaffoldResult!.file, from: cwd))
          : null,
      at: DateTime.now().toUtc(),
    );
    await RealizeReceiptStore(featureDir).save(swapReceipt);
    print(
      '   receipt: specs/$feature/tdd/${RealizeReceiptStore.fileName} '
      '(files ${receiptFiles.length}, ratios ${ratios.cell})',
    );

    // The unified journal entry (#1113): cycle meta, phase aggregate,
    // gate green, result realized — the machine-parseable record of the
    // MOCKED → REAL → DONE advance, referencing the receipts.
    final journalWriter = JournalWriter(featureDir);
    final refs = await journalWriter.resolveRefs();
    const differentialReceiptRel = 'tdd/differential-receipt.json';
    await journalWriter.append(
      JournalEntry(
        feature: feature,
        cycle: 'meta',
        phase: 'aggregate',
        startedAt: startedAt,
        finishedAt: DateTime.now().toUtc().toIso8601String(),
        gateState: 'green',
        receipts: [
          'tdd/${RealizeReceiptStore.fileName}',
          if (File(p.join(featureDir, differentialReceiptRel)).existsSync())
            differentialReceiptRel,
        ],
        violations: const [],
        engineReceipt: refs.engine,
        skinReceipt: refs.skin,
        contractSchema: refs.contract,
        result: 'realized',
        behaviors: behaviorIds,
        counts: {
          'behaviors': behaviorIds.length,
          'advanced': advanced.length,
          'handDeltas': gatedDeltas.length,
        },
        mocks: {'total': mocksTotal, 'certified': mocksCertified},
      ),
    );
    print(
      '   journal: unified journal entry appended (#1113) — MOCKED -> '
      'REAL -> DONE',
    );

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
            'rows=${differential.rows.length} '
            'drift=${differential.divergenceLabel} '
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
      drift: differential.divergenceLabel,
      threshold: '${differential.threshold}',
      handDeltas: gatedDeltas.length,
      mocks: '$mocksCertified/$mocksTotal',
      scaffold: scaffoldResult == null
          ? '-'
          : _normalizeRel(p.relative(scaffoldResult.file, from: cwd)),
      era: 'MOCKED->REAL',
      outcome: RealizeOutcome.realized,
    );
    exitCode = 0;
  }

  /// The standalone differential replay (spec 1195, SC-5): the harness
  /// runs ALONE against the committed fixtures — no nuance scan, no
  /// baseline suite, no rebind, no contract suite, no state transition,
  /// no rebind receipt. The receipt (mode diff-only) and an era-tagged
  /// cycle-log entry (kind realize-diff, era unchanged) are the only
  /// writes. Exit 0 on pass/skipped (skipped is named, never silent),
  /// 1 on divergence / runner-error — a divergent real adapter is
  /// proven BEFORE the swap is attempted.
  Future<void> _runDiffOnly({
    required String cwd,
    required String entity,
    required String adapter,
    required String feature,
    required String featureDir,
    required RealizeState state,
    required String featureFlag,
  }) async {
    final harness = DifferentialHarness(
      featureDir: featureDir,
      projectRoot: cwd,
      driver: _fixtureDriver(),
      mode: 'diff-only',
    );
    final differential = await harness.run(
      entity: entity,
      adapter: adapter.isEmpty ? '-' : adapter,
    );
    switch (differential.verdict) {
      case DifferentialVerdict.skipped:
        print(
          '   differential replay skipped: no committed fixtures under '
          '${p.relative(p.join(featureDir, 'tdd', 'fixtures'), from: cwd)} — '
          'the gate is marked skipped (not_assessed), never silently '
          'passed',
        );
      case DifferentialVerdict.pass:
        print(
          '   differential replay pass: ${differential.rows.length} '
          'row(s) / ${differential.compared} compared field(s) <= '
          'threshold ${differential.threshold}',
        );
        _printNamedRows(differential, withinThreshold: true);
      case DifferentialVerdict.divergence:
        print(
          '   differential replay DIVERGENCE: ${differential.rows.length} '
          'named row(s) — the mock and the real adapter disagree on '
          'contract behavior (the receipt records gate_state red for the '
          'journal).',
        );
        _printNamedRows(differential, withinThreshold: false);
      case DifferentialVerdict.runnerError:
        print(
          '   differential replay RUNNER-ERROR: ${differential.error} '
          '(the gate fails closed).',
        );
    }
    print(
      '   receipt: ${p.relative(p.join(featureDir, 'tdd', 'differential-receipt.json'), from: cwd)} '
      '(mode diff-only, digest ${differential.fixturesDigest.substring(0, 19)}...)',
    );

    final outcome = switch (differential.verdict) {
      DifferentialVerdict.pass => RealizeOutcome.diffClean,
      DifferentialVerdict.skipped => RealizeOutcome.diffSkipped,
      DifferentialVerdict.divergence => RealizeOutcome.diffDivergence,
      DifferentialVerdict.runnerError => RealizeOutcome.runnerError,
    };

    await EraTaggedLog(featureDir).append(
      EraTaggedLogEntry(
        behaviorId: '${toSnakeCase(entity)}-diff',
        kind: 'realize-diff',
        era: state.era,
        criterion: 'SC-1195',
        test: differential.replayed == 0
            ? '-'
            : '${differential.replayed} fixture(s)',
        command:
            'zfa tdd realize $entity --diff-only'
            '${adapter.isEmpty ? '' : ' --adapter $adapter'}'
            '${featureFlag.isEmpty ? '' : ' --feature $featureFlag'}',
        exitCode: switch (differential.verdict) {
          DifferentialVerdict.divergence => 1,
          DifferentialVerdict.runnerError => 1,
          _ => 0,
        },
        output:
            'differential=${differential.verdict.name} '
            'rows=${differential.rows.length} '
            'compared=${differential.compared} '
            'drift=${differential.divergenceLabel} '
            'era=${state.era.name.toUpperCase()} '
            'result=${outcome.label}',
      ),
    );

    _printSummary(
      entity: entity,
      adapter: adapter.isEmpty ? '-' : adapter,
      feature: feature,
      contract: '-',
      differential: differential.verdict.name,
      drift: differential.verdict == DifferentialVerdict.runnerError
          ? '-'
          : differential.divergenceLabel,
      threshold: '${differential.threshold}',
      era: state.era.name.toUpperCase(),
      outcome: outcome,
    );
    exitCode = switch (differential.verdict) {
      DifferentialVerdict.divergence => 1,
      DifferentialVerdict.runnerError => 1,
      _ => 0,
    };
  }

  /// The --dry-run preview (spec 1193): name every write the swap would
  /// make — and make NONE. Reads only: the binding scan, the cert
  /// registry, the nuance detection, the suite/fixture census, and the
  /// scaffold plan (validated, never written). Exit 0 when the swap
  /// would proceed; 1 with the would-refuse reason named when it would
  /// not.
  Future<void> _runDryRun({
    required String cwd,
    required String entity,
    required String adapter,
    required String feature,
    required String featureDir,
    required RealizeState state,
    required bool scaffold,
    required List<DiBindingSite> sites,
    required List<String> mockImplFiles,
    required List<String> suitePaths,
    required List<HandDelta> ungated,
    required int mocksCertified,
    required int mocksTotal,
  }) async {
    print(
      '   dry-run: preview of `zfa tdd realize $entity --adapter $adapter` '
      '— nothing was written',
    );
    final refusals = <String>[];
    for (final site in sites) {
      print(
        '   would rebind: ${_normalizeRel(p.relative(site.file, from: cwd))} '
        '(${site.occurrences} site(s))',
      );
    }
    print(
      '   would run: the mock-era suite (${suitePaths.length} file(s)) '
      'UNCHANGED against the real binding — the contract gate',
    );
    print(
      '   would replay: ${await _fixtureCount(featureDir)} committed '
      'fixture(s) through the differential harness (#1195)',
    );
    if (sites.isEmpty) {
      refusals.add(
        'no mock binding found for $entity — only a mock-era project can '
        'be realized',
      );
    }
    // The scaffold plan: validated, NOT written (write: false).
    final adapterPresent = await _adapterExists(cwd, adapter);
    if (!adapterPresent && scaffold) {
      if (mockImplFiles.isEmpty) {
        refusals.add(
          'cannot scaffold $adapter — no mock implementation file '
          'declares the interface to scaffold behind',
        );
      } else {
        try {
          final plan = await AdapterScaffolder(projectRoot: cwd).scaffold(
            adapterClass: adapter,
            mockFile: mockImplFiles.first,
            write: false,
          );
          print(
            '   would scaffold: '
            '${_normalizeRel(p.relative(plan.file, from: cwd))} behind '
            '${plan.interfaceName} (${plan.methods.length} method(s), '
            'hand-delta seam, receipted — never pretended generated)',
          );
        } on ScaffoldException catch (e) {
          refusals.add(e.message);
        }
      }
    } else if (!adapterPresent) {
      refusals.add(
        'no file under lib/ declares "class $adapter" — pass --scaffold '
        'to scaffold the hand-delta seam or write the adapter first',
      );
    }
    if (ungated.isNotEmpty) {
      refusals.add(
        '${ungated.length} unrecorded hand-delta(s) on the realization '
        'surface — record them with --hand-delta/--reason or revert them',
      );
      for (final delta in ungated) {
        print('   hand-delta: ${delta.file} (${delta.detail})');
      }
    }
    print(
      '   would advance: MOCKED -> REAL (era) with the behavior ladder to '
      'DONE in the unified journal (#1113) + the hand-delta receipt '
      '(generated/mock/hand ratios)',
    );
    for (final refusal in refusals) {
      print('   would refuse: $refusal');
    }
    _printSummary(
      entity: entity,
      adapter: adapter,
      feature: feature,
      contract: '-',
      mocks: '$mocksCertified/$mocksTotal',
      era: state.era.name.toUpperCase(),
      outcome: RealizeOutcome.dryRun,
    );
    exitCode = refusals.isEmpty ? 0 : 1;
  }

  /// The registry behavior ids the swap covers: every record whose
  /// description names the entity (the planner convention), plus the
  /// target itself when it was a registered behavior id.
  Future<List<String>> _collectBehaviorIds(
    String featureDir,
    String entity,
    String target,
  ) async {
    final registry = ArtifactRegistry(featureDir: featureDir);
    final ids = <String>{};
    for (final record in await registry.loadAll()) {
      if (record.behaviorId == target ||
          _entityFromDescription(record.descriptionSegment) == entity) {
        ids.add(record.behaviorId);
      }
    }
    return ids.toList()..sort();
  }

  /// The behavior-state half of the ladder advance (spec 1193): every
  /// behavior the swap covers that sits in the `mocked` state advances
  /// to `done` in tdd/run-state.json. Pending/red/green behaviors are
  /// never touched — the ladder is honest about what it advanced.
  Future<List<String>> _advanceBehaviorStates(
    String featureDir,
    List<String> behaviorIds,
  ) async {
    if (behaviorIds.isEmpty) return const [];
    final store = RunStateStore(featureDir);
    final state = await store.load();
    if (state == null) return const [];
    var next = state;
    final advanced = <String>[];
    for (final id in behaviorIds) {
      if (next.behaviorStates[id] == BehaviorState.mocked) {
        next = next.advance(id, BehaviorState.done);
        advanced.add(id);
      }
    }
    if (advanced.isNotEmpty) await store.save(next);
    return advanced;
  }

  /// The committed fixture census for the preview (read-only).
  Future<int> _fixtureCount(String featureDir) async {
    final dir = Directory(p.join(featureDir, 'tdd', 'fixtures'));
    if (!await dir.exists()) return 0;
    return dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .length;
  }

  /// Whether any file under lib/ declares the adapter class.
  Future<bool> _adapterExists(String cwd, String adapter) async {
    try {
      await DiRebinder(projectRoot: cwd).locateAdapter(adapterClass: adapter);
      return true;
    } on DiRebindException {
      return false;
    }
  }

  /// Print the harness's named rows: the row id, its contract clause,
  /// and — for a blocking divergence — the full four-field row (input,
  /// mock output, real output). Rows within a consciously raised
  /// threshold are still named (never silenced), compactly.
  void _printNamedRows(
    DifferentialHarnessResult differential, {
    required bool withinThreshold,
  }) {
    for (final row in differential.rows) {
      print(
        '   ${withinThreshold ? 'row (within threshold)' : 'divergence'}: '
        '${row.id} (${row.dimension.label}) — ${row.detail}',
      );
      print('     clause: ${row.clause}');
      if (!withinThreshold) {
        print('     input: ${jsonEncode(row.input)}');
        print('     mock:  ${jsonEncode(row.mockOutput)}');
        print('     real:  ${jsonEncode(row.realOutput)}');
      }
    }
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
    String mocks = '-',
    String scaffold = '-',
    required String era,
    required RealizeOutcome outcome,
  }) {
    print(
      'realize: entity=$entity adapter=$adapter feature=$feature '
      'contract=$contract differential=$differential drift=$drift '
      'threshold=$threshold handDeltas=$handDeltas mocks=$mocks '
      'scaffold=$scaffold era=$era result=${outcome.label}',
    );
    // Issue #969: the realize outcome label IS the exit class.
    _verdict
      ..exitClass = outcome.label
      ..outcome = switch (outcome) {
        RealizeOutcome.realized => VerdictOutcome.pass,
        RealizeOutcome.alreadyReal => VerdictOutcome.pass,
        RealizeOutcome.diffClean => VerdictOutcome.pass,
        RealizeOutcome.diffSkipped => VerdictOutcome.pass,
        RealizeOutcome.dryRun => VerdictOutcome.pass,
        _ => VerdictOutcome.fail,
      }
      ..details['entity'] = entity
      ..details['adapter'] = adapter
      ..details['hand_deltas'] = handDeltas
      ..details['mocks'] = mocks
      ..details['scaffold'] = scaffold
      ..feature = feature == 'unknown' ? null : feature;
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
        generatorVersion: version,
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

  Future<List<int>?> _ledgerBytes(String path) async {
    final file = File(path);
    return await file.exists() ? file.readAsBytes() : null;
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
