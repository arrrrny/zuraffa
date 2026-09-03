/// ZAP conformance suite (spec 071, issue #809, FR-008).
///
/// The executable form of the issue's first done-when criterion: "the
/// conformance suite passes for the reference client". `zfa zap conform`
/// runs every check here; `--drift-dir <dir>` adds the
/// published-contract drift gate (committed schemas/goldens vs the code).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'zap_client.dart';
import 'zap_executor.dart';
import 'zap_golden.dart';
import 'zap_host.dart';
import 'zap_message.dart';
import 'zap_protocol.dart';
import 'zap_schema.dart';
import 'zap_validator.dart';

/// One conformance check: named, boolean, with a detail line.
class ZapConformanceCheck {
  const ZapConformanceCheck(this.name, this.ok, this.detail);

  final String name;
  final bool ok;
  final String detail;

  Map<String, Object?> toJson() => {'name': name, 'ok': ok, 'detail': detail};
}

/// The suite's verdict.
class ZapConformanceReport {
  const ZapConformanceReport(this.checks);

  final List<ZapConformanceCheck> checks;

  int get passed => checks.where((c) => c.ok).length;

  int get failed => checks.where((c) => !c.ok).length;

  bool get ok => failed == 0;

  Map<String, Object?> toJson() => {
    'command': 'zfa zap conform',
    'ok': ok,
    'total': checks.length,
    'passed': passed,
    'failed': failed,
    'checks': [for (final c in checks) c.toJson()],
  };
}

/// Runs the ZAP conformance suite.
abstract final class ZapConformance {
  /// Runs all checks. [driftDir], when given, adds the published-contract
  /// drift gate over `<driftDir>/schemas/*.schema.json` and
  /// `<driftDir>/golden/*.golden.json`.
  static Future<ZapConformanceReport> run({String? driftDir}) async {
    final checks = <ZapConformanceCheck>[
      ..._schemaSelfIntegrity(),
      ..._goldenPositives(),
      ..._goldenRoundTrips(),
      ..._negativeTable(),
      ...await _referenceClientSession(),
      ...await _disciplineViolationSession(),
      if (driftDir != null) ..._driftGate(driftDir),
    ];
    return ZapConformanceReport(checks);
  }

  // ----------------------------------------------------------------
  // 1. Schema self-integrity
  // ----------------------------------------------------------------

  static List<ZapConformanceCheck> _schemaSelfIntegrity() => [
    for (final type in ZapSchema.types)
      ZapConformanceCheck(
        'schema:$type',
        _schemaIsSane(ZapSchema.forType(type)),
        'draft-07 object schema with a closed envelope',
      ),
  ];

  static bool _schemaIsSane(Map<String, Object?> schema) =>
      schema['\$schema'] == zapDraft &&
      schema['type'] == 'object' &&
      (schema['required'] as List?)?.isNotEmpty == true &&
      schema['properties'] is Map &&
      schema['additionalProperties'] == false;

  // ----------------------------------------------------------------
  // 2. Golden positives
  // ----------------------------------------------------------------

  static List<ZapConformanceCheck> _goldenPositives() => [
    for (final type in const ['mission', 'evidence', 'checkpoint', 'receipt'])
      () {
        final result = ZapValidator.validate(ZapGoldens.example(type));
        return ZapConformanceCheck(
          'golden:$type',
          result.ok,
          result.ok
              ? 'validates against schemas/$type.schema.json'
              : 'INVALID: ${result.issues.join('; ')}',
        );
      }(),
  ];

  // ----------------------------------------------------------------
  // 3. Golden <-> typed round-trips
  // ----------------------------------------------------------------

  static List<ZapConformanceCheck> _goldenRoundTrips() => [
    for (final type in const ['mission', 'evidence', 'checkpoint', 'receipt'])
      () {
        final golden = ZapGoldens.example(type);
        try {
          final typed = ZapMessage.fromJson(golden);
          final ok = _mapsEqual(typed.toJson(), golden);
          return ZapConformanceCheck(
            'roundtrip:$type',
            ok,
            ok
                ? 'fromJson(toJson()) equals the golden map'
                : 'round-trip drifted from the golden bytes',
          );
        } on ZapSchemaException catch (e) {
          return ZapConformanceCheck(
            'roundtrip:$type',
            false,
            'golden failed to parse: $e',
          );
        }
      }(),
  ];

