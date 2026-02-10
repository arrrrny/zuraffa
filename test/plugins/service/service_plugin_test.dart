import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_service_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates service interface for custom usecase', () async {
    final plugin = ServicePlugin(
      outputDir: outputDir,
      dryRun: false,
      force: false,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'SendEmail',
        methods: const [],
        service: 'Email',
        domain: 'email',
        paramsType: 'EmailParams',
        returnsType: 'SendResult',
      ),
    );

    final serviceFile = File('$outputDir/domain/services/email_service.dart');

    expect(serviceFile.existsSync(), isTrue);
    final content = serviceFile.readAsStringSync();
    expect(content.contains('abstract class EmailService'), isTrue);
    expect(
      content.contains('Future<SendResult> sendEmail(EmailParams params)'),
      isTrue,
    );
  });

  test('uses stream return type for stream usecases', () async {
    final plugin = ServicePlugin(
      outputDir: outputDir,
      dryRun: false,
      force: false,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'WatchOrders',
        methods: const [],
        service: 'Orders',
        domain: 'orders',
        paramsType: 'OrderFilter',
        returnsType: 'Order',
        useCaseType: 'stream',
      ),
    );

    final serviceFile = File('$outputDir/domain/services/orders_service.dart');

    final content = serviceFile.readAsStringSync();
    expect(
      content.contains('Stream<Order> watchOrders(OrderFilter params)'),
      isTrue,
    );
  });
}
