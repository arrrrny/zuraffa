import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  test('CodeBuilderFactory creates generators with context', () {
    final config = GeneratorConfig(name: 'Order');
    final context = GenerationContext.create(
      config: config,
      outputDir: 'lib/src',
      dryRun: true,
      force: true,
      verbose: true,
    );

    final factory = CodeBuilderFactory(context);

    final repoGenerator = factory.repository();
    final usecaseGenerator = factory.usecase();
    final diGenerator = factory.di();

    expect(repoGenerator.config, equals(config));
    expect(usecaseGenerator.config, equals(config));
    expect(diGenerator.config, equals(config));
    expect(repoGenerator.outputDir, equals('lib/src'));
    expect(repoGenerator.dryRun, isTrue);
    expect(repoGenerator.force, isTrue);
    expect(repoGenerator.verbose, isTrue);
  });
}
