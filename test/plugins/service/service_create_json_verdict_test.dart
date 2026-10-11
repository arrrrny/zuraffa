import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/verdict_envelope.dart';
import 'package:zuraffa/src/zfa_cli.dart' as cli;

/// SPEC 1127, order 1 — `zfa service create` upgrades to the canonical
/// `zuraffa.verdict.v1` envelope (issue #1105).
///
/// `--json` becomes the machine-OUTPUT flag (a bare negatable flag, the
/// same seam `zfa state create` and `zfa usecase create` took): the last
/// stdout line is exactly one parseable `zuraffa.verdict.v1` envelope
/// listing the service class, the bound provider, the created methods and
/// the grammar/schema conformance verdict. Error paths are envelopes too
/// (verdict fail/error + exit_class + fix), never prose-only and never an
/// uncaught crash.
///
/// This replaces the pre-canonical `{schema: 1, ok, file, ...}` verdict
/// contract (issue #978 order 5) — issue #1127 pins the canonical shape.
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

  group('zfa service create --json (canonical zuraffa.verdict.v1)', () {
    test('success: canonical envelope with service class, provider, methods, '
        'conformance (flags form)', () async {
      final output = await zfa([
        'service',
        'create',
        'SendEmail',
        '--params',
        'EmailParams',
        '--returns',
        'SendResult',
        '--type',
        'usecase',
        '--json',
      ]);

      final raw = lastJson(output);
      expect(
        raw,
        isNotNull,
        reason: 'machine mode must print a parseable envelope:\n$output',
      );
      expect(raw!['schema'], equals('zuraffa.verdict.v1'));
      expect(raw['command'], equals('zfa service create'));
      expect(raw['verdict'], equals('pass'));
      expect(raw['exit_class'], equals(0));
      expect(
        raw['subject'],
        isA<Map>().having((s) => s['kind'], 'subject.kind', 'service'),
      );
      expect(raw['subject']['id'], equals('SendEmailService'));

      // Artifacts: the generated service file.
      final created = (raw['artifacts']['created'] as List).cast<String>();
      expect(
        created.where((f) => f.endsWith('send_email_service.dart')),
        isNotEmpty,
      );

      // Receipts: the stable per-entity receipt is listed.
      expect(raw['receipts'], isA<List>());
      expect(
        (raw['receipts'] as List).cast<String>().any(
          (r) => r.contains('service-SendEmail.json'),
        ),
        isTrue,
        reason: 'envelope must reference .zfa/receipts/service-SendEmail.json',
      );

      // Details: service class, provider binding, methods, conformance.
      final details = raw['details'] as Map;
      expect(details['serviceClass'], equals('SendEmailService'));
      expect(
        (details['methods'] as List).cast<String>(),
        contains('sendEmail'),
        reason: 'the interface member name(s) must be reported',
      );
      expect(details['type'], equals('usecase'));
      expect(
        details['conformance'],
        isA<Map>().having((c) => c['ok'], 'conformance.ok', isTrue),
        reason: 'a fresh generation must prove grammar ≡ schema conformance',
      );

      // The envelope parses through the canonical parser.
      expect(() => VerdictEnvelope.fromJson(raw), returnsNormally);

      // The artifact really landed and matches the verdict.
      final file = File(
        p.join(outputDir, 'domain', 'services', 'send_email_service.dart'),
      );
      expect(file.existsSync(), isTrue);
      expect(
        file.readAsStringSync(),
        contains('Future<SendResult> sendEmail(EmailParams params);'),
      );

      expect(exitCode, equals(0), reason: 'verdict pass must exit 0');
    });

    test(
      'flags merge: --name form works and no value is consumed by --json',
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
        ]);

        final raw = lastJson(output);
        expect(raw, isNotNull);
        expect(raw!['verdict'], equals('pass'));
        expect(
          ((raw['artifacts']['created'] as List).cast<String>()).where(
            (f) => f.endsWith('barcode_service.dart'),
          ),
          isNotEmpty,
        );
      },
    );

    test(
      'error path: missing name → fail envelope + --> fix: + exit 2',
      () async {
        final output = await zfa(['service', 'create', '--json']);

        final raw = lastJson(output);
        expect(
          raw,
          isNotNull,
          reason: 'error paths are verdicts too:\n$output',
        );
        expect(raw!['schema'], equals('zuraffa.verdict.v1'));
        expect(raw['verdict'], equals('fail'));
        expect(raw['exit_class'], equals(2));
        expect(
          (raw['findings'] as List).isNotEmpty ||
              (raw['details']['error'] as String?) != null,
          isTrue,
          reason: 'the failure must carry a finding or an error detail',
        );

        expect(output, contains('--> fix:'));
        expect(output, isNot(contains('✅ Success!')));
        expect(
          exitCode,
          equals(2),
          reason: 'usage error family (missing name) — SPEC 917 canonical 2',
        );
      },
    );

    test('declined generation (exists without --force) → skip verdict, '
        'exit 1, fix names --force', () async {
      // First run creates the artifact.
      await zfa([
        'service',
        'create',
        'Invoice',
        '--params',
        'NoParams',
        '--returns',
        'Invoice',
      ]);

      // Second run without --force: every file is skipped.
      final output = await zfa([
        'service',
        'create',
        'Invoice',
        '--params',
        'NoParams',
        '--returns',
        'Invoice',
        '--json',
      ]);

      final raw = lastJson(output);
      expect(raw, isNotNull, reason: output);
      expect(raw!['verdict'], equals('skip'));
      expect(raw['exit_class'], equals(1));
      expect(
        raw['fix'],
        isA<String>(),
        reason:
            'the skip verdict must carry its remediation at the '
            'canonical top-level fix slot',
      );
      expect(output, contains('--> fix:'));
      expect(exitCode, equals(1));
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

    test('--json with JSON-input payload still accepted for compatibility '
        'of the name channel (--json-args style is NOT reused; bare flag '
        'wins)', () async {
      // The old contract passed a JSON string as the --json OPTION value.
      // The canonical contract is a bare flag. A payload after --json now
      // must NOT be swallowed as the flag's value: the name travels via
      // --name or the positional.
      final output = await zfa([
        'service',
        'create',
        '--name',
        'Legacy',
        '--params',
        'NoParams',
        '--returns',
        'Legacy',
        '--json',
      ]);

      final raw = lastJson(output);
      expect(raw, isNotNull);
      expect(raw!['verdict'], equals('pass'));
    });
  });
}
