// Issue #1112 — the `zfa skin drive` command: wraps package:vm_service
// against a live VM (flutter run / flutter test runner), evaluates the
// debugTapAnchorJson seam, and prints the TapResult JSON as the final
// stdout line — the same envelope on every host OS. Honest exit codes:
// found 0 / disabled 1 / notFound 2 / error 3.
library;

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/skin_command.dart';

Future<(String, int)> captureOutputAndExit(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return (output.join('\n'), exitCode);
}

CommandRunner<void> runner() =>
    CommandRunner<void>('zfa', 'test')..addCommand(SkinCommand());

void main() {
  group('issue #1112 — zfa skin drive (CLI surface)', () {
    setUp(() {
      exitCode = 0;
    });

    tearDown(() {
      exitCode = 0;
    });

    test('drive is registered as a skin subcommand', () {
      final skin = runner().commands['skin']!;
      expect(skin.subcommands.keys, contains('drive'));
    });

    test('--dart-uri and --anchor are required (honest arg errors)', () async {
      final (out, code) = await captureOutputAndExit(() async {
        await runner().run(['skin', 'drive']);
      });
      // Missing input is an honest failure (the route-verify
      // precedent): the fix line names the remedy, exit 3.
      expect(out, contains('missing --dart-uri'));
      expect(out, contains('--> fix:'));
      expect(code, 3);
    });

    test(
      'a refused connection prints the error JSON envelope (exit 3)',
      () async {
        // Port 1 on loopback refuses immediately — no VM service there.
        final (out, _) = await captureOutputAndExit(() async {
          await runner().run([
            'skin',
            'drive',
            '--dart-uri=http://127.0.0.1:1',
            '--anchor=zfa:signin-guest',
          ]);
        });
        final lastLine = out.trim().split('\n').last;
        final envelope = lastLine.trim();
        expect(envelope, contains('"result":"error"'));
        expect(envelope, contains('"tapped":false'));
        expect(exitCode, 3);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'a refused ws:// URI is equally honest (scheme passthrough)',
      () async {
        final (out, _) = await captureOutputAndExit(() async {
          await runner().run([
            'skin',
            'drive',
            '--dart-uri=ws://127.0.0.1:1/ws',
            '--anchor=signin-guest',
          ]);
        });
        final lastLine = out.trim().split('\n').last;
        expect(lastLine.trim(), contains('"result":"error"'));
        expect(exitCode, 3);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'exit codes map the TapResult vocabulary (found/disabled/notFound/error → 0/1/2/3)',
      () {
        // The contract is documented on the command itself so agents
        // can branch on it without parsing beyond the JSON.
        expect(SkinDriveCommand.exitCodeForLabel('found'), 0);
        expect(SkinDriveCommand.exitCodeForLabel('disabled'), 1);
        expect(SkinDriveCommand.exitCodeForLabel('notFound'), 2);
        expect(SkinDriveCommand.exitCodeForLabel('error'), 3);
      },
    );
  });
}
