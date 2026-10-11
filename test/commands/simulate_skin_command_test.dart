// Issue #1112 — `zfa simulate skin`: the scenario-worlds surface gets
// a skin-behavior driver. Behaviors run through the debugTapAnchor
// VM-service seam — NO synthetic clicks, deterministic across
// platforms. One JSON verdict line per behavior + a summary line, and
// the exit code is the most severe verdict on the SkinDriveExitCode
// ladder (found 0 < disabled 1 < notFound 2 < error 3).
//
// Grammar note (bug #856 lesson): registered parser-only via
// argParser.addCommand + manual dispatch, exactly like init/run/
// certify/verify-world, so the legacy flag surface stays reachable.
library;

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/simulate_command.dart';
import 'package:zuraffa/src/skin/tap_result.dart';

Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

/// The recorded drive plan: one verdict per anchor, in order.
class FakeDriver {
  FakeDriver(this.results);
  final Map<String, TapResult> results;
  final List<String> tapped = [];

  Future<TapResult> drive({
    required String dartUri,
    required String anchor,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration driveTimeout = const Duration(seconds: 20),
    void Function(String line)? log,
  }) async {
    tapped.add(anchor);
    return results[anchor] ?? const TapNotFound();
  }
}

void main() {
  Future<(String, int)> runSimulate(
    List<String> args, {
    FakeDriver? fake,
  }) async {
    exitCode = 0;
    final runner = CommandRunner<void>('zfa', 'test')
      ..addCommand(SimulateCommand(skinDriver: fake?.drive));
    final output = await captureOutput(() => runner.run(['simulate', ...args]));
    return (output, exitCode);
  }

  group('zfa simulate skin — behaviors through debugTapAnchor (#1112)', () {
    test(
      'drives every declared behavior in order, one JSON line each',
      () async {
        final fake = FakeDriver({
          'zfa:signin-guest': const TapFound(),
          'zfa:signin-logOut': const TapFound(),
        });
        final (output, code) = await runSimulate([
          'skin',
          '--dart-uri',
          'http://127.0.0.1:8181/token=/',
          '--behaviors',
          'zfa:signin-guest,zfa:signin-logOut',
        ], fake: fake);
        expect(code, 0, reason: output);
        expect(fake.tapped, ['zfa:signin-guest', 'zfa:signin-logOut']);
        expect(
          output,
          contains(
            '{"behavior":"zfa:signin-guest","result":"found","tapped":true}',
          ),
        );
        expect(
          output,
          contains(
            '{"behavior":"zfa:signin-logOut","result":"found","tapped":true}',
          ),
        );
        expect(
          output,
          contains(
            'simulate skin: behaviors=2 found=2 disabled=0 notFound=0 error=0',
          ),
        );
      },
    );

    test('the most severe verdict wins the exit code (ladder)', () async {
      final fake = FakeDriver({
        'zfa:signin-guest': const TapFound(),
        'zfa:signin-logOut': const TapDisabled(),
        'zfa:signin-missing': const TapNotFound(),
      });
      final (output, code) = await runSimulate([
        'skin',
        '--dart-uri',
        'http://127.0.0.1:8181/token=/',
        '--behaviors',
        'zfa:signin-guest,zfa:signin-logOut,zfa:signin-missing',
      ], fake: fake);
      expect(code, 2, reason: output);
      expect(output, contains('found=1 disabled=1 notFound=1 error=0'));
    });

    test('a driver failure is the most severe verdict (exit 3)', () async {
      final fake = FakeDriver({
        'zfa:signin-guest': const TapError('connection refused'),
      });
      final (output, code) = await runSimulate([
        'skin',
        '--dart-uri',
        'http://127.0.0.1:8181/token=/',
        '--behaviors',
        'zfa:signin-guest',
      ], fake: fake);
      expect(code, 3, reason: output);
      expect(output, contains('"message":"connection refused"'));
    });

    test('missing --behaviors → usage verdict with a fix line', () async {
      final (output, code) = await runSimulate([
        'skin',
        '--dart-uri',
        'http://127.0.0.1:8181/token=/',
      ]);
      expect(code, 3, reason: output);
      expect(output, contains('--> fix:'));
    });

    test(
      'the legacy flag surface still parses (no subcommand regression)',
      () async {
        // bug #856: adding real subcommands would make package:args
        // reject every flag-mode invocation with "Missing subcommand".
        // The `skin` verb must follow the parser-only registration too.
        final (output, code) = await runSimulate(['--verify-guard']);
        expect(output, isNot(contains('Missing subcommand')), reason: output);
        // The guard self-certifies honestly (0 green, 1 red) — it never
        // reaches the usage path above.
        expect(code, anyOf(0, 1), reason: output);
      },
    );
  });
}
