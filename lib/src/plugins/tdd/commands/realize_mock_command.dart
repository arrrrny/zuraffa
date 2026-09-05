/// `zfa tdd realize-mock <Entity> --against=firestore` — the Tier-1 vs
/// Tier-2 differential gate (issue #1009, ZIKZAK-REBUILD; extends spec
/// 913's realize with a certification that never rebinds DI).
///
/// `zfa tdd realize` (#913) swaps mock → REAL and gates that crossing.
/// This command certifies a cheaper, earlier parity: the SAME contract
/// cases run against (a) the Tier-1 mock — the mock-era oracle, its
/// output recorded in the committed fixtures (or produced through the
/// tier-1 driver protocol) — and (b) a [Tier2MockProvider], a
/// Firestore-shaped adapter behind the same invocation surface, backed
/// by a [FakeFirebaseFirestore]. Divergence (value OR type) is a
/// failure; identical results certify the pair.
///
/// The gate is per-entity, never per-method: exit 0 only when every
/// method's `diff == none`. A divergent method is named in the output
/// and recorded in the receipt.
///
/// The differential receipt — `realize.<Entity>.firestore.receipt.json`
/// under `.zfa/receipts/` — carries one record per contract case
/// `{method, tier1_result, tier2_result, diff: none|mismatch}` inside a
/// `proof.v1` envelope, so `zfa proof check` parses and counts it.
///
/// Nothing in the target tree is mutated: the Tier-2 swap lives for the
/// duration of the run (a fresh provider per case, seeded from the
/// fixture's `seed` records), the receipt and an era-tagged cycle-log
/// entry are the only writes.
///
/// Summary (house convention): the LAST stdout line is machine-readable:
///
///     realize-mock: entity=<E> against=<A> feature=<F> methods=<N>
///                   mismatch=<M> result=<certified|mismatch|...>
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../services/artifact_registry.dart';
import '../services/entity_lookup.dart' show toSnakeCase;
import '../services/era_tagged_log.dart';
import '../services/realize_mock_receipt.dart';
import '../services/realize_state.dart';
import '../services/tier2_firestore/fake_firebase_firestore.dart';
import '../services/tier2_firestore/tier2_mock_provider.dart';
import '../tdd_plugin.dart';
import 'realize_command.dart' show RealizeSuiteRunner;

/// Executes one contract case through the Tier-1 mock (the realize
/// driver protocol: input JSON in, output JSON out). Injectable for
/// fast-tier tests; the production default spawns the project's
/// `tool/realize_driver.dart` with `--binding tier1`.
typedef RealizeMockTier1Driver =
    Future<Map<String, dynamic>> Function(
      String entity,
      Map<String, dynamic> input,
    );

/// Builds a fresh Tier-2 provider per contract case (state isolation).
/// Injectable for fast-tier tests (the divergent-method cases).
typedef Tier2ProviderFactory = Tier2MockProvider Function(String entity);

/// Outcome labels for the machine-readable summary line.
enum RealizeMockOutcome {
  certified('certified'),
  mismatch('mismatch'),
  tier1Red('tier1-red'),
  blocked('blocked'),
  runnerError('runner-error'),
  usageError('usage-error');

  const RealizeMockOutcome(this.label);
  final String label;
}

/// The only `--against` target the differential gate supports today
/// (issue #1009 names exactly one; more land with their own receipts).
const List<String> supportedAgainst = ['firestore'];

