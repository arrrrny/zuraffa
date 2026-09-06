// SPEC 917 — machine-readable verdicts everywhere (issue #838):
//   * `--json` on every tdd/corpus command (the four laggard tdd verbs —
//     run-engine, split, status, theater — and the four top-level
//     `zfa corpus` subcommands — import, catalog, run, ledger — join the
//     26 verbs already emitting the verdict.v1 envelope);
//   * `zfa tdd run --stream` emits NDJSON per-step verdicts as they
//     happen (schema_versioned `step-verdict.v1`), the final envelope
//     still closing the output.
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../plugins/tdd/helpers/tdd_fixture.dart';

void main() {
  group('--json on the four laggard tdd verbs', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('zfa_917_json');
      await Directory(
        p.join(root.path, 'specs', '917-json-feature'),
      ).create(recursive: true);
    });

    tearDown(() {
      root.delete(recursive: true);
      exitCode = 0;
    });

    Future<(int, String)> run(List<String> args) async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(args);
      return (CliRunner.lastDispatchedExitCode, out);
    }

    Map<String, dynamic>? lastJsonLine(String out) {
      for (final line in out.trim().split('\n').reversed) {
        if (line.trim().isEmpty) continue;
        if (!line.startsWith('{')) return null;
        return jsonDecode(line) as Map<String, dynamic>;
      }
      return null;
    }

    test('tdd run-engine --json closes with a verdict.v1 envelope', () async {
      final (code, out) = await run([
        'tdd',
        'run-engine',
        '917-json-feature',
        '--project',
        root.path,
        '--json',
      ]);
      expect(code, isNot(0), reason: out); // empty feature: honest failure
      final envelope = lastJsonLine(out);
      expect(envelope, isNotNull, reason: out);
      expect(envelope!['schema'], 'verdict.v1');
      expect(envelope['command'], 'run-engine');
      expect(envelope['verdict'], isNot('pass'));
      // Errors are an API: a failing envelope carries the fix.
      expect(envelope['fix'], isNotNull, reason: out);
    });

    test('tdd status --json closes with a verdict.v1 envelope', () async {
      final (code, out) = await run([
        'tdd',
        'status',
        '917-json-feature',
        '--project',
        root.path,
        '--json',
      ]);
      expect(code, 1, reason: out); // both lanes absent → not green
      final envelope = lastJsonLine(out);
      expect(envelope, isNotNull, reason: out);
      expect(envelope!['schema'], 'verdict.v1');
      expect(envelope['command'], 'status');
      expect(envelope['verdict'], 'fail');
      expect(envelope['details']['engine'], 'absent');
      expect(envelope['details']['skin'], 'absent');
    });

    test(
      'tdd status --json honors the green lane (verdict pass, exit 0)',
      () async {
        // Seed green engine+skin receipts: the JSON verdict must agree with
        // the text verdict (and exit 0).
        final featureDir = p.join(root.path, 'specs', '917-json-feature');
        final receiptsDir = Directory(p.join(featureDir, 'tdd'))
          ..createSync(recursive: true);
        File(
          p.join(receiptsDir.path, '04-engine-receipt.json'),
        ).writeAsStringSync(jsonEncode({'verdict': 'green'}));
        File(
          p.join(receiptsDir.path, '04-skin-receipt.json'),
        ).writeAsStringSync(jsonEncode({'verdict': 'green'}));

        final (code, out) = await run([
          'tdd',
          'status',
          '917-json-feature',
          '--project',
          root.path,
          '--json',
        ]);
        expect(code, 0, reason: out);
        final envelope = lastJsonLine(out);
        expect(envelope!['verdict'], 'pass', reason: out);
      },
    );

    test('tdd split --json closes with a verdict.v1 envelope', () async {
      final (code, out) = await run(['tdd', 'split', '--json']);
      // A split invocation without input refuses — but in JSON mode the
      // refusal still ends with the envelope (errors are an API).
      expect(code, isNot(0), reason: out);
      final envelope = lastJsonLine(out);
      expect(envelope, isNotNull, reason: out);
      expect(envelope!['schema'], 'verdict.v1');
      expect(envelope['command'], 'split');
    });

    test('tdd theater --json closes with a verdict.v1 envelope', () async {
      final (code, out) = await run(['tdd', 'theater', '--json']);
      expect(code, isNot(0), reason: out);
      final envelope = lastJsonLine(out);
      expect(envelope, isNotNull, reason: out);
      expect(envelope!['schema'], 'verdict.v1');
      expect(envelope['command'], 'theater');
    });
  });

  group('--json on the top-level zfa corpus subcommands', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('zfa_917_corpus');
    });

    tearDown(() {
      root.delete(recursive: true);
      exitCode = 0;
    });

    Future<(int, String)> run(List<String> args) async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(args);
      return (CliRunner.lastDispatchedExitCode, out);
    }

    Map<String, dynamic>? lastJsonLine(String out) {
      for (final line in out.trim().split('\n').reversed) {
        if (line.trim().isEmpty) continue;
        if (!line.startsWith('{')) return null;
        return jsonDecode(line) as Map<String, dynamic>;
      }
      return null;
    }

    test('corpus catalog --json closes with a verdict.v1 envelope', () async {
      final (code, out) = await run([
        'corpus',
        'catalog',
        '--target',
        p.join(root.path, 'no-such-target'),
        '--json',
      ]);
      expect(code, isNot(0), reason: out);
      final envelope = lastJsonLine(out);
      expect(envelope, isNotNull, reason: out);
      expect(envelope!['schema'], 'verdict.v1');
      expect(envelope['command'], 'corpus catalog');
      expect(envelope['fix'], isNotNull, reason: out);
    });

    test('corpus run --json closes with a verdict.v1 envelope', () async {
      final (code, out) = await run([
        'corpus',
        'run',
        '--target',
        p.join(root.path, 'no-such-target'),
        '--json',
      ]);
      expect(code, isNot(0), reason: out);
      final envelope = lastJsonLine(out);
      expect(envelope, isNotNull, reason: out);
      expect(envelope!['schema'], 'verdict.v1');
      expect(envelope['command'], 'corpus run');
    });

    test('corpus ledger --json closes with a verdict.v1 envelope', () async {
      final (code, out) = await run([
        'corpus',
        'ledger',
        '--target',
        p.join(root.path, 'no-such-target'),
        '--json',
      ]);
      expect(code, isNot(0), reason: out);
      final envelope = lastJsonLine(out);
      expect(envelope, isNotNull, reason: out);
      expect(envelope!['schema'], 'verdict.v1');
      expect(envelope['command'], 'corpus ledger');
    });

    test('corpus import --json closes with a verdict.v1 envelope', () async {
      final (code, out) = await run(['corpus', 'import', '--json']);
      // Missing <source> is a usage refusal — enveloped in JSON mode.
      expect(code, isNot(0), reason: out);
      final envelope = lastJsonLine(out);
      expect(envelope, isNotNull, reason: out);
      expect(envelope!['schema'], 'verdict.v1');
      expect(envelope['command'], 'corpus import');
    });
  });

  group('tdd run --stream — NDJSON per-step verdicts', () {
    late TddFixture fx;
    const feature = '091-run-stream';

    Future<String> drive({List<String> extraArgs = const []}) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
        ...extraArgs,
      ]);
    }

    setUp(() async {
      fx = await TddFixture.create(featureName: feature);
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'streamed behavior one',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-002',
          description: 'streamed behavior two',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test(
      'every completed step emits one schema_versioned NDJSON verdict',
      () async {
        final out = await drive(extraArgs: const ['--stream']);
        expect(exitCode, 0, reason: out);

        final lines = out
            .trim()
            .split('\n')
            .where((l) => l.startsWith('{'))
            .map((l) => jsonDecode(l) as Map<String, dynamic>)
            .toList();

        final stepEvents = lines
            .where((j) => j['schema_version'] == 'step-verdict.v1')
            .toList();
        // 2 behaviors × 4 loop steps, streamed as they happened.
        expect(stepEvents.length, 8, reason: out);
        expect(stepEvents.map((e) => '${e['behavior']}:${e['step']}').toSet(), {
          'B-001:gen',
          'B-001:verify-red',
          'B-001:make',
          'B-001:refactor',
          'B-002:gen',
          'B-002:verify-red',
          'B-002:make',
          'B-002:refactor',
        });
        for (final event in stepEvents) {
          expect(event['command'], 'run');
          expect(event['feature'], feature);
          expect(event['outcome'], isA<String>());
          expect(event['exit_code'], 0);
          expect(event['timestamp'], isA<String>());
        }
        // The order is streaming order: B-001's steps before B-002's.
        final behaviorOrder = stepEvents
            .map((e) => e['behavior'] as String)
            .toSet()
            .toList();
        expect(behaviorOrder, ['B-001', 'B-002']);
        // The final envelope still closes the output.
        final last = lines.last;
        expect(last['schema'], 'verdict.v1');
      },
    );

    test(
      'without --stream no step events appear (legacy output intact)',
      () async {
        final out = await drive();
        expect(exitCode, 0, reason: out);
        expect(out, isNot(contains('step-verdict.v1')));
      },
    );

    test(
      '--stream composes with --json: steps stream, envelope closes',
      () async {
        final out = await drive(extraArgs: const ['--stream', '--json']);
        expect(exitCode, 0, reason: out);
        final lines = out
            .trim()
            .split('\n')
            .where((l) => l.startsWith('{'))
            .map((l) => jsonDecode(l) as Map<String, dynamic>)
            .toList();
        final stepCount = lines
            .where((j) => j['schema_version'] == 'step-verdict.v1')
            .length;
        expect(stepCount, 8, reason: out);
        expect(lines.last['schema'], 'verdict.v1');
        expect(lines.last['command'], 'run');
      },
    );
  });
}
