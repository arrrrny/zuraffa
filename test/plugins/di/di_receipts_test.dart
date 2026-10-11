import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/plugin_system/capability_invocation_wrapper.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/di/capabilities/create_di_capability.dart';
import 'package:zuraffa/src/plugins/di/capabilities/register_capability.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';

/// SPEC 0974 (issue #974, order 3) under the issue-#1130 writer
/// unification: the standalone `zfa di create/register` path ships ONE
/// proof.v1 receipt per run, persisted by the
/// [CapabilityInvocationWrapper] (the sole receipt writer — a second
/// writer races it and shadows the canonical document in `loadAll()`).
/// The DI-specific payload (index digest aggregate) arrives via the
/// public `indexFiles` input key, so `zfa proof check` is green after a
/// standalone run exactly like the `zfa make` path (issue #807).
void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_di_receipt_');
    projectRoot = tempDir.path;
    outputDir = p.join(projectRoot, 'lib', 'src');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  CapabilityInvocationWrapper diWrapper(ZuraffaCapability capability) =>
      CapabilityInvocationWrapper(
        capability: capability,
        pluginId: 'di',
        projectRoot: projectRoot,
      );

  test('A3: standalone di create appends a di-create-<target> receipt '
      'binding the written registrations and index', () async {
    final plugin = DiPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    final wrapper = diWrapper(
      CreateDiCapability(plugin, projectRoot: projectRoot),
    );

    final result = await wrapper.execute({'name': 'Product'});

    expect(result.success, isTrue, reason: 'generation itself succeeded');

    final records = await ReceiptStore(projectRoot: projectRoot).loadAll();
    expect(
      records,
      hasLength(1),
      reason:
          'exactly one receipt — the wrapper is the sole writer '
          '(issue #1130)',
    );
    expect(
      records.single.fileName,
      matches(RegExp(r'^di-create-Product-')),
      reason:
          'saveCapability keys receipts '
          '<plugin>-<capability>-<entity>-<stamp>.json',
    );

    final receipt = records.single.receipt;
    expect(receipt.schema, 'proof.v1');
    expect(receipt.command, 'di create');
    expect(receipt.target, 'Product');
    expect(receipt.repro, contains('zfa di create Product'));
    // Issue #996 machine fields — the old self-receipt carried none.
    expect(receipt.plugin, 'di');
    expect(receipt.capability, 'create');
    expect(receipt.entity, 'Product');

    // Registrations written: every receipted artifact exists on disk and
    // its digest binds the exact bytes.
    expect(receipt.files, isNotEmpty);
    for (final entry in receipt.files) {
      final file = File(p.join(projectRoot, entry.path));
      expect(
        file.existsSync(),
        isTrue,
        reason: '${entry.path} must exist when receipted',
      );
      final digest = crypto.sha256.convert(file.readAsBytesSync()).toString();
      expect(
        entry.sha256,
        digest,
        reason: '${entry.path} digest must bind on-disk bytes',
      );
    }
    expect(
      receipt.files.any((f) => f.path.endsWith('di/index.dart')),
      isTrue,
      reason: 'the DI index must be receipted',
    );

    // Index hash recorded in the input context (spec 0974 payload,
    // surfaced via args['_indexFiles'] and aliased by the wrapper).
    final indexFiles = receipt.input['indexFiles'];
    expect(indexFiles, isA<Map<String, dynamic>>());
    expect((indexFiles as Map).keys, anyElement(endsWith('di/index.dart')));
  });

  test(
    'A3b: zfa proof check (ProofChecker) is green after a standalone run',
    () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      await diWrapper(
        CreateDiCapability(plugin, projectRoot: projectRoot),
      ).execute({'name': 'Product'});

      final report = await ProofChecker(projectRoot: projectRoot).check();
      expect(
        report.ok,
        isTrue,
        reason: 'proof findings: ${report.findings.map((f) => f.detail)}',
      );
      expect(report.receipts, 1);
      expect(report.filesChecked, greaterThan(0));
    },
  );

  test('U4: standalone di register also writes a receipt', () async {
    final plugin = DiPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    final wrapper = diWrapper(
      RegisterCapability(plugin, projectRoot: projectRoot),
    );

    final result = await wrapper.execute({'target': 'ListingService'});

    expect(result.success, isTrue);
    final records = await ReceiptStore(projectRoot: projectRoot).loadAll();
    expect(records, hasLength(1));
    expect(
      records.single.fileName,
      matches(RegExp(r'^di-register-ListingService-')),
    );

    final receipt = records.single.receipt;
    expect(receipt.command, 'di register');
    expect(receipt.target, 'ListingService');
    expect(receipt.entity, 'ListingService');
    expect(receipt.capability, 'register');
    expect(receipt.files, isNotEmpty);

    final report = await ProofChecker(projectRoot: projectRoot).check();
    expect(report.ok, isTrue);
  });

  test('U5: dry-run and revert runs write no receipt', () async {
    final plugin = DiPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    final wrapper = diWrapper(
      CreateDiCapability(plugin, projectRoot: projectRoot),
    );

    await wrapper.execute({'name': 'Product', 'dryRun': true});
    expect(
      Directory(p.join(projectRoot, '.zfa', 'receipts')).existsSync(),
      isFalse,
      reason: 'dry-run must not persist proof for unwritten artifacts',
    );
  });
}