class RealizeMockCommand extends Command<void> {
  RealizeMockCommand(
    this.plugin, {
    RealizeSuiteRunner? suiteRunner,
    RealizeMockTier1Driver? tier1Driver,
    Tier2ProviderFactory? tier2ProviderFactory,
  }) : _suiteRunnerOverride = suiteRunner,
       _tier1DriverOverride = tier1Driver,
       _tier2ProviderFactoryOverride = tier2ProviderFactory {
    argParser.addFlag(
      'json',
      help:
          'Emit the receipt JSON document as the final stdout line '
          '(machine-readable verdict).',
      negatable: false,
    );
    argParser.addOption(
      'against',
      allowed: supportedAgainst,
      help:
          'The Tier-2 adapter shape the differential runs against '
          '(issue #1009: firestore). Required.',
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 047-tdd-make). Restricts entity resolution '
          'to specs/<feature>. When omitted, feature registries are '
          'scanned for the entity.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, lib/, test/. Defaults to the '
          'current working directory.',
    );
  }

  final TddPlugin plugin;

  final RealizeSuiteRunner? _suiteRunnerOverride;

  final RealizeMockTier1Driver? _tier1DriverOverride;

  final Tier2ProviderFactory? _tier2ProviderFactoryOverride;

  @override
  String get name => 'realize-mock';

  @override
  String get description =>
      'Run the Tier-1 contract test, then the same contract cases through '
      'a Firestore-shaped Tier2MockProvider (backed by a fake '
      'FirebaseFirestore), and certify the pair with a per-method '
      'differential receipt (issue #1009). Divergence = exit 1 with the '
      'mismatched method named.';

  @override
  String get invocation =>
      'zfa tdd realize-mock <entity> --against=firestore [options]';

  /// The project root this invocation resolved (driver spawn cwd).
  String _resolvedRoot = '';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    final entity = rest.isNotEmpty ? rest.first.trim() : '';
    final against = (argResults?['against'] as String?)?.trim() ?? '';
    final featureFlag = (argResults?['feature'] as String?)?.trim() ?? '';
    final projectFlag = (argResults?['project'] as String?)?.trim() ?? '';
    final jsonMode = argResults?['json'] as bool? ?? false;

    // ---------------------------------------------------------------
    // Argument validation (misfire-stop, never a guess).
    // ---------------------------------------------------------------
    if (entity.isEmpty) {
      _fail(
        'zfa tdd realize-mock: an entity name is required. Usage: '
        '$invocation',
        entity: '-',
        against: against,
        feature: featureFlag,
        methods: 0,
        mismatch: 0,
        outcome: RealizeMockOutcome.usageError,
      );
      return;
    }
    if (against.isEmpty) {
      _fail(
        'zfa tdd realize-mock: --against <target> is required — the '
        'differential needs the Tier-2 adapter shape to swap in '
        '(supported: ${supportedAgainst.join(', ')}).',
        entity: entity,
        against: '-',
        feature: featureFlag,
        methods: 0,
        mismatch: 0,
        outcome: RealizeMockOutcome.usageError,
      );
      return;
    }

    final cwd = projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    _resolvedRoot = cwd;

    print('zfa tdd realize-mock: entity $entity -> against $against');

    // ---------------------------------------------------------------
    // Resolve the feature + the entity's Tier-1 contract test through
    // the artifact registries (the realize resolution surface).
    // ---------------------------------------------------------------
    final resolved = await _resolveEntity(cwd, entity, featureFlag);
    if (resolved == null) {
      _fail(
        'zfa tdd realize-mock: unknown entity "$entity". No record in any '
        'specs/<feature>/tdd/artifacts.json names it — pass --feature '
        '<name> to pin the feature home.',
        entity: entity,
        against: against,
        feature: featureFlag,
        methods: 0,
        mismatch: 0,
        outcome: RealizeMockOutcome.usageError,
      );
      return;
    }
    final feature = resolved.feature;
    final featureDir = p.join(cwd, 'specs', feature);
    print('   feature: $feature');

    final contractTests = <String>[];
    for (final record in resolved.records) {
      final path = p.normalize(
        p.isAbsolute(record.testPath)
            ? record.testPath
            : p.join(cwd, record.testPath),
      );
      if (await File(path).exists()) contractTests.add(path);
    }
    if (contractTests.isEmpty) {
      _fail(
        'zfa tdd realize-mock: no contract test for entity $entity — the '
        'registry names ${resolved.records.length} record(s) but none of '
        'their test files exist on disk. The differential gate refuses '
        'to certify an unloaded contract.',
        entity: entity,
        against: against,
        feature: feature,
        methods: 0,
        mismatch: 0,
        outcome: RealizeMockOutcome.blocked,
      );
      return;
    }
    print(
      '   tier-1 contract test: ${contractTests.length} file(s) '
      '(${contractTests.map((f) => p.relative(f, from: cwd)).join(', ')})',
    );

    // ---------------------------------------------------------------
    // The Tier-1 contract run: the registered suite must be green
    // BEFORE any differential is meaningful — a red Tier-1 baseline
    // blames the mock era, never the Tier-2 adapter (fail-closed).
    // ---------------------------------------------------------------
    final suiteRunner = _suiteRunner();
    final tier1Run = await suiteRunner(contractTests, cwd);
    if (tier1Run.exitCode != 0) {
      print(
        '   tier-1 contract test RED (exit ${tier1Run.exitCode}) — the '
        'mock era is broken; the differential is not run and nothing is '
        'certified.',
      );
      _printSummary(
        entity: entity,
        against: against,
        feature: feature,
        methods: 0,
        mismatch: 0,
        outcome: RealizeMockOutcome.tier1Red,
      );
      exitCode = 1;
      return;
    }
    print('   tier-1 contract test green (exit 0)');

    // ---------------------------------------------------------------
    // The contract cases: the committed fixtures under
    // specs/<feature>/tdd/fixtures/ — each one method invocation (its
    // `input.op`), optionally carrying a recorded Tier-1 oracle
    // (`mockOutput`) and `seed` records pre-loaded into the Tier-2
    // store before the invocation.
    // ---------------------------------------------------------------
    final fixturesDir = Directory(p.join(featureDir, 'tdd', 'fixtures'));
    if (!await fixturesDir.exists()) {
      _fail(
        'zfa tdd realize-mock: no committed contract cases — the '
        'differential needs specs/<feature>/tdd/fixtures/*.json (one '
        'method case per fixture: input.op + args, optional recorded '
        'mockOutput, optional seed). An empty surface is never '
        'certified.',
        entity: entity,
        against: against,
        feature: feature,
        methods: 0,
        mismatch: 0,
        outcome: RealizeMockOutcome.blocked,
      );
      return;
    }
    final fixtureFiles =
        fixturesDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    if (fixtureFiles.isEmpty) {
      _fail(
        'zfa tdd realize-mock: specs/<feature>/tdd/fixtures/ is empty — '
        'the differential needs at least one committed method case.',
        entity: entity,
        against: against,
        feature: feature,
        methods: 0,
        mismatch: 0,
        outcome: RealizeMockOutcome.blocked,
      );
      return;
    }

    // ---------------------------------------------------------------
    // The differential: per contract case, the Tier-1 oracle (recorded
    // mockOutput, else the tier-1 driver protocol) vs a fresh
    // Firestore-shaped Tier2MockProvider (seeded per case). Comparison
    // is JSON-encoding equality — `42` vs `"42"` is a type mismatch.
    // Every case runs; the receipt records all of them (the gate is
    // per-entity, so one row never short-circuits the rest).
    // ---------------------------------------------------------------
    final records = <RealizeMockMethodRecord>[];
    final mismatches = <RealizeMockMethodRecord>[];
    for (final file in fixtureFiles) {
      final caseId = p.basenameWithoutExtension(file.path);
      Map<String, dynamic>? fixture;
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) fixture = decoded;
      } on FormatException {
        fixture = null;
      }
      final input = fixture?['input'];
      if (fixture == null || input is! Map<String, dynamic>) {
        _fail(
          'zfa tdd realize-mock: fixture $caseId is not a '
          'realize-diff.v1 document (schema, input.op missing) — fix the '
          'fixture before certifying.',
          entity: entity,
          against: against,
          feature: feature,
          methods: records.length,
          mismatch: mismatches.length,
          outcome: RealizeMockOutcome.runnerError,
        );
        return;
      }
      final op = input['op'];
      if (op is! String || op.isEmpty) {
        _fail(
          'zfa tdd realize-mock: fixture $caseId carries no input.op — '
          'the contract method name is required to route both tiers.',
          entity: entity,
          against: against,
          feature: feature,
          methods: records.length,
          mismatch: mismatches.length,
          outcome: RealizeMockOutcome.runnerError,
        );
        return;
      }
      final args = <String, dynamic>{
        for (final entry in input.entries)
          if (entry.key != 'op') entry.key: entry.value,
      };

      // Tier 1: the recorded oracle, else the driver protocol.
      Object? tier1Result;
      final recorded = fixture['mockOutput'];
      if (recorded is Map<String, dynamic>) {
        tier1Result = recorded;
      } else {
        try {
          tier1Result = await _tier1Driver()(entity, input);
        } catch (error) {
          _fail(
            'zfa tdd realize-mock: the tier-1 driver failed on $caseId '
            '($op): $error — the differential fails closed.',
            entity: entity,
            against: against,
            feature: feature,
            methods: records.length,
            mismatch: mismatches.length,
            outcome: RealizeMockOutcome.runnerError,
          );
          return;
        }
      }

      // Tier 2: a fresh Firestore-shaped provider, seeded per case.
      final provider = _tier2ProviderFactory()(entity);
      final seed = fixture['seed'];
      if (seed is List) {
        final seedRecords = <Map<String, dynamic>>[];
        for (final entry in seed) {
          if (entry is Map<String, dynamic>) {
            seedRecords.add(entry);
          } else if (entry is Map) {
            seedRecords.add(Map<String, dynamic>.from(entry));
          }
        }
        try {
          await provider.seed(seedRecords);
        } on ArgumentError catch (error) {
          _fail(
            'zfa tdd realize-mock: fixture $caseId carries an invalid '
            'seed — $error.',
            entity: entity,
            against: against,
            feature: feature,
            methods: records.length,
            mismatch: mismatches.length,
            outcome: RealizeMockOutcome.runnerError,
          );
          return;
        }
      }
      Object? tier2Result;
      try {
        tier2Result = await provider.invoke(op, args);
      } on Tier2MockMethodError catch (error) {
        tier2Result = <String, dynamic>{'error': '$error'};
      }

      final diff =
          jsonEncode(_sortJson(tier1Result)) ==
              jsonEncode(_sortJson(tier2Result))
          ? 'none'
          : 'mismatch';
      final record = RealizeMockMethodRecord(
        method: op,
        tier1Result: tier1Result,
        tier2Result: tier2Result,
        diff: diff,
      );
      records.add(record);
      if (record.isMismatch) mismatches.add(record);
      print(
        '   method ${op.padRight(24)} tier1=${_preview(tier1Result)} '
        'tier2=${_preview(tier2Result)} diff=$diff',
      );
    }

    // ---------------------------------------------------------------
    // The per-entity gate: certified only when EVERY method's diff is
    // none. Divergent methods are named, both values shown.
    // ---------------------------------------------------------------
    final verdict = mismatches.isEmpty ? 'certified' : 'mismatch';
    final writer = RealizeMockReceiptWriter(projectRoot: cwd);
    final receiptFile = await writer.write(
      entity: entity,
      against: against,
      feature: feature,
      contractTests: [
        for (final path in contractTests) p.relative(path, from: cwd),
      ],
      methods: records,
      verdict: verdict,
    );
    print(
      '   receipt: ${p.relative(receiptFile.path, from: cwd)} '
      '(${records.length} method record(s), verdict $verdict)',
    );

    if (mismatches.isNotEmpty) {
      print(
        '   DIFFERENTIAL GATE MISMATCH: ${mismatches.length} of '
        '${records.length} method(s) diverge:',
      );
      for (final record in mismatches) {
        print(
          '   method ${record.method}: tier1=${_preview(record.tier1Result)} '
          'tier2=${_preview(record.tier2Result)} — the Tier-2 adapter '
          'diverged (value or type).',
        );
      }
    }

    await EraTaggedLog(featureDir).append(
      EraTaggedLogEntry(
        behaviorId: '${toSnakeCase(entity)}-realize-mock',
        kind: 'realize-mock',
        era: RealizeEra.mocked,
        criterion: 'issue #1009',
        test: contractTests.isEmpty
            ? '-'
            : 'tier-1 contract test (${contractTests.length} file(s))',
        command:
            'zfa tdd realize-mock $entity --against=$against'
            '${featureFlag.isEmpty ? '' : ' --feature $featureFlag'}',
        exitCode: mismatches.isEmpty ? 0 : 1,
        output:
            'methods=${records.length} mismatch=${mismatches.length} '
            'verdict=$verdict receipt=${p.basename(receiptFile.path)}',
      ),
    );
    print('   evidence: era-tagged cycle-log entry appended (era MOCKED)');

    // The per-entity gate's exit code holds in every output mode.
    exitCode = mismatches.isEmpty ? 0 : 1;

    if (jsonMode) {
      print(
        jsonEncode(
          RealizeMockReceiptWriter.documentFor(
            entity: entity,
            against: against,
            feature: feature,
            contractTests: [
              for (final path in contractTests) p.relative(path, from: cwd),
            ],
            methods: records,
            verdict: verdict,
          ),
        ),
      );
      return;
    }

    _printSummary(
      entity: entity,
      against: against,
      feature: feature,
      methods: records.length,
      mismatch: mismatches.length,
      outcome: mismatches.isEmpty
          ? RealizeMockOutcome.certified
          : RealizeMockOutcome.mismatch,
    );
  }

  // -----------------------------------------------------------------
  // Resolution: the feature home + the entity's registry records.
  // -----------------------------------------------------------------

  /// The entity's records in one feature's registry (the `create entity
  /// X` description convention the planner emits; every record when the
  /// feature was pinned explicitly and names no entity).
  Future<_EntityResolution?> _resolveEntity(
    String cwd,
    String entity,
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

    // A feature naming the entity in any record is the entity's home.
    for (final entry in entries) {
      final records = await entry.registry.loadAll();
      final named = _recordsForEntity(records, entity);
      if (named != null) {
        return _EntityResolution(entry.feature, named);
      }
    }
    // A pinned feature with records but no entity mention: the pinned
    // home stands (the user asserted the feature owns the entity).
    if (featureFlag.isNotEmpty && entries.isNotEmpty) {
      final records = await entries.single.registry.loadAll();
      if (records.isNotEmpty) {
        return _EntityResolution(featureFlag, records);
      }
    }
    return null;
  }

  /// The records whose descriptions name [entity] (the `create entity X`
  /// convention), or null when none do.
  static List<ArtifactRecord>? _recordsForEntity(
    List<ArtifactRecord> records,
    String entity,
  ) {
    final RegExp entityPattern = RegExp(
      'entity\\s+${RegExp.escape(entity)}\\b',
      caseSensitive: true,
    );
    final matches = <ArtifactRecord>[];
    for (final record in records) {
      final description = record.descriptionSegment;
      if (description == entity || entityPattern.hasMatch(description)) {
        matches.add(record);
      }
    }
    return matches.isEmpty ? null : matches;
  }

  // -----------------------------------------------------------------
  // Injectable defaults.
  // -----------------------------------------------------------------

  RealizeSuiteRunner _suiteRunner() {
    final override = _suiteRunnerOverride;
    if (override != null) return override;
    return (paths, workingDirectory) async {
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

  RealizeMockTier1Driver _tier1Driver() {
    final override = _tier1DriverOverride;
    if (override != null) return override;
    return (entity, input) async {
      final driverScript = File(
        p.join(_resolvedRoot, 'tool', 'realize_driver.dart'),
      );
      if (!driverScript.existsSync()) {
        throw StateError(
          'tool/realize_driver.dart not found — the tier-1 side needs the '
          'project-owned driver when a fixture records no mockOutput '
          '(see the realize command docs).',
        );
      }
      final process = await Process.start('dart', [
        'run',
        'tool/realize_driver.dart',
        '--binding',
        'tier1',
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
          'tier-1 driver failed (exit $driverExit): $stdoutText$stderrText',
        );
      }
      final decoded = jsonDecode(stdoutText);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('tier-1 driver printed non-object JSON');
      }
      return decoded;
    };
  }

  Tier2ProviderFactory _tier2ProviderFactory() {
    final override = _tier2ProviderFactoryOverride;
    if (override != null) return override;
    return (entity) =>
        Tier2MockProvider(entity: entity, firestore: FakeFirebaseFirestore());
  }

  // -----------------------------------------------------------------
  // Output helpers.
  // -----------------------------------------------------------------

  void _fail(
    String message, {
    required String entity,
    required String against,
    required String feature,
    required int methods,
    required int mismatch,
    required RealizeMockOutcome outcome,
  }) {
    print(message);
    _printSummary(
      entity: entity,
      against: against,
      feature: feature,
      methods: methods,
      mismatch: mismatch,
      outcome: outcome,
    );
    exitCode = 1;
  }

  void _printSummary({
    required String entity,
    required String against,
    required String feature,
    required int methods,
    required int mismatch,
    required RealizeMockOutcome outcome,
  }) {
    print(
      'realize-mock: entity=$entity against=$against feature=$feature '
      'methods=$methods mismatch=$mismatch result=${outcome.label}',
    );
  }

  /// One-line result preview for the per-method log lines.
  static String _preview(Object? value) {
    final encoded = jsonEncode(value);
    return encoded.length > 60 ? '${encoded.substring(0, 57)}...' : encoded;
  }

  /// Canonical JSON shape for comparison: map keys sorted recursively so
  /// two structurally-equal documents compare equal regardless of key
  /// order (value AND type equality still enforced by the encoding).
  static Object? _sortJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => '$k').toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _sortJson(value[key]),
      };
    }
    if (value is List) {
      return <Object?>[for (final item in value) _sortJson(item)];
    }
    return value;
  }
}

class _RegistryEntry {
  const _RegistryEntry(this.feature, this.registry);
  final String feature;
  final ArtifactRegistry registry;
}

class _EntityResolution {
  const _EntityResolution(this.feature, this.records);
  final String feature;
  final List<ArtifactRecord> records;
}
