import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/zfa_cli.dart' as cli;

/// SPEC 1127, order 2 — `zfa service verify <Entity>`.
///
/// The grammar-conformance gate: re-derives the member surface the service
/// schema grammar prescribes (params/returns/type/init knobs, same builder
/// the generator drives) and audits the generated service FILE on disk with
/// the analyzer AST. Exit 1 when the file's grammar does not match the
/// schema (missing class, missing method, signature mismatch, parse error);
/// exit 0 when it conforms. `--json` emits one canonical `zuraffa.verdict.v1`
/// envelope (issue #1105). Usage errors exit 2.
///
/// The knobs resolve from the stable create receipt
/// (`.zfa/receipts/service-<Entity>.json`) and can be overridden per flag —
/// the same receipt-then-flags resolution `zfa provider verify` uses.
void main() {
  late Directory workspace;
  late String outputDir;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_service_verify_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_service_verify_test
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

  File serviceFile(String name) =>
      File(p.join(outputDir, 'domain', 'services', name));

  group('zfa service verify (grammar conformance gate)', () {
    test('a freshly generated service conforms: exit 0', () async {
      await zfa([
        'service',
        'create',
        'SendEmail',
        '--params',
        'EmailParams',
        '--returns',
        'SendResult',
      ]);

      final output = await zfa(['service', 'verify', 'SendEmail']);

      expect(
        output,
        contains('✅'),
        reason: 'conform gate must affirm: $output',
      );
      expect(exitCode, equals(0));
    });

    test('hand-edited file (method body signature drift) fails: exit 1 '
        'with a --> fix: line', () async {
      await zfa([
        'service',
        'create',
        'SendEmail',
        '--params',
        'EmailParams',
        '--returns',
        'SendResult',
      ]);

      // Hand-edit: rename the method away from the grammar-prescribed
      // surface (sendEmail → send).
      final file = serviceFile('send_email_service.dart');
      file.writeAsStringSync(
        file.readAsStringSync().replaceAll('sendEmail', 'send'),
      );

      final output = await zfa(['service', 'verify', 'SendEmail']);

      expect(output, contains('missing_method'));
      expect(output, contains('--> fix:'));
      expect(exitCode, equals(1));
    });

    test('return-type drift fails the gate (grammar ≡ schema)', () async {
      await zfa([
        'service',
        'create',
        'SendEmail',
        '--params',
        'EmailParams',
        '--returns',
        'SendResult',
      ]);

      final file = serviceFile('send_email_service.dart');
      file.writeAsStringSync(
        file.readAsStringSync().replaceAll(
          'Future<SendResult> sendEmail',
          'Stream<SendResult> sendEmail',
        ),
      );

      final output = await zfa(['service', 'verify', 'SendEmail']);

      expect(output, contains('signature_mismatch'));
      expect(exitCode, equals(1));
    });

    test('missing service file → exit 1, missing_file finding', () async {
      final output = await zfa(['service', 'verify', 'Ghost']);

      expect(output, contains('missing_file'));
      expect(exitCode, equals(1));
    });

    test('--json emits one canonical envelope (pass)', () async {
      await zfa([
        'service',
        'create',
        'Audit',
        '--params',
        'NoParams',
        '--returns',
        'Audit',
        '--type',
        'usecase',
      ]);

      final output = await zfa(['service', 'verify', 'Audit', '--json']);

      Map<String, dynamic>? decoded;
      for (final line in output.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('{')) continue;
        try {
          final value = jsonDecode(trimmed);
          if (value is Map<String, dynamic>) decoded = value;
        } catch (_) {}
      }
      expect(decoded, isNotNull, reason: output);
      expect(decoded!['schema'], equals('zuraffa.verdict.v1'));
      expect(decoded['command'], equals('zfa service verify'));
      expect(decoded['verdict'], equals('pass'));
      expect(decoded['exit_class'], equals(0));
      expect(decoded['subject']['kind'], equals('service'));
      expect(decoded['subject']['id'], equals('AuditService'));
      expect((decoded['details']['methods'] as List), contains('audit'));
    });

    test('--json emits canonical envelope (fail) on drift', () async {
      await zfa([
        'service',
        'create',
        'Billing',
        '--params',
        'NoParams',
        '--returns',
        'Billing',
      ]);
      final file = serviceFile('billing_service.dart');
      file.writeAsStringSync(
        file.readAsStringSync().replaceAll('billing(', 'charge('),
      );

      final output = await zfa(['service', 'verify', 'Billing', '--json']);

      Map<String, dynamic>? decoded;
      for (final line in output.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('{')) continue;
        try {
          final value = jsonDecode(trimmed);
          if (value is Map<String, dynamic>) decoded = value;
        } catch (_) {}
      }
      expect(decoded, isNotNull, reason: output);
      expect(decoded!['verdict'], equals('fail'));
      expect(decoded['exit_class'], equals(1));
      final findings = (decoded['findings'] as List).cast<Map>();
      expect(
        findings.any((f) => f['kind'] == 'missing_method'),
        isTrue,
        reason: 'findings must name the drifted member: $findings',
      );
      expect(findings.first['fix'], isA<String>());
    });

    test('no entity → usage error (exit 2), never a crash', () async {
      final output = await zfa(['service', 'verify']);

      expect(output, contains('--> fix:'));
      expect(exitCode, equals(2));
    });

    test('knob overrides: --returns changes the audited surface', () async {
      await zfa(['service', 'create', 'Ticker', '--params', 'NoParams']);

      // The file was generated with returns == 'void' (default). Verifying
      // with --returns int must FAIL (the file says void).
      final output = await zfa([
        'service',
        'verify',
        'Ticker',
        '--returns',
        'int',
      ]);

      expect(exitCode, equals(1));
      expect(output, contains('signature_mismatch'));
    });

    test('malformed entity (weird characters) does not crash with an '
        'uncaught exception', () async {
      final output = await zfa(['service', 'verify', 'not a valid entity!!']);

      expect(output, isNot(contains('Unhandled exception')));
      expect(exitCode, isNot(equals(0)));
    });
  });
}
