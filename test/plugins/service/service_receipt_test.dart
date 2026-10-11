import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/service/service_receipt.dart';
import 'package:zuraffa/src/zfa_cli.dart' as cli;

/// SPEC 1127, order 3 — proof-carrying service generation.
///
/// `zfa service create` ships a deterministic `proof.v1` receipt at
/// `.zfa/receipts/service-<Entity>.json` (the same stable per-entity
/// contract `provider-<Entity>.json` established): digests of the exact
/// bytes that landed on disk plus the service ledger (interface, methods,
/// type, knobs) `zfa service verify` and machine readers consume.
void main() {
  late Directory workspace;
  late String outputDir;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_service_receipt_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_service_receipt_test
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

  group('service receipts (.zfa/receipts/service-<entity>.json)', () {
    test('create writes the stable per-entity receipt (proof.v1)', () async {
      await zfa([
        'service',
        'create',
        'SendEmail',
        '--params',
        'EmailParams',
        '--returns',
        'SendResult',
      ]);

      final receipt = File(
        p.join(workspace.path, '.zfa', 'receipts', 'service-SendEmail.json'),
      );
      expect(
        receipt.existsSync(),
        isTrue,
        reason:
            'acceptance: .zfa/receipts/service-<entity>.json exists after '
            'create (${workspace.path})',
      );

      final json =
          jsonDecode(receipt.readAsStringSync()) as Map<String, dynamic>;
      expect(json['schema'], equals('proof.v1'));
      expect(json['command'], equals('service create'));
      expect(json['target'], equals('SendEmail'));
      expect(json['plugin'], equals('service'));
      expect(json['capability'], equals('create'));
      expect(json['entity'], equals('SendEmail'));

      // The receipt binds the exact on-disk bytes.
      final files = (json['files'] as List).cast<Map>();
      expect(files, hasLength(1));
      final artifact = File(
        p.join(outputDir, 'domain', 'services', 'send_email_service.dart'),
      );
      expect(artifact.existsSync(), isTrue);
      expect(files.first['path'], contains('send_email_service.dart'));
      expect(files.first['sha256'], isA<String>());
      expect(
        (files.first['sha256'] as String).length,
        equals(64),
        reason: 'sha256 hex digest',
      );

      // The ledger extras verify + agents consume.
      expect(json['interface'], equals('SendEmailService'));
      expect((json['methods'] as List).cast<String>(), contains('sendEmail'));
      expect(json['type'], equals('usecase'));
      expect(json['params'], equals('EmailParams'));
      expect(json['returns'], equals('SendResult'));
    });

    test(
      'regeneration with --force refreshes the receipt (latest wins)',
      () async {
        await zfa(['service', 'create', 'Ledger', '--returns', 'Entry']);
        await zfa([
          'service',
          'create',
          'Ledger',
          '--returns',
          'Entry',
          '--force',
        ]);

        final receipts = Directory(p.join(workspace.path, '.zfa', 'receipts'));
        final matching = receipts
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path) == 'service-Ledger.json')
            .toList();
        expect(matching, hasLength(1), reason: 'stable name, refreshed');
      },
    );

    test(
      'dry-run writes no receipt (nothing landed, nothing to prove)',
      () async {
        await zfa([
          'service',
          'create',
          'Dry',
          '--returns',
          'Dry',
          '--dry-run',
        ]);

        final dir = Directory(p.join(workspace.path, '.zfa', 'receipts'));
        expect(
          dir.existsSync() && dir.listSync().whereType<File>().isNotEmpty,
          isFalse,
          reason: 'a dry run must not ship a proof',
        );
      },
    );

    test('declined generation (skipped file) rewrites no ledger lie: the '
        'receipt stays from the run that wrote the bytes', () async {
      await zfa(['service', 'create', 'Keep', '--returns', 'Keep']);
      final receipt = File(
        p.join(workspace.path, '.zfa', 'receipts', 'service-Keep.json'),
      );
      final firstDigest =
          (jsonDecode(receipt.readAsStringSync()) as Map)['files'][0]['sha256'];

      // Second run without --force skips everything.
      await zfa(['service', 'create', 'Keep', '--returns', 'Keep']);
      final secondDigest =
          (jsonDecode(receipt.readAsStringSync()) as Map)['files'][0]['sha256'];
      expect(secondDigest, equals(firstDigest));
    });

    test('ServiceReceiptWriter.load reads the document back', () async {
      await zfa(['service', 'create', 'Loader', '--returns', 'Snapshot']);

      final doc = ServiceReceiptWriter.load(workspace.path, 'Loader');
      expect(doc, isNotNull);
      expect(doc!['schema'], equals('proof.v1'));
      expect(doc['interface'], equals('LoaderService'));
    });
  });
}
