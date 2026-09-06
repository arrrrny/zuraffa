// Spec 036 — Track 4.2: CLI `zfa xray status --json` machine-readable output.
//
// Behavior B15: --json outputs JSON; default human-readable unchanged;
// release mode reports release_mode: true.
//
// EPIC 1150 migration: the output is the canonical zuraffa.verdict.v1
// envelope; the legacy {enabled, release_mode} keys live inside `data`.
//
// The xray subcommands now accept a `--root` flag so they can be invoked
// hermetically against a temp dir (mirroring `zfa xray deck --root`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/zfa_cli.dart' as cli;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_status_json_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Run the CLI with --root pointing at the temp dir so the test never
  // touches the real user config file.
  Future<String> run(List<String> args) {
    return cli.runCapturing(['xray', ...args, '--root=${tempDir.path}']);
  }

  dynamic tryParseJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  /// The envelope's `data` payload (EPIC 1150) — where the legacy
  /// {enabled, release_mode} keys live.
  Map<String, dynamic> envelopeData(String output) {
    final parsed = tryParseJson(output.trim()) as Map<String, dynamic>;
    expect(parsed['schema'], 'zuraffa.verdict.v1');
    expect(parsed['command'], 'zfa xray status');
    return parsed['data'] as Map<String, dynamic>;
  }

  group('zfa xray status --json', () {
    test('--json flag emits valid JSON on stdout with `enabled` key', () async {
      await run(['disable']);
      final output = await run(['status', '--json']);
      final parsed = tryParseJson(output.trim());
      expect(parsed, isA<Map<String, dynamic>>());
      final data = envelopeData(output);
      expect(data, contains('enabled'));
      expect(data['enabled'], isA<bool>());
    });

    test('default (no flag) emits human-readable text, NOT raw JSON', () async {
      await run(['disable']);
      final output = await run(['status']);
      // Should NOT be parseable as JSON (it's "X-Ray overlay: enabled").
      expect(
        tryParseJson(output.trim()),
        isNull,
        reason: 'default output MUST be human-readable, not JSON',
      );
      expect(output, contains('X-Ray'));
    });

    test('--json reflects enabled=false after `zfa xray disable`', () async {
      await run(['disable']);
      final output = await run(['status', '--json']);
      expect(envelopeData(output)['enabled'], isFalse);
    });

    test('--json reflects enabled=true after `zfa xray enable`', () async {
      await run(['enable']);
      final output = await run(['status', '--json']);
      expect(envelopeData(output)['enabled'], isTrue);
    });

    test('--json includes release_mode indicator (false in tests)', () async {
      await run(['disable']);
      final output = await run(['status', '--json']);
      final data = envelopeData(output);
      expect(data, contains('release_mode'));
      expect(
        data['release_mode'],
        isFalse,
        reason:
            'dart test runs in non-release VM, '
            'so kXrayReleaseMode must be false here',
      );
    });

    test(
      'config file is created under --root/.dart_tool/zuraffa/xray.json',
      () async {
        await run(['enable']);
        final cfgPath = p.join(
          tempDir.path,
          '.dart_tool',
          'zuraffa',
          'xray.json',
        );
        expect(File(cfgPath).existsSync(), isTrue);
        final parsed = jsonDecode(File(cfgPath).readAsStringSync());
        expect(parsed, isA<Map>());
        expect(parsed['enabled'], isTrue);
      },
    );
  });
}
