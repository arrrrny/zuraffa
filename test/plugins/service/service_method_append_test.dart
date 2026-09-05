import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

/// Issue #978, order 4 — method-append test for
/// `MethodCapability(targetType: 'service')` (`zfa service method`).
///
/// Mirrors the repository append tests (`repository_plugin_test.dart` /
/// `append_method_capability_test.dart`): appending a method to an EXISTING
/// service must preserve every hand-written member (doc comments, custom
/// methods, getters) and append the new method with the requested
/// signature — action `updated`, never `import augment`.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_service_append_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('zfa service method appends to an existing service and preserves '
      'hand-written members', () async {
    const servicesRelPath = 'domain/services';
    final servicesDir = Directory('$outputDir/$servicesRelPath');
    await servicesDir.create(recursive: true);

    // A hand-written service: doc comment, a custom method with a
    // non-trivial signature, and a getter. All three must survive the
    // append.
    await File('${servicesDir.path}/billing_service.dart').writeAsString('''
import 'package:zuraffa/zuraffa.dart';

/// Hand-written billing domain service.
abstract class BillingService {
  /// Hand-written doc comment on a member.
  Future<Invoice> fetchInvoice(String invoiceId);

  Stream<bool> get isReady;
}
''');

    final plugin = ServicePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    final methodCapability = plugin.capabilities.firstWhere(
      (c) => c.name == 'method',
    );

    final result = await methodCapability.execute({
      'target': 'BillingService',
      'name': 'refundCharge',
      'params': 'RefundParams',
      'returns': 'void',
      'type': 'sync',
      'force': true,
    });

    expect(result.success, isTrue);
    expect(result.files, isNotEmpty);

    final hostEntry =
        (result.data?['generatedFiles'] as List).firstWhere(
              (f) => f.path.contains('billing_service.dart'),
            )
            as dynamic;
    expect(hostEntry.action, 'updated');

    final content = await File(
      '$outputDir/$servicesRelPath/billing_service.dart',
    ).readAsString();

    // Hand-written members preserved verbatim.
    expect(content, contains('/// Hand-written billing domain service.'));
    expect(
      content,
      contains('Future<Invoice> fetchInvoice(String invoiceId);'),
      reason: 'the hand-written method must survive the append',
    );
    expect(content, contains('Stream<bool> get isReady'));
    expect(
      content,
      contains('/// Hand-written doc comment on a member.'),
      reason: 'member-level doc comments must survive the append',
    );

    // New member appended with the requested signature (sync type: no
    // Future wrapper).
    expect(content, contains('void refundCharge(RefundParams params);'));
    // Structurally intact: exactly one class declaration.
    expect('abstract class BillingService'.allMatches(content), hasLength(1));
    // The append path must never emit augmentation files.
    expect(content, isNot(contains('import augment')));
    expect(
      File(
        '$outputDir/$servicesRelPath/billing_service.augment.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('append is repeatable: appending the same method again is a no-op, not '
      'a duplicate', () async {
    const servicesRelPath = 'domain/services';
    final servicesDir = Directory('$outputDir/$servicesRelPath');
    await servicesDir.create(recursive: true);
    await File('${servicesDir.path}/billing_service.dart').writeAsString('''
abstract class BillingService {
  Future<void> existingMethod();
}
''');

    final plugin = ServicePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    final methodCapability = plugin.capabilities.firstWhere(
      (c) => c.name == 'method',
    );

    await methodCapability.execute({
      'target': 'BillingService',
      'name': 'refundCharge',
      'returns': 'void',
      'force': true,
    });
    final second = await methodCapability.execute({
      'target': 'BillingService',
      'name': 'refundCharge',
      'returns': 'void',
      'force': true,
    });

    expect(second.success, isTrue);
    final content = await File(
      '$outputDir/$servicesRelPath/billing_service.dart',
    ).readAsString();
    expect('refundCharge'.allMatches(content), hasLength(1));
    expect(content, contains('Future<void> existingMethod();'));
  });
}
