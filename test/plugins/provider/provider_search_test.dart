import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_provider_search_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('finds existing provider in non-standard domain folder', () async {
    final plugin = ProviderPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );

    // 1. Create a provider manually in a custom location
    final customDomainDir = Directory(
      path.join(outputDir, 'data', 'providers', 'custom_domain'),
    );
    await customDomainDir.create(recursive: true);
    final providerFile = File(
      path.join(customDomainDir.path, 'barcode_provider.dart'),
    );
    await providerFile.writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../../../domain/services/barcode_service.dart';

class BarcodeProvider implements BarcodeService {
  @override
  Future<void> initialMethod() async {}
}
''');

    // 2. Try to generate another method for BarcodeService in a different domain
    final config = GeneratorConfig(
      name: 'ScanBarcode',
      service: 'Barcode',
      domain: 'scanner', // Different domain than custom_domain
      paramsType: 'NoParams',
      returnsType: 'void',
      outputDir: outputDir,
      generateData: true,
      appendToExisting: true,
    );

    final result = await plugin.generate(config);

    // Should have updated the existing file instead of creating a new one in 'scanner' domain
    expect(result.first.path, equals(providerFile.path));

    final content = providerFile.readAsStringSync();
    expect(content.contains('Future<void> initialMethod()'), isTrue);
    expect(content.contains('Future<void> scanBarcode()'), isTrue);

    // Verify no file was created in the 'scanner' domain
    final wrongFile = File(
      path.join(
        outputDir,
        'data',
        'providers',
        'scanner',
        'barcode_provider.dart',
      ),
    );
    expect(wrongFile.existsSync(), isFalse);
  });
}
