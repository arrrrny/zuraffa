import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/provider/capabilities/create_provider_capability.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;
  late CreateProviderCapability capability;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_provider_create_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    final plugin = ProviderPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );
    capability = CreateProviderCapability(plugin);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.delete(recursive: true);
    }
  });

  void writeServiceInterface(String entity) {
    final snake = entity.toLowerCase();
    final file = File(
      '$outputDir/domain/services/${snake}_service.dart',
    );
    file.createSync(recursive: true);
    file.writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

abstract class ${entity}Service {
  Future<void> execute(NoParams params);
}
''');
  }

  // Issue #768: `zfa provider create --name X` is the documented minimal
  // invocation (the manifest requires only `name`), yet the capability
  // schema defaulted `data` to false while the positional
  // `zfa provider <Entity>` path defaults it to true. With the schema
  // default the provider plugin's gate returned zero files and the command
  // reported success — a silent no-op. And because a provider implements a
  // service interface, blindly flipping the default would generate a file
  // importing `domain/services/<name>_service.dart` even when that interface
  // does not exist (uncompilable output). So the capability must default to
  // generating AND validate the service interface up front, failing with an
  // actionable message when it is missing.
  group('issue #768 — provider create default flags', () {
    test('schema data default matches the positional CLI contract', () {
      final props =
          capability.inputSchema['properties'] as Map<String, dynamic>;
      expect(
        (props['data'] as Map<String, dynamic>)['default'],
        isTrue,
        reason: 'positional `zfa provider <Entity>` defaults data to true',
      );
    });

    test('minimal invocation generates the provider when the service exists',
        () async {
      writeServiceInterface('Cart');

      final result = await capability.execute({'name': 'Cart'});

      expect(result.success, isTrue);
      expect(
        result.files
            .where((p) => p.endsWith('data/providers/cart/cart_provider.dart')),
        hasLength(1),
      );
      final generated =
          result.data?['generatedFiles'] as List<dynamic>;
      final provider = generated.first as dynamic;
      expect(provider.content, contains('class CartProvider'));
      expect(provider.content, contains('implements CartService'));
      expect(
        provider.content,
        contains('../../domain/services/cart_service.dart'),
        reason: 'the provider imports the service interface it implements',
      );
      expect(File(provider.path).existsSync(), isTrue);
    });

    test(
        'minimal invocation without a service interface fails with an actionable message',
        () async {
      expect(
        () => capability.execute({'name': 'Cart'}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('CartService'),
              contains('domain/services/cart_service.dart'),
              contains('zfa service create --name Cart'),
            ),
          ),
        ),
        reason: 'the error must say what is missing and how to fix it',
      );
    });

    test('explicit opt-out (--no-data) is still honored', () async {
      writeServiceInterface('Cart');

      final result = await capability.execute({
        'name': 'Cart',
        'data': false,
      });

      expect(result.files, isEmpty);
    });
  });
}
