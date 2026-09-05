import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/zfa_cli.dart' as cli;

/// Issue #978, order 5 — machine verdict for `zfa service create`.
///
/// The `--json` option (already the generic machine-input channel:
/// "Pass arguments as JSON string") becomes the full machine contract:
/// JSON in → JSON out. When the caller passes `--json`, the command emits a
/// SINGLE parseable verdict object (issue #778 convention — no prose) with
/// the envelope:
///
///     {"schema":1, "ok":true, "file":..., "methods":[...], "type":...}
///
/// Error paths carry `ok:false`, a `fix` hint, and a `--> fix:` line, with
/// a non-zero exit code. Prose mode (no `--json`) is unchanged.
void main() {
  late Directory workspace;
  late String outputDir;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_service_json_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_service_json_test
environment:
  sdk: ^3.11.0
''');
    exitCode = 0;
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  Future<String> zfa(List<String> args) =>
      cli.runCapturing(['-C', workspace.path, ...args]);

  /// The last JSON object printed on stdout (prose lines may precede it).
  Map<String, dynamic>? lastJson(String output) {
    Map<String, dynamic>? decoded;
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('{')) continue;
      try {
        final value = jsonDecode(trimmed);
        if (value is Map<String, dynamic>) decoded = value;
      } catch (_) {
        // Not JSON — skip.
      }
    }
    return decoded;
  }

  group('zfa service create --json (machine verdict)', () {
    test(
      'success: single verdict envelope {schema:1, ok, file, methods[], type}',
      () async {
        final output = await zfa([
          'service',
          'create',
          '--json',
          '{"name":"SendEmail","params":"EmailParams","returns":"SendResult","type":"usecase"}',
        ]);

        final verdict = lastJson(output);
        expect(
          verdict,
          isNotNull,
          reason:
              'machine mode must print a parseable verdict object:\n$output',
        );
        expect(verdict!['schema'], equals(1));
        expect(verdict['ok'], isTrue);
        expect(
          verdict['file'],
          isA<String>().having(
            (f) => f,
            'file',
            contains(p.join('domain', 'services', 'send_email_service.dart')),
          ),
        );
        expect(
          (verdict['methods'] as List).cast<String>(),
          contains('sendEmail'),
          reason: 'the interface member name(s) must be reported',
        );
        expect(verdict['type'], equals('usecase'));

        // The artifact really landed and matches the verdict.
        final file = File(
          p.join(outputDir, 'domain', 'services', 'send_email_service.dart'),
        );
        expect(file.existsSync(), isTrue);
        expect(
          file.readAsStringSync(),
          contains('Future<SendResult> sendEmail(EmailParams params);'),
        );

        expect(exitCode, equals(0), reason: 'verdict ok:true must exit 0');
      },
    );

    test(
      'flags merge with the JSON payload (empty {} + --name works)',
      () async {
        final output = await zfa([
          'service',
          'create',
          '--name',
          'Barcode',
          '--params',
          'NoParams',
          '--returns',
          'Barcode',
          '--json',
          '{}',
        ]);

        final verdict = lastJson(output);
        expect(verdict, isNotNull);
        expect(verdict!['ok'], isTrue);
        expect(
          verdict['file'],
          isA<String>().having(
            (f) => f,
            'file',
            contains(p.join('domain', 'services', 'barcode_service.dart')),
          ),
        );
      },
    );

    test('error path: missing required name → ok:false verdict + --> fix: line '
        '+ non-zero exit', () async {
      final output = await zfa(['service', 'create', '--json', '{}']);

      final verdict = lastJson(output);
      expect(
        verdict,
        isNotNull,
        reason: 'error paths are verdicts too:\n$output',
      );
      expect(verdict!['schema'], equals(1));
      expect(verdict['ok'], isFalse);
      expect(verdict['error'], isA<String>());
      expect(verdict['fix'], isA<String>());

      expect(output, contains('--> fix:'));
      expect(output, isNot(contains('✅ Success!')));
      expect(exitCode, equals(64), reason: 'usage error family (missing name)');
    });

    test('prose mode (no --json) is unchanged: ✅ Success framing', () async {
      final output = await zfa([
        'service',
        'create',
        '--name',
        'Sync',
        '--params',
        'SyncParams',
      ]);

      expect(output, contains('✅ Success! Created/Modified:'));
      expect(
        output,
        contains(p.join('domain', 'services', 'sync_service.dart')),
      );
      expect(exitCode, equals(0));
    });
  });
}
