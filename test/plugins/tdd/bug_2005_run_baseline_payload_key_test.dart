// The run-baseline payload KEY contract (issue #2005).
//
// `RunBaselineCache.write` emits the JSON key `exitCode` and
// `RunBaselineCache.read` REQUIRES that key — the payload is a wire format
// between the run driver (the writer) and `make` (the reader), not a
// projection of a Dart identifier.
//
// Commit 898bc8b5 renamed the Dart identifier `exitCode` ->
// `CliRunner.lastDispatchedExitCode` and carried the JSON KEY along with it
// in seven test fixtures: the writer and the reader stopped agreeing, every
// cached baseline became unreadable, and the caller silently fell back to
// the absolute-green preflight (issue #922's safe fallback). The failure was
// SAFE, so nothing went red in CI — the affected suites are `slow`/`e2e` and
// the fast lane excludes them.
//
// This suite pins the contract so the next blind rename fails loudly:
//
//   1. the reader accepts a payload keyed `exitCode` and rejects one keyed
//      anything else (the key name IS the contract);
//   2. NO source file writes a run-baseline-shaped payload without the
//      `exitCode` key — the sweep that would have caught the seven fixtures.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/run_baseline_cache.dart';
import 'package:zuraffa/src/plugins/tdd/services/suite_guard.dart';

import '../../helpers/project_root.dart';

void main() {
  group('the run-baseline payload key is exitCode', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('zfa_2005_baseline_');
    });

    tearDown(() async {
      if (sandbox.existsSync()) await sandbox.delete(recursive: true);
    });

    Future<SuiteSnapshot?> readPayload(Map<String, Object?> payload) async {
      final file = File(p.join(sandbox.path, 'run-baseline.json'));
      await file.writeAsString(jsonEncode(payload));
      return const RunBaselineCache().read(file.path);
    }

    test(
      'a payload keyed exitCode is READABLE (the writer/reader agree)',
      () async {
        final snapshot = await readPayload({
          'command': 'dart test',
          'exitCode': 1,
          'failedTests': ['test/other_test.dart: other behavior red'],
          'capturedAt': '2026-09-01T00:00:00.000Z',
          'parseable': true,
        });

        expect(snapshot, isNotNull);
        expect(snapshot!.exitCode, 1);
        expect(snapshot.failedTests, [
          'test/other_test.dart: other behavior red',
        ]);
      },
    );

    test('a payload keyed anything else is UNREADABLE (the key is the '
        'contract, not the identifier)', () async {
      final snapshot = await readPayload({
        'command': 'dart test',
        'notExitCode': 1,
        'capturedAt': '2026-09-01T00:00:00.000Z',
        'parseable': true,
      });

      expect(snapshot, isNull);
    });
  });

  group('no source writes a run-baseline payload without the exitCode key', () {
    test(
      'every run-baseline-shaped payload in the repo carries exitCode',
      () async {
        final root = await findProjectRoot();
        final offenders = <String>[];

        for (final dir in const ['lib', 'bin', 'tool', 'test']) {
          final absolute = Directory(p.join(root, dir));
          if (!absolute.existsSync()) continue;
          for (final file in absolute.listSync(recursive: true)) {
            if (file is! File || !file.path.endsWith('.dart')) continue;
            final text = file.readAsStringSync();
            final matches = RegExp(
              r"""['"]failedTests['"]\s*:""",
            ).allMatches(text);
            for (final match in matches) {
              final block = _enclosingMapLiteral(text, match.start);
              if (block == null) continue;
              if (!block.contains("'exitCode'") &&
                  !block.contains('"exitCode"')) {
                offenders.add(
                  '${p.relative(file.path, from: root)}:${_lineOf(text, match.start)}',
                );
              }
            }
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'These sources write a run-baseline/corpus-baseline payload '
              'without the `exitCode` key the reader requires, so every such '
              'baseline is unreadable and the caller falls back to the '
              'absolute-green preflight (issue #2005). Use `exitCode`.\n'
              '${offenders.join('\n')}',
        );
      },
    );
  });
}

/// The map literal enclosing the key at [keyIndex], or null when the key is
/// not inside one (a reader, e.g. `json['failedTests']`).
String? _enclosingMapLiteral(String text, int keyIndex) {
  var start = -1;
  for (var i = keyIndex - 1; i >= 0; i--) {
    final c = text[i];
    if (c == '{') {
      start = i;
      break;
    }
    if (c == '}' || c == ';') return null;
  }
  if (start < 0) return null;

  var depth = 0;
  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  return text.substring(start);
}

/// The 1-based line number of [offset] in [text].
int _lineOf(String text, int offset) =>
    '\n'.allMatches(text.substring(0, offset)).length + 1;
