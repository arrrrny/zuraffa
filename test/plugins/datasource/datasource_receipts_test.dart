import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/datasource_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

/// Spec #977 — proof receipts on the standalone `zfa datasource` path.
///
/// A successful (non-dry-run) standalone generation must ship its own
/// `proof.v1` receipt at `.zfa/receipts/datasource-<entity>.json`,
/// binding the emitted artifacts' digests AND recording the id-field /
/// query-field resolution that generation consumed (#294 audit trail).
/// `zfa proof check` must stay green on the receipts we write.
Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

/// DataSourceCommand with a hand-parsed ArgResults — the standalone
/// entity-positional shape is only reachable through direct programmatic
/// invocation (package:args rejects it at dispatch when subcommands are
/// registered), which is exactly the host path run() must serve honestly.
class _InjectableDataSourceCommand extends DataSourceCommand {
  _InjectableDataSourceCommand(super.plugin);

  ArgResults? injected;

  @override
  ArgResults? get argResults => injected ?? super.argResults;

  void accept(List<String> args) => injected = argParser.parse(args);
}

void main() {
  late Directory tempDir;
  late String originalCwd;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_977_receipt_');
    originalCwd = Directory.current.path;
    Directory.current = tempDir.path;
  });

  tearDown(() async {
    Directory.current = originalCwd;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  _InjectableDataSourceCommand command() {
    final plugin = DataSourcePlugin(
      outputDir: '${tempDir.path}/lib/src',
      options: const GeneratorOptions(),
    );
    return _InjectableDataSourceCommand(plugin);
  }

  group('standalone datasource receipts', () {
    test('successful generation writes datasource-<entity>.json', () async {
      exitCode = 0;

      final cmd = command()..accept(['--no-local', 'Product']);
      await captureOutput(() => cmd.run());

      final receiptFile = File(
        '${tempDir.path}/.zfa/receipts/datasource-product.json',
      );
      expect(receiptFile.existsSync(), isTrue);

      final receipt =
          jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
      expect(receipt['schema'], 'proof.v1');
      expect(receipt['command'], 'datasource create');
      expect(receipt['target'], 'Product');

      // #294 audit trail: the id-field / query-field resolution the run
      // consumed must be recorded, even when it is the default.
      final input = receipt['input'] as Map<String, dynamic>;
      expect(input['id-field'], 'id');
      expect(input['id-field-type'], 'String');
      expect(input['query-field'], 'id');

      // Every emitted artifact is digest-bound.
      final files = receipt['files'] as List;
      expect(files, isNotEmpty);
      for (final entry in files) {
        final map = entry as Map<String, dynamic>;
        final artifact = File('${tempDir.path}/${map['path']}');
        expect(
          artifact.existsSync(),
          isTrue,
          reason: 'receipt names ${map['path']} which must exist',
        );
        final digest = sha256.convert(artifact.readAsBytesSync()).toString();
        expect(
          map['sha256'],
          digest,
          reason: 'receipt digest must match on-disk bytes',
        );
      }
    });

    test('written receipts keep `proof check` green', () async {
      exitCode = 0;

      final cmd = command()..accept(['--no-local', 'Product']);
      await captureOutput(() => cmd.run());

      final report = await ProofChecker(projectRoot: tempDir.path).check();
      expect(report.ok, isTrue, reason: 'fresh receipt must verify clean');
      expect(report.findings, isEmpty);
      expect(report.receipts, greaterThan(0));
    });

    test('dry-run does not write a receipt', () async {
      exitCode = 0;

      final cmd = command()..accept(['--dry-run', 'Product']);
      await captureOutput(() => cmd.run());

      final receiptsDir = Directory('${tempDir.path}/.zfa/receipts');
      expect(
        receiptsDir.existsSync(),
        isFalse,
        reason: 'nothing was written, so nothing can be proven',
      );
    });

    test(
      'local variant generation records the id-field in the receipt too',
      () async {
        exitCode = 0;

        final cmd = command()..accept(['--local', 'Product']);
        await captureOutput(() => cmd.run());

        final receiptFile = File(
          '${tempDir.path}/.zfa/receipts/datasource-product.json',
        );
        expect(receiptFile.existsSync(), isTrue);
        final receipt =
            jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
        final files = (receipt['files'] as List).cast<Map<String, dynamic>>();
        final paths = files.map((f) => f['path'] as String).toSet();
        expect(
          paths.any((p) => p.endsWith('product_local_datasource.dart')),
          isTrue,
        );
      },
    );
  });
}
