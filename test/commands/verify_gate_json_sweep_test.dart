import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// SPEC 1106 — the test-of-completeness for the #1104 envelope audit:
/// EVERY verify-gate command in the codebase must ship `--json`.
///
/// Two complementary assertions:
///
/// 1. **The greppable assertion** — a filesystem sweep over the command
///    surfaces (`lib/src/commands/`, `lib/src/plugins/*/commands/`): every
///    file that implements a verify-gate command must reference the `json`
///    flag. If a future verify gate is added without `--json`, this test
///    fails on the exact file — no audit-by-memory.
///
/// 2. **Live spot-checks** for the two gates this spec repaired: the flag
///    must be USABLE (bare `--json`, no value), and the run must end with
///    the canonical `verdict.v1` envelope as the last stdout line.
void main() {
  group('SPEC 1106 sweep — every verify-gate command file ships --json', () {
    const commandDirs = ['lib/src/commands', 'lib/src/plugins/tdd/commands'];

    /// The parity gate lives in a file not named `verify` (#1103) — it is
    /// pinned explicitly so the sweep cannot miss it.
    const explicitGates = {'datasource_check_command.dart'};

    /// The known verify-gate files at the time of SPEC 1106. The discovery
    /// regex must keep finding every one of them — if one is renamed or
    /// moved, update it here AND keep its `--json` flag.
    const knownGates = {
      'di_verify_command.dart',
      'datasource_check_command.dart',
      'route_verify_command.dart',
      'cache_verify_command.dart',
      'provider_verify_command.dart',
      'verify_command.dart',
      'verify_red_command.dart',
    };

    Set<String> discoverVerifyGateFiles() {
      final found = <String>{};
      for (final dirPath in commandDirs) {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final base = entity.uri.pathSegments.last;
          if (base.contains('verify') || explicitGates.contains(base)) {
            found.add(base);
          }
        }
      }
      return found;
    }

    test('discovery finds the known verify-gate files', () {
      final discovered = discoverVerifyGateFiles();
      expect(discovered, isNotEmpty);
      final missing = knownGates.difference(discovered);
      expect(
        missing,
        isEmpty,
        reason:
            'verify-gate file(s) $missing are no longer discoverable by the '
            'sweep — move them back under a *verify* command file name or '
            'update the sweep inventory',
      );
    });

    test('every discovered verify-gate file references the json flag', () {
      for (final dirPath in commandDirs) {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final base = entity.uri.pathSegments.last;
          if (!base.contains('verify') && !explicitGates.contains(base)) {
            continue;
          }
          final content = entity.readAsStringSync();
          expect(
            content,
            contains("'json'"),
            reason:
                '$dirPath/$base implements a verify-gate command but does '
                'not ship the --json machine-verdict flag (SPEC 1106 / '
                'issue #1106: every verify-gate command emits --json)',
          );
        }
      }
    });
  });

  group(
    'SPEC 1106 live spot-checks — the repaired gates accept bare --json',
    () {
      late Directory tmp;

      setUp(() {
        tmp = Directory.systemTemp.createTempSync('spec1106_sweep_');
      });

      tearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      Map<String, Object?> decodeLastLine(String out) {
        final lines = out.trimRight().split('\n');
        final last = lines.isEmpty ? '' : lines.last;
        final decoded = jsonDecode(last);
        expect(
          decoded,
          isA<Map<String, Object?>>(),
          reason: 'last stdout line must be the verdict envelope: $last',
        );
        return decoded as Map<String, Object?>;
      }

      test('zfa di verify --json ends with the canonical envelope', () async {
        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(['-C', tmp.path, 'di', 'verify', '--json']);

        final envelope = decodeLastLine(out);
        expect(envelope['schema'], 'verdict.v1');
        expect(envelope['command'], 'di verify');
        expect(envelope['verdict'], 'pass');
        expect((envelope['subject'] as Map)['kind'], 'di');
      });

      test(
        'zfa datasource check --json ends with the canonical envelope',
        () async {
          final out = await CliRunner(exitOnCompletion: false).runCapturing([
            '-C',
            tmp.path,
            'datasource',
            'check',
            'Product',
            '--json',
          ]);

          final envelope = decodeLastLine(out);
          expect(envelope['schema'], 'verdict.v1');
          expect(envelope['command'], 'datasource check');
          expect(envelope['verdict'], 'fail');
          expect((envelope['subject'] as Map)['kind'], 'datasource');
          expect((envelope['subject'] as Map)['entity'], 'Product');
        },
      );
    },
  );
}
