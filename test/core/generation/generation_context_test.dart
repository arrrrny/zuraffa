import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/context/progress_reporter.dart';
import 'package:zuraffa/src/core/generation/generation_context.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  group('GenerationContext', () {
    test('creates context with defaults', () {
      final config = GeneratorConfig(name: 'Product');
      final context = GenerationContext.create(config: config);

      expect(context.config, equals(config));
      expect(context.outputDir, equals('lib/src'));
      expect(context.dryRun, isFalse);
      expect(context.force, isFalse);
      expect(context.verbose, isFalse);
      expect(context.progress, isA<NullProgressReporter>());
    });

    test('creates context with verbose progress reporter', () {
      final config = GeneratorConfig(name: 'Order');
      final context = GenerationContext.create(config: config, verbose: true);

      expect(context.progress, isA<CliProgressReporter>());
    });

    test('uses provided progress reporter', () {
      final config = GeneratorConfig(name: 'User');
      final reporter = _TestProgressReporter();
      final context = GenerationContext.create(
        config: config,
        progressReporter: reporter,
      );

      expect(context.progress, same(reporter));
    });
  });
}

class _TestProgressReporter implements ProgressReporter {
  @override
  void report(ProgressReport report) {}

  @override
  void started(String message, int totalSteps) {}

  @override
  void update(String currentStep) {}

  @override
  void completed() {}

  @override
  void failed(String error) {}

  @override
  void warning(String message) {}

  @override
  void info(String message) {}
}
