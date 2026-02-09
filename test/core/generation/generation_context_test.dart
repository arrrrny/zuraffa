import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/generator/usecase_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  test('GenerationContext configures generators', () {
    final config = GeneratorConfig(name: 'Product');
    final context = GenerationContext(
      config: config,
      outputDir: 'lib/src',
      dryRun: true,
      force: true,
      verbose: true,
    );

    final generator = UseCaseGenerator.fromContext(context);

    expect(generator.config, equals(config));
    expect(generator.outputDir, equals('lib/src'));
    expect(generator.dryRun, isTrue);
    expect(generator.force, isTrue);
    expect(generator.verbose, isTrue);
  });
}
