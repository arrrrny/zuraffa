import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

Future<void> main() async {
  final outputDir = 'example/lib/src';

  final product = CodeGenerator(
    config: GeneratorConfig(
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
      generateData: true,
      generateVpcs: true,
      generateState: true,
      generateDi: true,
      generateMock: true,
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    ),
    outputDir: outputDir,
  );

  final todo = CodeGenerator(
    config: GeneratorConfig(
      name: 'Todo',
      methods: const [
        'get',
        'getList',
        'create',
        'update',
        'delete',
        'watch',
        'watchList',
      ],
      generateData: true,
      generateVpcs: true,
      generateState: true,
      generateDi: true,
      generateMock: true,
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    ),
    outputDir: outputDir,
  );

  await product.generate();
  await todo.generate();
}
