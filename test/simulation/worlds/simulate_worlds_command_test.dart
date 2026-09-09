/// Spec 968 — `zfa simulate init/run/certify/verify-world` (A1–A10): the
/// scenario-worlds command surface, end to end.
///
/// Also pins the dispatch contract: the spec-968 subcommands coexist
/// with the #832 legacy flag surface (`--scaffold`, `--feature`,
/// `--verify-guard`, ...) — package:args rejects flag-mode invocation
/// when subcommands are registered through `addSubcommand` (the bug
/// #856 / spec #975 grammar lesson), so the subcommands parse through
/// `argParser.addCommand` only and `run()` dispatches manually.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/simulation/worlds/world_manifest.dart';

Future<(int, String)> runZfa(List<String> args) async {
  final runner = CliRunner(exitOnCompletion: false);
  final output = await runner.runCapturing(args);
  return (exitCode, output);
}

const _feature = '058-demo-world-feature';

Future<Directory> _workspace() =>
    Directory.systemTemp.createTemp('zfa-simulate-worlds');

String _dependencyTable(String feature) =>
    '''
# Test List: $feature

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1 |
| RestSync | service | push(batch) -> SyncResult, pull(cursor) -> Page | P1 |

## Routing provenance
''';

Future<void> _writeDependencyTable(Directory ws) => _seedFeature(ws, _feature);

/// Seeds `specs/<feature>/tdd/test-list.md` with a declared dependency
/// table (the #960 output `simulate init` composes).
Future<void> _seedFeature(Directory ws, String feature) async {
  final featureDir = Directory('${ws.path}/specs/$feature/tdd')
    ..createSync(recursive: true);
  File(
    '${featureDir.path}/test-list.md',
  ).writeAsStringSync(_dependencyTable(feature));
}