  static bool _mapsEqual(Map<String, Object?> a, Map<String, Object?> b) =>
      jsonEncode(a) == jsonEncode(b);

  // ----------------------------------------------------------------
  // 4. The negative table — hallucinations are structurally impossible
  // ----------------------------------------------------------------

  static List<ZapConformanceCheck> _negativeTable() {
    Map<String, Object?> mutated(void Function(Map<String, Object?>) fn) {
      final copy = ZapGoldens.example('mission');
      fn(copy);
      return copy;
    }

    final cases = <(String, Map<String, Object?>?, String, String)>[
      ('not-json', null, 'schema', ''),
      ('missing-goal', mutated((m) => m.remove('goal')), 'schema', 'goal'),
      (
        'missing-budget-maxSteps',
        mutated((m) => (m['budget'] as Map).remove('maxSteps')),
        'schema',
        'budget.maxSteps',
      ),
      (
        'bad-phase-enum',
        mutated((m) => (m['steps'] as List)[0]['phase'] = 'vibes'),
        'schema',
        'steps[0].phase',
      ),
      (
        'zero-budget',
        mutated((m) => m['budget'] = {'maxSteps': 0}),
        'schema',
        'budget.maxSteps',
      ),
      (
        'empty-steps',
        mutated((m) => m['steps'] = <Object?>[]),
        'schema',
        'steps',
      ),
      (
        'hallucinated-field',
        mutated((m) => m['priority'] = 'URGENT'),
        'schema',
        'priority',
      ),
      ('wrong-type-typed', mutated((m) => m['goal'] = 42), 'schema', 'goal'),
      (
        'unknown-type',
        <String, Object?>{
          'zap': zapProtocolVersion,
          'type': 'telepathy',
          'id': 'x',
          'ts': '2026-09-03T10:00:00Z',
        },
        'schema',
        'type',
      ),
      ('wrong-version', mutated((m) => m['zap'] = '2.0'), 'version', 'zap'),
    ];

    return [
      for (final (name, message, code, needle) in cases)
        () {
          String actualCode;
          List<String> detail = const [];
          if (message == null) {
            // The garbage-line path: the host's decode failure.
            actualCode = 'schema';
          } else {
            try {
              ZapMessage.fromJson(message);
              actualCode = '(accepted!)';
            } on ZapSchemaException catch (e) {
              actualCode = e.classification ?? 'schema';
              detail = [for (final i in e.issues) i.toString()];
            }
          }
          final ok =
              actualCode == code &&
              (needle.isEmpty || detail.join(' ').contains(needle));
          return ZapConformanceCheck(
            'reject:$name',
            ok,
            ok
                ? 'rejected as $code (path: $needle)'
                : 'expected rejection as $code naming $needle; got '
                      '$actualCode [${detail.join('; ')}]',
          );
        }(),
      // Non-object roots through the raw entry.
      ZapConformanceCheck(
        'reject:not-an-object',
        !ZapValidator.validateRaw('nope').ok,
        'a non-object line is rejected',
      ),
    ];
  }

  // ----------------------------------------------------------------
  // 5. Reference-client session (in-process, scripted executor)
  // ----------------------------------------------------------------

  static Future<List<ZapConformanceCheck>> _referenceClientSession() async {
    final checks = <ZapConformanceCheck>[];
    try {
      final session = await _driveSession(
        exits: {'s1': 1, 's2': 0, 's3': 0},
        missionId: 'conform-ref',
      );
      checks.add(
        ZapConformanceCheck(
          'session:receipt-pass',
          session.receipt.verdict == 'pass' && session.receipt.exit == 0,
          'mission -> evidence -> receipt verdict=pass '
              '(${session.receipt.stepsExecuted} steps)',
        ),
      );
      checks.add(
        ZapConformanceCheck(
          'session:chain-verified',
          session.client.recomputeChainDigest('conform-ref') ==
              session.receipt.chainDigest,
          'the client recomputed chain equals the receipt chainDigest',
        ),
      );
      checks.add(
        ZapConformanceCheck(
          'session:client-verified-receipt',
          session.client.verifyReceipt(session.receipt),
          'verifyReceipt: verdict + checks + digest all agree',
        ),
      );
    } catch (e) {
      checks.add(
        ZapConformanceCheck(
          'session:reference-client',
          false,
          'session failed: $e',
        ),
      );
    }
    return checks;
  }

