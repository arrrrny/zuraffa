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
    final file = File('$outputDir/domain/services/${snake}_service.dart');
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

    test(
      'minimal invocation generates the provider when the service exists',
      () async {
        writeServiceInterface('Cart');

        final result = await capability.execute({'name': 'Cart'});

        expect(result.success, isTrue);
        expect(
          result.files.where(
            (p) => p.endsWith('data/providers/cart/cart_provider.dart'),
          ),
          hasLength(1),
        );
        final generated = result.data?['generatedFiles'] as List<dynamic>;
        final provider = generated.first as dynamic;
        expect(provider.content, contains('class CartProvider'));
        expect(provider.content, contains('implements CartService'));
        expect(
          provider.content,
          contains('../../domain/services/cart_service.dart'),
          reason: 'the provider imports the service interface it implements',
        );
        expect(File(provider.path).existsSync(), isTrue);
      },
    );

    test(
      'minimal invocation without a service interface returns success: false '
      'with an actionable message (spec 1128 order 2 — graceful failure, was '
      'a thrown StateError under B+)',
      () async {
        // Spec 1128 (order 2): the full execute() path is wrapped in
        // try/catch matching the di/repository pattern. The thrown
        // StateError from `_generateFiles` (the #768 missing-service path)
        // is now caught and returned as
        // `ExecutionResult(success: false, message: 'provider create
        // failed for Cart: <StateError message>')`. The diagnostic content
        // that used to live in the StateError body now lives in the
        // ExecutionResult message — same actionable substrings, different
        // carrier. A malformed entity must NOT crash with an uncaught
        // exception.
        final result = await capability.execute({'name': 'Cart'});

        expect(
          result.success,
          isFalse,
          reason:
              'a malformed entity (missing service interface) must '
              'return success: false instead of throwing',
        );
        expect(
          result.files,
          isEmpty,
          reason: 'no files should be reported on a failed run',
        );
        expect(
          result.message,
          isNotNull,
          reason: 'the failure must surface an actionable message',
        );
        expect(
          result.message,
          allOf(
            contains('provider create failed'),
            contains('CartService'),
            contains('domain/services/cart_service.dart'),
            contains('zfa service create --name Cart'),
          ),
          reason:
              'the message must carry the same actionable diagnostics '
              'the B+ StateError carried, prefixed with the capability name',
        );
      },
    );

    test('a missing provider file (malformed entity) does not crash with an '
        'uncaught exception — spec 1128 order 4 error-handling path', () async {
      // This is the spec-1128-order-4 dedicated error-handling test.
      // The capability MUST NOT propagate an exception from execute();
      // it MUST return an ExecutionResult(success:false). The previous
      // test covers the missing-service-interface path (the only known
      // throwing path under B+); this one asserts the broader contract
      // — ANY exception from `_generateFiles` becomes a graceful failure.
      final result = await capability.execute({'name': 'MissingThing'});

      expect(
        result.success,
        isFalse,
        reason:
            'an entity whose service interface does not exist must '
            'gracefully return success: false',
      );
      expect(
        result.message,
        anyOf(
          contains('provider create failed'),
          contains('MissingThingService'),
          contains('zfa service create --name MissingThing'),
        ),
        reason: 'the failure message must be actionable',
      );
      expect(
        result.files,
        isEmpty,
        reason: 'no files may be reported on a failed run',
      );
    });

    test('explicit opt-out (--no-data) is still honored', () async {
      writeServiceInterface('Cart');

      final result = await capability.execute({'name': 'Cart', 'data': false});

      expect(result.files, isEmpty);
    });
  });
}
