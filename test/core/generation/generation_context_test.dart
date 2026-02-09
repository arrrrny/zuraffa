import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/generator/usecase_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'dart:io';

void main() {
  test('GenerationContext configures generators', () {
    final config = GeneratorConfig(name: 'Product');
    final tempDir = Directory.systemTemp.createTempSync('zuraffa_ctx_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final context = GenerationContext.create(
      config: config,
      outputDir: 'lib/src',
      dryRun: true,
      force: true,
      verbose: true,
      root: tempDir.path,
    );

    final generator = UseCaseGenerator.fromContext(context);

    expect(generator.config, equals(config));
    expect(generator.outputDir, equals('lib/src'));
    expect(generator.dryRun, isTrue);
    expect(generator.force, isTrue);
    expect(generator.verbose, isTrue);
    expect(context.fileSystem, isNotNull);
    expect(context.store, isNotNull);
    expect(context.progress, isA<CliProgressReporter>());
  });

  test('GenerationContext file system and store are usable', () async {
    final config = GeneratorConfig(name: 'Order');
    final tempDir = await Directory.systemTemp.createTemp('zuraffa_ctx_');
    addTearDown(() => tempDir.delete(recursive: true));
    final context = GenerationContext.create(
      config: config,
      outputDir: 'lib/src',
      root: tempDir.path,
    );

    await context.fileSystem.write('foo/bar.txt', 'hello');
    final content = await context.fileSystem.read('foo/bar.txt');
    expect(content, equals('hello'));

    context.store.set('value', 123);
    expect(context.store.get<int>('value'), equals(123));
  });
}
