// EPIC 1150 — zuraffa.verdict.v1: the canonical --json envelope for the
// whole fleet (E2E layer).
//
// Drives real `zfa` subprocesses (issue #506 pattern) and asserts that the
// LAST stdout line of every --json output path is ONE canonical envelope:
// schema=zuraffa.verdict.v1, result in {ok,error,skipped,refused},
// exit_class int, message, data map, drifts list, ts ISO-8601.
//
// RED (2026-09-07, commit e5b5cc68): every command below still emits its
// own divergent shape — the asserts fail, proving the parser-less fleet.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// The SPEC 917 drift exit code (mirrored locally so this E2E file does
/// not depend on library internals — it tests the CLI as a black box).
class ExitProtocolDrift {
  static const int classCode = 3;
}

void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_1150_verdict_');
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort.
      }
    }
  });

  /// The LAST `{`-leading stdout line = the machine contract line every
  /// command must emit under --json (text/prose above it stays human).
  Map<String, Object?> lastJsonLine(ProcessResult result) {
    final stdoutText = result.stdout as String;
    final lines = stdoutText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('{') || l.startsWith('['))
        .toList();
    expect(lines, isNotEmpty, reason: 'no JSON line on stdout:\n$stdoutText');
    final decoded = jsonDecode(lines.last);
    expect(decoded, isA<Map<String, Object?>>(), reason: lines.last);
    return decoded as Map<String, Object?>;
  }

  /// The canonical-envelope assertion every verb is held to.
  void expectCanonical(
    Map<String, Object?> json,
    String expectedCommand, {
    String result = 'ok',
  }) {
    expect(
      json['schema'],
      'zuraffa.verdict.v1',
      reason: 'envelope schema must be the canonical one',
    );
    expect(json['command'], expectedCommand);
    expect(json['result'], anyOf('ok', 'error', 'skipped', 'refused'));
    expect(json['result'], result);
    expect(
      json['exit_class'],
      isA<int>(),
      reason: 'exit_class is the int exit code, not a label',
    );
    expect(json['message'], isA<String>());
    expect(json['data'], isA<Map<String, Object?>>());
    expect(json['drifts'], isA<List<Object?>>());
    expect(
      json['ts'],
      isA<String>(),
      reason: 'ts is the ISO-8601 instant the verdict was emitted',
    );
    expect(
      DateTime.tryParse(json['ts'] as String),
      isNotNull,
      reason: 'ts must parse as an ISO-8601 timestamp',
    );
  }

  group('[EPIC 1150] every --json path speaks zuraffa.verdict.v1', () {
    test('zfa xray status --json', () async {
      final result = await runZfaSource([
        'xray',
        'status',
        '--json',
        '--root',
        workspace.path,
      ], workingDirectory: workspace.path);
      final json = lastJsonLine(result);
      expectCanonical(json, 'zfa xray status');
      expect((json['data'] as Map<String, Object?>)['enabled'], isA<bool>());
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('zfa manifest (default json listing)', () async {
      final result = await runZfaSource([
        'manifest',
        '--format',
        'json',
      ], workingDirectory: workspace.path);
      final json = lastJsonLine(result);
      expectCanonical(json, 'zfa manifest');
      expect((json['data'] as Map<String, Object?>)['tools'], isA<List>());
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('zfa manifest --verify --format json', () async {
      final result = await runZfaSource([
        'manifest',
        '--verify',
        '--format',
        'json',
      ], workingDirectory: workspace.path);
      final json = lastJsonLine(result);
      // The verdict is honest: in a clean workspace verify passes (ok / 0);
      // where pre-existing drift exists it reports error / 3 — both are
      // correct envelope outcomes, the exit code and result must AGREE.
      expectCanonical(
        json,
        'zfa manifest verify',
        result: json['result'] == 'ok' ? 'ok' : 'error',
      );
      final data = json['data'] as Map<String, Object?>;
      expect(data['certified'], isA<int>());
      expect(data['findings'], isA<List>());
      expect(
        json['exit_class'],
        (json['result'] == 'ok') ? 0 : ExitProtocolDrift.classCode,
        reason: 'exit_class must equal the process exit code (drift = 3)',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('zfa tdd verdicts --json', () async {
      final result = await runZfaSource([
        'tdd',
        'verdicts',
        '--json',
      ], workingDirectory: workspace.path);
      final json = lastJsonLine(result);
      expectCanonical(json, 'zfa tdd verdicts');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('zfa benchmark list --json', () async {
      final result = await runZfaSource([
        'benchmark',
        'list',
        '--json',
      ], workingDirectory: workspace.path);
      final json = lastJsonLine(result);
      expectCanonical(json, 'zfa benchmark list');
      expect((json['data'] as Map<String, Object?>)['scenarios'], isA<List>());
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('zfa proof check --format=json', () async {
      final result = await runZfaSource([
        'proof',
        'check',
        '--format=json',
      ], workingDirectory: workspace.path);
      final json = lastJsonLine(result);
      expectCanonical(json, 'zfa proof check');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('zfa doctor --format=json', () async {
      final result = await runZfaSource([
        'doctor',
        '--format=json',
      ], workingDirectory: workspace.path);
      final json = lastJsonLine(result);
      expectCanonical(json, 'zfa doctor');
      expect((json['data'] as Map<String, Object?>)['checks'], isA<List>());
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('zfa tdd verdicts --schema prints the canonical schema', () async {
      final result = await runZfaSource([
        'tdd',
        'verdicts',
        '--schema',
      ], workingDirectory: workspace.path);
      final stdoutText = result.stdout as String;
      expect(stdoutText, contains('zuraffa.verdict.v1'));
      expect(stdoutText, contains('"result"'));
      // The frozen result vocabulary, rendered as the schema enum array.
      for (final value in ['ok', 'error', 'skipped', 'refused']) {
        expect(stdoutText, contains('"$value"'));
      }
      expect(stdoutText, contains('"exit_class"'));
      expect(stdoutText, contains('"ts"'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