  // ----------------------------------------------------------------
  // 6. Discipline violation session (a dishonest loop must FAIL)
  // ----------------------------------------------------------------

  static Future<List<ZapConformanceCheck>> _disciplineViolationSession() async {
    try {
      final session = await _driveSession(
        exits: {'s1': 0, 's2': 0}, // red PASSES — dishonest loop
        missionId: 'conform-discipline',
      );
      final receipt = session.receipt;
      final discipline = receipt.checks.firstWhere(
        (c) => c.name == 'tdd-discipline',
      );
      return [
        ZapConformanceCheck(
          'session:discipline-fail',
          receipt.verdict == 'fail' &&
              receipt.exit == 1 &&
              !discipline.ok &&
              (discipline.detail ?? '').contains('red'),
          'a passing red flips the receipt to fail with the rule named',
        ),
      ];
    } catch (e) {
      return [
        ZapConformanceCheck(
          'session:discipline-fail',
          false,
          'session failed: $e',
        ),
      ];
    }
  }

  static Future<({ZapClient client, ZapReceipt receipt})> _driveSession({
    required Map<String, int> exits,
    required String missionId,
  }) async {
    final host = ZapHost(
      executor: ScriptedZapStepExecutor(
        (step) async =>
            zapScriptedRun(step, exits[step.id] ?? 0, 'scripted ${step.id}'),
      ),
    );

    final toHost = StreamController<String>();
    final toClient = StreamController<String>();
    final pump = () async {
      await for (final line in toHost.stream) {
        await host.handleLine(line, emit: toClient.add);
      }
    }();
    pump.ignore;

    final client = ZapClient(inbound: () => toClient.stream, send: toHost.add)
      ..start();

    final receipt = await client.submit(
      MissionEnvelope(
        id: 'm-conform',
        ts: DateTime.now().toUtc().toIso8601String(),
        missionId: missionId,
        agent: 'zap-conformance',
        goal: 'self-test session',
        maxSteps: 8,
        riskTier: 'standard',
        toolAllowlist: const ['dart'],
        steps: [
          for (final entry in exits.entries)
            MissionStep(
              id: entry.key,
              command: 'dart demo ${entry.key}',
              phase: entry.key == 's1'
                  ? 'red'
                  : entry.key == 's2'
                  ? 'green'
                  : 'verify',
            ),
        ],
      ),
    );
    return (client: client, receipt: receipt);
  }

  // ----------------------------------------------------------------
  // 7. Published-contract drift gate
  // ----------------------------------------------------------------

  static List<ZapConformanceCheck> _driftGate(String driftDir) {
    final checks = <ZapConformanceCheck>[];

    for (final entry in ZapSchema.all.entries) {
      final name = 'drift:${entry.key}.schema.json';
      final file = File('$driftDir/schemas/${entry.key}.schema.json');
      if (!file.existsSync()) {
        checks.add(ZapConformanceCheck(name, false, 'file missing'));
        continue;
      }
      try {
        final committed = jsonDecode(file.readAsStringSync());
        final ok = _mapsEqualDeep(
          committed as Map<String, Object?>,
          entry.value,
        );
        checks.add(
          ZapConformanceCheck(
            name,
            ok,
            ok ? 'committed schema equals the code' : 'schema DRIFTED',
          ),
        );
      } catch (e) {
        checks.add(ZapConformanceCheck(name, false, 'unparseable: $e'));
      }
    }

    for (final type in const ['mission', 'evidence', 'checkpoint', 'receipt']) {
      final name = 'drift:$type.golden.json';
      final file = File('$driftDir/golden/$type.golden.json');
      if (!file.existsSync()) {
        checks.add(ZapConformanceCheck(name, false, 'file missing'));
        continue;
      }
      try {
        final committed = jsonDecode(file.readAsStringSync());
        final ok = _mapsEqualDeep(
          committed as Map<String, Object?>,
          ZapGoldens.example(type),
        );
        checks.add(
          ZapConformanceCheck(
            name,
            ok,
            ok ? 'committed golden equals the code' : 'golden DRIFTED',
          ),
        );
      } catch (e) {
        checks.add(ZapConformanceCheck(name, false, 'unparseable: $e'));
      }
    }

    return checks;
  }

  static bool _mapsEqualDeep(Map a, Map b) => jsonEncode(a) == jsonEncode(b);
}
