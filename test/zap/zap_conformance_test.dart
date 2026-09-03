// Spec 071 (issue #809) — ZAP CLI surface: conform + schema.
//
// A2, A3, U21 from specs/071-zuraffa-agent-protocol/tdd/test-list.md:
// `zfa zap conform` passes with the machine summary line; `--format json`
// emits one verdict object; a failing drift check flips the exit; the
// schema subcommand prints and exports (FR-006, FR-008, SC-002).
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/project_root.dart';

late CliRunner runner;

void main() {
  setUp(() {
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() {
    exitCode = 0;
  });

  group('zfa zap conform', () {
    test('A2: zfa zap conform passes with the machine summary line', () async {
      final out = await runner.runCapturing(['zap', 'conform']);

      expect(exitCode, 0, reason: out);
      // The machine summary line, per the #778 exit vocabulary.
      final lastLine = out.trim().split('\n').last;
      expect(
        lastLine,
        matches(RegExp(r'^zap: conform checks=\d+ passed=\d+ failed=0 — OK$')),
        reason:
            'the final stdout line must be the machine summary: '
            '$lastLine',
      );
      // Human check lines precede it.
      expect(out, contains('schema:'));
    });

    test('A3: --format json emits one verdict object', () async {
      final out = await runner.runCapturing([
        'zap',
        'conform',
        '--format',
        'json',
      ]);
      expect(exitCode, 0, reason: out);

      final lines = out.trim().split('\n');
      expect(lines, hasLength(1), reason: 'json mode prints ONE object');
      final verdict = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(verdict['ok'], isTrue);
      expect(verdict['passed'], greaterThan(0));
      expect(verdict['failed'], 0);
      expect(verdict['checks'], isA<List>());
      final results = (verdict['checks'] as List).cast<Map<String, dynamic>>();
      expect(results.length, verdict['total']);
      expect(results.length, verdict['passed'] + verdict['failed']);
      expect(
        results.every((c) => c['ok'] == true),
        isTrue,
        reason: 'every check result is green',
      );
    });

    test(
      'A3: a failing drift check flips the verdict and the exit code',
      () async {
        // A temp dir holding a TAMPERED copy of the published schemas —
        // the drift gate must fail loudly (exit 1) and say which file.
        final dir = Directory.systemTemp.createTempSync('zap_drift');
        addTearDown(() => dir.deleteSync(recursive: true));
        Directory('${dir.path}/schemas').createSync();
        File(
          '${dir.path}/schemas/mission.schema.json',
        ).writeAsStringSync(jsonEncode({'tampered': true}));

        final out = await runner.runCapturing([
          'zap',
          'conform',
          '--format',
          'json',
          '--drift-dir',
          dir.path,
        ]);
        expect(exitCode, 1, reason: 'a drifted contract must fail the gate');

        final verdict =
            jsonDecode(out.trim().split('\n').single) as Map<String, dynamic>;
        expect(verdict['ok'], isFalse);
        expect(verdict['failed'], greaterThan(0));
        expect(
          out,
          contains('mission.schema.json'),
          reason: 'the drifted file must be named',
        );
      },
    );
  });

  group('zfa zap schema', () {
    test('U21: --type mission prints the draft-07 schema', () async {
      final out = await runner.runCapturing([
        'zap',
        'schema',
        '--type',
        'mission',
      ]);
      expect(exitCode, 0, reason: out);

      // The whole (indented) output IS the schema.
      final schema = jsonDecode(out.trim());
      expect(schema, isA<Map>());
      final map = schema as Map<String, dynamic>;
      expect(map['\$schema'], 'http://json-schema.org/draft-07/schema#');
      expect(map['type'], 'object');
      expect(map['properties'], isA<Map>());
    });

    test('U21: --export writes the five schemas + four goldens', () async {
      final dir = Directory.systemTemp.createTempSync('zap_export');
      addTearDown(() => dir.deleteSync(recursive: true));

      final out = await runner.runCapturing([
        'zap',
        'schema',
        '--export',
        dir.path,
      ]);
      expect(exitCode, 0, reason: out);

      for (final type in [
        'mission',
        'evidence',
        'checkpoint',
        'receipt',
        'error',
      ]) {
        final file = File('${dir.path}/schemas/$type.schema.json');
        expect(file.existsSync(), isTrue, reason: '$type schema exported');
        final schema = jsonDecode(file.readAsStringSync());
        expect(
          (schema as Map)['\$schema'],
          'http://json-schema.org/draft-07/schema#',
        );
      }
      for (final type in ['mission', 'evidence', 'checkpoint', 'receipt']) {
        expect(
          File('${dir.path}/golden/$type.golden.json').existsSync(),
          isTrue,
          reason: '$type golden exported',
        );
      }

      // The exported files equal the committed ones (round-trip through
      // the same writer that produced them).
      final root = await findProjectRoot();
      final committed = File(
        '$root/specs/071-zuraffa-agent-protocol/schemas/mission.schema.json',
      ).readAsStringSync();
      final exported = File(
        '${dir.path}/schemas/mission.schema.json',
      ).readAsStringSync();
      expect(
        exported,
        committed,
        reason:
            'export is deterministic — byte-equal to the committed '
            'contract',
      );
    });

    test('U21: an unknown type is a usage error', () async {
      final out = await runner.runCapturing([
        'zap',
        'schema',
        '--type',
        'telepathy',
      ]);
      expect(exitCode, 64, reason: out);
    });
  });
}
