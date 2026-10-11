@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';
import 'package:zuraffa/src/core/benchmark/baseline_store.dart';
import 'package:zuraffa/src/core/verdict_envelope.dart';

/// SPEC 1132 / EPIC 1 lane 2 — the verdict-envelope unification's backlog
/// emitters (issue #1105's `kExcluded` allow-list).
///
/// Three `--json` surfaces on master still emit divergent shapes the ONE
/// canonical parser (`VerdictEnvelope.fromJson` / `tryParse`) rejects:
///
///   * `zfa provider verify <Entity> --json` — the `{"schema":1,...}`
///     `ProviderVerifyReport` dump;
///   * `zfa benchmark list --json` — a raw `{"scenarios":[...]}` document
///     with no schema at all;
///   * the generic capability path's machine-mode missing-arguments
///     refusal — `{"schema":1,"ok":false,...}`.
///
/// `VerdictEnvelope.tryParse` returns null for all three today; each test
/// pins the canonical `zuraffa.verdict.v1` envelope with the real verdict,
/// exit class and subject, and the payload riding in `details`.
void main() {
  late CliRunner runner;
  late Directory tmp;

  setUp(() async {
    runner = CliRunner(exitOnCompletion: false);
    tmp = await Directory.systemTemp.createTemp('verdict_1132_');
  });

  tearDown(() async {
    exitCode = 0;
    if (tmp.existsSync()) {
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    }
  });

  Future<String> drive(List<String> args) =>
      runner.runCapturing(['-C', tmp.path, ...args]);

  group('SPEC 1132 L2 — provider verify --json speaks verdict.v1', () {
    setUp(() async {
      final entityDir = Directory(
        p.join(tmp.path, 'lib', 'src', 'domain', 'entities', 'product'),
      );
      await entityDir.create(recursive: true);
      await File(p.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;
  const Product({required this.id});
}
''');
      await File(p.join(tmp.path, 'pubspec.yaml')).writeAsString('''
name: verdict_1132_fixture
environment:
  sdk: ^3.11.0
''');
    });

    test(
      'missing provider emits the canonical envelope (fail, exit 1)',
      () async {
        final out = await drive(['provider', 'verify', 'Product', '--json']);

        final envelope = VerdictEnvelope.tryParse(out);
        expect(
          envelope,
          isNotNull,
          reason:
              'the machine output must carry one canonical '
              '`zuraffa.verdict.v1` envelope (issue #1105 backlog emitter; '
              'the old {"schema":1,...} dump is a foreign document to the '
              'canonical parser).\nstdout:\n$out',
        );
        expect(envelope!.verdict, VerdictKind.fail);
        expect(envelope.exitClass, ExitProtocol.failure);
        expect(envelope.subject?.kind, 'provider');
        expect(envelope.subject?.id, 'Product');
        expect(
          envelope.findings,
          isNotEmpty,
          reason: 'the missing-provider finding must stay machine-readable',
        );
        expect(
          envelope.findings.first.fix,
          isNotNull,
          reason: 'every finding keeps its machine-actionable fix line',
        );
        expect(
          CliRunner.lastDispatchedExitCode,
          ExitProtocol.failure,
          reason: 'the exit code contract is unchanged: 1 on findings',
        );
      },
    );
  });

  group('SPEC 1132 L2 — benchmark --json speaks verdict.v1', () {
    test(
      'benchmark list emits the canonical envelope (pass, exit 0)',
      () async {
        final out = await drive(['benchmark', 'list', '--json']);

        final envelope = VerdictEnvelope.tryParse(out);
        expect(
          envelope,
          isNotNull,
          reason:
              '`zfa benchmark list --json` must emit the canonical envelope '
              '(issue #1105 backlog emitter); the raw '
              '{"scenarios":[...]} document carries no schema at all.\n'
              'stdout:\n$out',
        );
        expect(envelope!.verdict, VerdictKind.pass);
        expect(envelope.exitClass, ExitProtocol.success);
        final scenarios = envelope.details['scenarios'];
        expect(
          scenarios,
          isA<List<dynamic>>(),
          reason:
              'the scenario registry rides in details.scenarios — the '
              'payload stays machine-readable under the canonical schema',
        );
        expect(
          (scenarios as List).isNotEmpty,
          isTrue,
          reason: 'the first-party scenario registry is never empty',
        );
        expect(
          CliRunner.lastDispatchedExitCode,
          ExitProtocol.success,
          reason: 'a successful list exits 0',
        );
      },
    );

    test('baseline compare emits the canonical envelope (pass)', () async {
      // Seed a baseline with a real save run (the string-utils-casing
      // scenario is pure Dart — fast, no Flutter, no network).
      final saveOut = await drive([
        'benchmark',
        'baseline',
        'save',
        'string-utils-casing',
        '--label',
        'fixture-base',
      ]);
      expect(
        saveOut.toLowerCase(),
        anyOf(contains('baseline'), contains('saved')),
        reason: 'the fixture save must succeed:\n$saveOut',
      );

      // A same-tree re-run jitters, so pin the comparison into the stable
      // band with a tolerance no real spread can exceed — otherwise this
      // test flakes into the `regressed` branch it is not pinning.
      final out = await drive([
        'benchmark',
        'baseline',
        'compare',
        'string-utils-casing',
        '--baseline',
        'fixture-base',
        '--tolerance',
        '1000000',
        '--json',
      ]);

      final envelope = VerdictEnvelope.tryParse(out);
      expect(
        envelope,
        isNotNull,
        reason:
            '`zfa benchmark baseline compare <id> --json` must emit the '
            'canonical envelope (issue #1105 backlog emitter).\n'
            'stdout:\n$out',
      );
      expect(envelope!.verdict, VerdictKind.pass);
      expect(envelope.exitClass, ExitProtocol.success);
      final comparison = envelope.details['comparison'];
      expect(
        comparison,
        isA<Map<String, dynamic>>(),
        reason: 'the comparison payload rides in details.comparison',
      );
      expect(
        (comparison as Map)['overallStatus'],
        equals('stable'),
        reason: 'the million-percent tolerance makes `stable` the only status',
      );
    });

    test('baseline compare emits the canonical envelope (regressed)', () async {
      // Seed a baseline whose single metric is impossibly fast, so the
      // real current run is a regression the envelope must report as
      // `fail` / exit_class 1 rather than prose.
      final store = JsonBaselineStore(
        directory: p.join(tmp.path, 'benchmarks', 'baselines'),
      );
      await store.save(
        Baseline(
          scenarioId: 'string-utils-casing',
          scenarioVersion: '1.0.0',
          label: 'regressed-base',
          metrics: const {'micros_elapsed': 1},
          timestamp: DateTime.now(),
        ),
      );

      final out = await drive([
        'benchmark',
        'baseline',
        'compare',
        'string-utils-casing',
        '--baseline',
        'regressed-base',
        '--json',
      ]);

      final envelope = VerdictEnvelope.tryParse(out);
      expect(
        envelope,
        isNotNull,
        reason:
            'a regressed comparison must still ship the canonical '
            'envelope.\nstdout:\n$out',
      );
      expect(envelope!.verdict, VerdictKind.fail);
      expect(envelope.exitClass, ExitProtocol.failure);
      final comparison = envelope.details['comparison'] as Map<String, dynamic>;
      expect(comparison['overallStatus'], equals('regressed'));
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.failure,
        reason: 'a regressed comparison exits 1',
      );
    });
  });

  group('SPEC 1132 L2 — capability pre-flight refusal speaks verdict.v1', () {
    test('missing required args emit the canonical usage envelope', () async {
      final out = await drive(['repository', 'method', '--json={}']);

      final envelope = VerdictEnvelope.tryParse(out);
      expect(
        envelope,
        isNotNull,
        reason:
            'the generic capability path\'s machine-mode refusal must emit '
            'the canonical envelope (issue #1105 backlog emitter); the old '
            '{"schema":1,"ok":false,...} shape is a foreign document to '
            'the canonical parser.\nstdout:\n$out',
      );
      expect(
        envelope!.verdict,
        VerdictKind.error,
        reason: 'the operation could NOT run as invoked',
      );
      expect(envelope.exitClass, ExitProtocol.usage);
      final missing = envelope.details['missing'];
      expect(
        missing,
        containsAll(['target', 'name']),
        reason: 'the missing arguments stay machine-readable in details',
      );
      expect(
        envelope.fix ?? envelope.findings.map((f) => f.fix).join(),
        contains('--target'),
        reason: 'the remediation names the missing flags',
      );
      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason: 'the exit class is unchanged: 2 for a usage refusal',
      );
    });

    test(
      'the old divergent shape breaks loudly, never parses silently',
      () async {
        // The guard the canonical parser ships with: a foreign schema is a
        // VerdictSchemaException, not a silent mis-parse.
        expect(
          () => VerdictEnvelope.fromJson(
            jsonDecode('{"schema":1,"ok":false}') as Map<String, dynamic>,
          ),
          throwsA(isA<VerdictSchemaException>()),
        );
      },
    );
  });
}
