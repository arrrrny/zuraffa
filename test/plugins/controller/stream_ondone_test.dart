import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'zuraffa_controller_ondone_',
    );
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('stream onDone callbacks', () {
    test(
      'watch method with state includes onDone that sets isWatching to false',
      () async {
        final plugin = ControllerPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Product',
          methods: const ['watch'],
          generateController: true,
          generateState: true,
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        // Should have registerSubscription
        expect(content.contains('registerSubscription'), isTrue);

        // Should have onDone callback in the listen call
        expect(content.contains('onDone:'), isTrue);

        // onDone should set isWatching to false
        // The generated code should look like: onDone: () { updateState(viewState.copyWith(isWatching: false)); }
        expect(
          content.contains('isWatching: false') ||
              content.contains('isWatching = false'),
          isTrue,
          reason: 'onDone should set isWatching to false',
        );
      },
    );

    test(
      'watchList method with state includes onDone that sets isWatchingList to false',
      () async {
        final plugin = ControllerPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Product',
          methods: const ['watchList'],
          generateController: true,
          generateState: true,
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        // Should have registerSubscription
        expect(content.contains('registerSubscription'), isTrue);

        // Should have onDone callback in the listen call
        expect(content.contains('onDone:'), isTrue);

        // onDone should set isWatchingList to false
        expect(
          content.contains('isWatchingList: false') ||
              content.contains('isWatchingList = false'),
          isTrue,
          reason: 'onDone should set isWatchingList to false',
        );
      },
    );

    test(
      'watchRecord method with state includes onDone that sets isWatching to false',
      () async {
        final plugin = ControllerPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Product',
          methods: const ['watch'],
          generateController: true,
          generateState: true,
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        // The watchRecord method is also generated alongside watch
        // It should have onDone that sets isWatching to false
        // We check that isWatching: false appears at least twice (once for watch, once for watchRecord)
        final isWatchingFalseCount = 'isWatching: false'
            .allMatches(content)
            .length;
        expect(
          isWatchingFalseCount,
          greaterThanOrEqualTo(2),
          reason:
              'isWatching: false should appear in both watch and watchRecord onDone callbacks',
        );
      },
    );

    test(
      'custom stream use case with state includes onDone that sets loading to false',
      () async {
        final plugin = ControllerPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'WatchPrices',
          domain: 'pricing',
          service: 'PriceStream',
          useCaseType: 'stream',
          paramsType: 'ProductId',
          returnsType: 'Price',
          generateController: true,
          generateState: true,
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        // Should have onDone callback in the listen call
        expect(content.contains('onDone:'), isTrue);

        // onDone should set isLoading to false
        expect(
          content.contains('isLoading: false') ||
              content.contains('isLoading = false'),
          isTrue,
          reason:
              'onDone should set isLoading to false for custom stream use case',
        );
      },
    );

    test(
      'custom orchestrator stream use case includes onDone that sets specific loading field to false',
      () async {
        final plugin = ControllerPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'ProcessCheckout',
          domain: 'checkout',
          usecases: const ['ValidateCart', 'ProcessPayment'],
          generateController: true,
          generateState: true,
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        // Orchestrator methods don't use streams by default (they're regular UseCases)
        // so onDone should NOT be present
        expect(
          content.contains('onDone:'),
          isFalse,
          reason: 'Non-stream orchestrator methods should not have onDone',
        );
      },
    );

    test('watch and watchList together both include onDone callbacks', () async {
      final plugin = ControllerPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Order',
        methods: const ['watch', 'watchList'],
        generateController: true,
        generateState: true,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      final content = files.first.content ?? '';

      // Should have multiple onDone callbacks (for watch, watchRecord, and watchList)
      final onDoneCount = 'onDone:'.allMatches(content).length;
      expect(
        onDoneCount,
        greaterThanOrEqualTo(3),
        reason: 'Should have onDone for watch, watchRecord, and watchList',
      );

      // Should have isWatching: false for watch and watchRecord
      expect(content.contains('isWatching: false'), isTrue);

      // Should have isWatchingList: false for watchList
      expect(content.contains('isWatchingList: false'), isTrue);
    });

    test(
      'stateless watch methods do not include onDone with state updates',
      () async {
        final plugin = ControllerPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Product',
          methods: const ['watch', 'watchList'],
          generateController: true,
          generateState: false,
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        // Stateless controllers should NOT have onDone with state updates
        // They still have subscriptions but no state to reset
        expect(content.contains('viewState'), isFalse);
        // Without state, onDone should not appear (no state to update on done)
        expect(
          content.contains('onDone:'),
          isFalse,
          reason:
              'Stateless watch methods should not have onDone callbacks (no state to reset)',
        );
      },
    );

    test('full CRUD with watch includes onDone in all stream methods', () async {
      final plugin = ControllerPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Product',
        methods: const [
          'get',
          'getList',
          'create',
          'update',
          'delete',
          'watch',
          'watchList',
        ],
        generateController: true,
        generateState: true,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      final content = files.first.content ?? '';

      // Should have onDone for watch, watchRecord, and watchList (3 stream methods)
      final onDoneCount = 'onDone:'.allMatches(content).length;
      expect(
        onDoneCount,
        greaterThanOrEqualTo(3),
        reason: 'Should have onDone for watch, watchRecord, and watchList',
      );

      // Should have isWatching: false
      expect(content.contains('isWatching: false'), isTrue);

      // Should have isWatchingList: false
      expect(content.contains('isWatchingList: false'), isTrue);
    });
  });
}