Map<String, dynamic> _readManifest(Directory ws) =>
    jsonDecode(
          File(
            '${ws.path}/specs/$_feature/tdd/worlds/checkout-flow.world.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  late Directory ws;

  setUp(() async {
    ws = await _workspace();
    await _writeDependencyTable(ws);
  });

  tearDown(() async {
    await ws.delete(recursive: true);
  });

  group('registration + dispatch contract', () {
    test('zfa simulate --help documents the legacy surface AND the '
        'spec-968 subcommands', () async {
      final (code, output) = await runZfa(['simulate', '--help']);
      expect(code, 0);
      expect(output, contains('scaffold'));
      expect(output, contains('scenario'));
      expect(output, contains('family'));
      expect(output, contains('init'));
      expect(output, contains('verify-world'));
    });

    test('the #832 legacy flag surface still works beside the '
        'subcommands (bug #856 lesson)', () async {
      final featureDir = '${ws.path}/specs/legacy-feature';
      final (code, output) = await runZfa([
        'simulate',
        '--scaffold',
        featureDir,
        '--family',
        'firebase-auth',
      ]);
      expect(code, 0, reason: output);
      expect(
        File('$featureDir/tdd/fixtures/auth-world.json').existsSync(),
        isTrue,
      );
    });

    test('zfa simulate --verify-guard still self-certifies', () async {
      final (code, output) = await runZfa(['simulate', '--verify-guard']);
      expect(code, 0, reason: output);
      expect(output, contains('guard ok'));
    });

    test('subcommand invocation without a scenario is a usage error', () async {
      final (code, output) = await runZfa([
        'simulate',
        'init',
        '--project',
        ws.path,
        '--feature',
        _feature,
      ]);
      // SPEC 917: the canonical usage code — the legacy 64 is retired.
      expect(code, 2, reason: output);
      expect(output, contains('Usage: zfa simulate init'));
    });
  });

  group('A1: simulate init scaffolds the world from the declared table', () {
    test(
      'writes a committed, diffable manifest with both touchpoints',
      () async {
        final (code, output) = await runZfa([
          'simulate',
          'init',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        expect(code, 0, reason: output);
        expect(output, contains('SIMULATE init -> GREEN'));
        expect(output, contains('touchpoints=2'));
        expect(output, contains(RegExp(r'world-hash=[0-9a-f]{12}')));

        final manifest = _readManifest(ws);
        expect(manifest['schema'], 1);
        expect(manifest['scenario'], 'checkout-flow');
        expect(manifest['feature'], _feature);
        expect((manifest['time'] as Map)['seed'], 968);
        final touchpoints = (manifest['touchpoints'] as List)
            .cast<Map<String, dynamic>>();
        expect(touchpoints.map((t) => t['name']), ['FirebaseAuth', 'RestSync']);
        expect(
          (touchpoints.first['methods'] as List)
              .cast<Map<String, dynamic>>()
              .map((m) => m['name']),
          ['signIn', 'signOut'],
        );
        expect(
          (touchpoints.last['methods'] as List)
              .cast<Map<String, dynamic>>()
              .map((m) => m['name']),
          ['push', 'pull'],
        );

        // The default failure-storm schedule: auth expiry + flap +
        // partial-write for the declared shapes.
        final storms =
            ((manifest['failureSchedule'] as Map<String, dynamic>)['storms']
                    as List)
                .cast<Map<String, dynamic>>();
        expect(
          storms.map((s) => s['kind']).toSet(),
          containsAll(['auth-expiry', 'network-flap', 'partial-write']),
        );

        // Latency bands per touchpoint.
        expect(
          (manifest['latency'] as Map).keys,
          containsAll(['FirebaseAuth', 'RestSync']),
        );
      },
    );

    test(
      'scaffolding is deterministic (byte-identical across worlds)',
      () async {
        final (a, _) = await runZfa([
          'simulate',
          'init',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        expect(a, 0);
        final first = File(
          '${ws.path}/specs/$_feature/tdd/worlds/checkout-flow.world.json',
        ).readAsStringSync();

        final ws2 = await _workspace();
        addTearDown(() => ws2.delete(recursive: true));
        await _writeDependencyTable(ws2);
        final (b, _) = await runZfa([
          'simulate',
          'init',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws2.path,
        ]);
        expect(b, 0);
        final second = File(
          '${ws2.path}/specs/$_feature/tdd/worlds/checkout-flow.world.json',
        ).readAsStringSync();
        expect(
          second,
          first,
          reason: 'same declared table + seed → byte-identical world',
        );
      },
    );

    test('A3: refuses honestly without a declared dependency table', () async {
      // A feature with a test-list that has no dependency section.
      final bareFeature = '020-bare-feature';
      Directory(
        '${ws.path}/specs/$bareFeature/tdd',
      ).createSync(recursive: true);
      File(
        '${ws.path}/specs/$bareFeature/tdd/test-list.md',
      ).writeAsStringSync('# Test List: $bareFeature\n\nnothing\n');

      final (code, output) = await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        bareFeature,
        '--project',
        ws.path,
      ]);
      expect(code, 1, reason: output);
      expect(output, contains('no external dependencies'));
      expect(output, contains('zfa tdd plan'));
      expect(
        File('${ws.path}/specs/$bareFeature/tdd/worlds').existsSync(),
        isFalse,
        reason:
            'no empty world committed — a world without touchpoints '
            'is a silent pass',
      );
    });

    test('refuses to re-scaffold an existing world without --force', () async {
      await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      final (code, output) = await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      expect(code, 1, reason: output);
      expect(output, contains('world already exists'));

      final (forceCode, _) = await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
        '--force',
      ]);
      expect(forceCode, 0);
    });
  });

  group('A2: init certifies the world (never self-graded)', () {
    test('the certification receipt records every method satisfied + '
        'the world hash; cycle-log evidence is appended', () async {
      final (code, output) = await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      expect(code, 0, reason: output);

      final certFile = File(
        '${ws.path}/specs/$_feature/tdd/worlds/checkout-flow.cert.json',
      );
      expect(certFile.existsSync(), isTrue);
      final cert =
          jsonDecode(certFile.readAsStringSync()) as Map<String, dynamic>;
      expect(cert['certified'], isTrue);
      // The receipt binds the EXACT manifest: recompute the world hash
      // from the committed bytes.
      final parsed = WorldManifest.parse(
        File(
          '${ws.path}/specs/$_feature/tdd/worlds/checkout-flow.world.json',
        ).readAsBytesSync(),
      );
      expect(cert['world_hash'], parsed.worldHash);
      final methods = (cert['methods'] as List).cast<Map<String, dynamic>>();
      expect(methods, hasLength(4));
      expect(
        methods.every((m) => m['satisfied'] == true),
        isTrue,
        reason: methods.where((m) => m['satisfied'] != true).toString(),
      );
      expect(
        methods.firstWhere((m) => m['method'] == 'signIn')['evidence'],
        contains('certified FirebaseAuthAdapter'),
      );

      // Cycle-log evidence: hash-chained world-cert entry.
      final cycleLog = File('${ws.path}/specs/$_feature/tdd/cycle-log.md');
      expect(cycleLog.existsSync(), isTrue);
      final log = cycleLog.readAsStringSync();
      expect(log, contains('- kind: world-cert'));
      expect(log, contains('- behavior: $_feature-world-checkout-flow'));
      expect(log, contains(RegExp(r'- hash: [0-9a-f]{64}')));
      expect(log, contains('- schema: 1'));
    });
  });

  group('A4: simulate run executes the scenario and writes the receipt', () {
    test('GREEN run names the world hash; storms fire; virtual time '
        'elapses without wall time', () async {
      await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);

      final (code, output) = await runZfa([
        'simulate',
        'run',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      expect(code, 0, reason: output);
      expect(output, contains('simulate-run: scenario=checkout-flow'));
      expect(output, contains('verdict=GREEN'));
      expect(output, contains(RegExp(r'world-hash=[0-9a-f]{12}')));
      expect(
        output,
        contains(RegExp(r'virtual-ms=[1-9][0-9]*')),
        reason: 'the run consumed virtual time (latency + backoff)',
      );

      final receiptFile = File(
        '${ws.path}/.zfa/receipts/world-run-checkout-flow.json',
      );
      expect(receiptFile.existsSync(), isTrue);
      final receipt =
          jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
      // The manifest's own world hash (recomputed at parse) — parse the
      // doc and recompute through the model:
      final parsedWorld = WorldManifest.parse(
        File(
          '${ws.path}/specs/$_feature/tdd/worlds/checkout-flow.world.json',
        ).readAsBytesSync(),
      );
      expect(receipt['world_hash'], parsedWorld.worldHash);
      expect(receipt['verdict'], 'GREEN');
      expect(receipt['world_valid'], isTrue);
      expect((receipt['world_hash'] as String), hasLength(64));
      expect(receipt['plays'] as int, greaterThan(0));
      expect(receipt['virtual_elapsed_ms'] as int, greaterThan(0));
      expect(receipt['schema'], 'proof.v1');

      // The differential report (#915) is committed.
      final report = File(
        '${ws.path}/specs/$_feature/tdd/world-differential-report.json',
      );
      expect(report.existsSync(), isTrue);
      final diff =
          jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;
      expect(diff['verdict'], 'pass');
      expect(diff['drift'], 0);
      expect(
        diff['storm_proof'],
        greaterThanOrEqualTo(1),
        reason: 'the auth-expiry storm was rehearsed',
      );

      // Cycle-log: the world-run evidence entry.
      final log = File(
        '${ws.path}/specs/$_feature/tdd/cycle-log.md',
      ).readAsStringSync();
      expect(log, contains('- kind: world-run'));
      expect(log, contains('- differential: pass'));
    });

    test(
      'the run is deterministic: two runs produce the same digest',
      () async {
        await runZfa([
          'simulate',
          'init',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        await runZfa([
          'simulate',
          'run',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        final first =
            jsonDecode(
                  File(
                    '${ws.path}/.zfa/receipts/world-run-checkout-flow.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;

        await runZfa([
          'simulate',
          'run',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        final second =
            jsonDecode(
                  File(
                    '${ws.path}/.zfa/receipts/world-run-checkout-flow.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;

        expect(second['run_digest'], first['run_digest']);
        expect(second['world_hash'], first['world_hash']);
      },
    );
  });

  group('A5: a mutated world invalidates the green receipt', () {
    test(
      're-running after mutation refuses and no stale green survives',
      () async {
        await runZfa([
          'simulate',
          'init',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        await runZfa([
          'simulate',
          'run',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        final green =
            jsonDecode(
                  File(
                    '${ws.path}/.zfa/receipts/world-run-checkout-flow.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(green['verdict'], 'GREEN');

        // Mutate the world (the corpus drifts).
        final manifestPath =
            '${ws.path}/specs/$_feature/tdd/worlds/checkout-flow.world.json';
        final manifest = _readManifest(ws);
        final corpus = manifest['corpus'] as Map<String, dynamic>;
        final restSync = corpus['RestSync'] as Map<String, dynamic>;
        final push = restSync['push'] as Map<String, dynamic>;
        (push['fixture'] as Map<String, dynamic>)['count'] = 999;
        File(manifestPath).writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
        );

        // The certification receipt no longer matches the mutated world.
        final (code, output) = await runZfa([
          'simulate',
          'run',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        expect(code, 1, reason: output);
        expect(
          output,
          anyOf(
            contains('world certification is missing, red, or stale'),
            contains('mutated since the green receipt'),
          ),
        );
        expect(output, contains('--> fix: re-certify'));

        // The stale green never survives: the mutation path invalidates
        // the receipt when the cert still matches but the run receipt
        // doesn't (both paths leave no lying GREEN).
        final receiptNow =
            jsonDecode(
                  File(
                    '${ws.path}/.zfa/receipts/world-run-checkout-flow.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(receiptNow['verdict'], isNot('GREEN'));

        // Recovery is the honest path: re-certify, then green again.
        final (certifyCode, certifyOut) = await runZfa([
          'simulate',
          'certify',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        expect(certifyCode, 0, reason: certifyOut);
        expect(certifyOut, contains('simulate-certify:'));

        final (runCode, runOut) = await runZfa([
          'simulate',
          'run',
          'checkout-flow',
          '--feature',
          _feature,
          '--project',
          ws.path,
        ]);
        expect(runCode, 0, reason: runOut);
        final newReceipt =
            jsonDecode(
                  File(
                    '${ws.path}/.zfa/receipts/world-run-checkout-flow.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(newReceipt['verdict'], 'GREEN');
        expect(
          newReceipt['world_hash'],
          isNot(green['world_hash']),
          reason: 'the new green is attributable to the mutated world',
        );
      },
    );

    test('a mutated world with a fresh re-certification invalidates the '
        'old green, then greens against the new hash', () async {
      await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      await runZfa([
        'simulate',
        'run',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      final oldGreen =
          jsonDecode(
                File(
                  '${ws.path}/.zfa/receipts/world-run-checkout-flow.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(oldGreen['verdict'], 'GREEN');

      // Mutate + re-certify (cert matches the mutated world), so the
      // re-run takes the receipt-invalidation path and proceeds to a
      // fresh green attributable to the mutated world.
      final manifestPath =
          '${ws.path}/specs/$_feature/tdd/worlds/checkout-flow.world.json';
      final manifest = _readManifest(ws);
      final restSync = (manifest['corpus'] as Map)['RestSync'] as Map;
      ((restSync['push'] as Map)['fixture'] as Map)['count'] = 4242;
      File(manifestPath).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
      );
      await runZfa([
        'simulate',
        'certify',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);

      final (code, output) = await runZfa([
        'simulate',
        'run',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      expect(code, 0, reason: output);
      expect(output, contains('world mutated since the green receipt'));
      expect(output, contains('INVALIDATED'));
      expect(output, contains('verdict=GREEN'));

      // The new receipt is a fresh green naming the MUTATED world —
      // the old hash's green never survives anywhere.
      final receipt =
          jsonDecode(
                File(
                  '${ws.path}/.zfa/receipts/world-run-checkout-flow.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(receipt['verdict'], 'GREEN');
      expect(receipt['world_valid'], isTrue);
      expect(receipt['world_hash'], isNot(oldGreen['world_hash']));
    });
  });

  group('A6: --replay proves deterministic re-execution', () {
    test('the digest matches the recorded receipt', () async {
      await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      await runZfa([
        'simulate',
        'run',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);

      final (code, output) = await runZfa([
        'simulate',
        'run',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
        '--replay',
      ]);
      expect(code, 0, reason: output);
      expect(output, contains('replay: deterministic (digest match)'));
    });
  });

  group('A10: verify-world is the CI gate', () {
    test('the green triple agrees → exit 0', () async {
      await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      await runZfa([
        'simulate',
        'run',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);

      final (code, output) = await runZfa([
        'simulate',
        'verify-world',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      expect(code, 0, reason: output);
      expect(output, contains('verify-world: scenario=checkout-flow'));
      expect(output, contains('verdict=GREEN'));
      expect(output, contains('run-receipt=green'));
    });

    test('drift (mutated manifest) → exit 1 naming the delta', () async {
      await runZfa([
        'simulate',
        'init',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      await runZfa([
        'simulate',
        'run',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);

      final manifestPath =
          '${ws.path}/specs/$_feature/tdd/worlds/checkout-flow.world.json';
      final manifest = _readManifest(ws);
      final restSync = (manifest['corpus'] as Map)['RestSync'] as Map;
      ((restSync['push'] as Map)['fixture'] as Map)['count'] = 1;
      File(manifestPath).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
      );

      final (code, output) = await runZfa([
        'simulate',
        'verify-world',
        'checkout-flow',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      expect(code, 1, reason: output);
      expect(output, contains('mutated since certification'));
    });

    test('an unknown scenario refuses with the init fix hint', () async {
      final (code, output) = await runZfa([
        'simulate',
        'verify-world',
        'ghost',
        '--feature',
        _feature,
        '--project',
        ws.path,
      ]);
      // SPEC 917: the unknown scenario refuses with the canonical usage
      // code (the legacy 64 is retired).
      expect(code, 2, reason: output);
      expect(output, contains('no world manifest'));
      expect(output, contains('zfa simulate init ghost'));
    });
  });

  group(
    'issue #1354: pinned feature resolution (bare positional invocation)',
    () {
      /// Pins `.specify/feature.json` in the workspace to [featureDirectory].
      void writePin(Directory scope, String featureDirectory) {
        Directory('${scope.path}/.specify').createSync(recursive: true);
        File(
          '${scope.path}/.specify/feature.json',
        ).writeAsStringSync('{"feature_directory":"$featureDirectory"}\n');
      }

      test('B1: bare init scaffolds the world under the pinned feature '
          '(the issue #1354 repro)', () async {
        writePin(ws, 'specs/$_feature');
        final (code, output) = await runZfa([
          'simulate',
          'init',
          'test_world',
          '--project',
          ws.path,
        ]);
        expect(code, 0, reason: output);
        expect(output, contains('SIMULATE init -> GREEN'));
        expect(output, contains('feature=$_feature'));

        final manifestPath =
            '${ws.path}/specs/$_feature/tdd/worlds/test_world.world.json';
        expect(File(manifestPath).existsSync(), isTrue, reason: output);

        // Same outcome as the explicit twin: byte-identical manifest from
        // the same declared table + seed.
        final ws2 = await _workspace();
        addTearDown(() => ws2.delete(recursive: true));
        await _writeDependencyTable(ws2);
        final (twinCode, twinOutput) = await runZfa([
          'simulate',
          'init',
          'test_world',
          '--feature',
          _feature,
          '--project',
          ws2.path,
        ]);
        expect(twinCode, 0, reason: twinOutput);
        expect(
          File(manifestPath).readAsStringSync(),
          File(
            '${ws2.path}/specs/$_feature/tdd/worlds/test_world.world.json',
          ).readAsStringSync(),
          reason: 'bare invocation == explicit --feature invocation',
        );
      });

      test('B2: an explicit --feature beats the pin', () async {
        const other = '070-other-world-feature';
        await _seedFeature(ws, other);
        writePin(ws, 'specs/$_feature');
        final (code, output) = await runZfa([
          'simulate',
          'init',
          'test_world',
          '--feature',
          other,
          '--project',
          ws.path,
        ]);
        expect(code, 0, reason: output);
        expect(output, contains('feature=$other'));
        expect(
          File(
            '${ws.path}/specs/$other/tdd/worlds/test_world.world.json',
          ).existsSync(),
          isTrue,
          reason: output,
        );
        expect(
          Directory('${ws.path}/specs/$_feature/tdd/worlds').existsSync(),
          isFalse,
          reason: 'the pinned feature must stay untouched',
        );
      });

      test(
        'B3: no flag + no pin refuses honestly naming both inputs',
        () async {
          final (code, output) = await runZfa([
            'simulate',
            'init',
            'test_world',
            '--project',
            ws.path,
          ]);
          expect(code, 2, reason: output);
          expect(output, contains('--feature'));
          expect(
            output,
            contains('feature.json'),
            reason: 'the error names the pin as the missing resolution step',
          );
          expect(
            output,
            isNot(contains('ignored')),
            reason: 'the positional scenario parses; only resolution failed',
          );
          expect(
            Directory('${ws.path}/specs/$_feature/tdd/worlds').existsSync(),
            isFalse,
          );
        },
      );

      test(
        'B4: a pin to a missing directory refuses naming the path',
        () async {
          writePin(ws, 'specs/1354-does-not-exist');
          final (code, output) = await runZfa([
            'simulate',
            'init',
            'test_world',
            '--project',
            ws.path,
          ]);
          expect(code, 2, reason: output);
          expect(output, contains('1354-does-not-exist'));
          expect(
            Directory('${ws.path}/specs/$_feature/tdd/worlds').existsSync(),
            isFalse,
            reason: 'never a silent fallback to another feature',
          );
        },
      );

      test('B5: bare run/certify/verify-world resolve the pin like their '
          'explicit twins', () async {
        writePin(ws, 'specs/$_feature');
        final init = await runZfa([
          'simulate',
          'init',
          'test_world',
          '--project',
          ws.path,
        ]);
        expect(init.$1, 0, reason: init.$2);

        final run = await runZfa([
          'simulate',
          'run',
          'test_world',
          '--project',
          ws.path,
        ]);
        expect(run.$1, 0, reason: run.$2);
        expect(run.$2, contains('simulate-run: scenario=test_world'));

        final certify = await runZfa([
          'simulate',
          'certify',
          'test_world',
          '--project',
          ws.path,
        ]);
        expect(certify.$1, 0, reason: certify.$2);
        expect(certify.$2, contains('simulate-certify: scenario=test_world'));

        final verify = await runZfa([
          'simulate',
          'verify-world',
          'test_world',
          '--project',
          ws.path,
        ]);
        expect(verify.$1, 0, reason: verify.$2);
        expect(verify.$2, contains('verdict=GREEN'));
        expect(verify.$2, contains('run-receipt=green'));
      });

      test(
        'B6: the parent-level --feature keeps winning over the pin',
        () async {
          const other = '070-other-world-feature';
          await _seedFeature(ws, other);
          writePin(ws, 'specs/$other');
          final (code, output) = await runZfa([
            'simulate',
            '--feature',
            _feature,
            'init',
            'test_world',
            '--project',
            ws.path,
          ]);
          expect(code, 0, reason: output);
          expect(output, contains('feature=$_feature'));
          expect(
            File(
              '${ws.path}/specs/$_feature/tdd/worlds/test_world.world.json',
            ).existsSync(),
            isTrue,
            reason: output,
          );
        },
      );

      test('B7: a malformed pin refuses honestly (never crashes)', () async {
        Directory('${ws.path}/.specify').createSync(recursive: true);
        File(
          '${ws.path}/.specify/feature.json',
        ).writeAsStringSync('not json {{{');
        final (code, output) = await runZfa([
          'simulate',
          'init',
          'test_world',
          '--project',
          ws.path,
        ]);
        expect(code, 2, reason: output);
        expect(
          output,
          contains('malformed'),
          reason: 'an unreadable pin is named, not silently ignored',
        );
        expect(
          Directory('${ws.path}/specs/$_feature/tdd/worlds').existsSync(),
          isFalse,
        );
      });

      test(
        'B8: the subcommand help documents the pinned-feature default',
        () async {
          final (code, output) = await runZfa(['simulate', 'init', '--help']);
          expect(code, 0, reason: output);
          expect(output, contains('pinned'));
        },
      );
    },
  );
}
