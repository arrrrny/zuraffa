import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import 'baseline_generator.dart';

void main() {
  test('legacy and plugin outputs match for entity with data', () async {
    final scenario = BaselineScenario(
      name: 'product_basic',
      config: GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'getList'],
        generateData: true,
      ),
    );
    final outputDir = _tempOutputDir();

    final baselineOutputs = await BaselineGenerator().generate(
      scenario,
      outputDir: outputDir,
    );
    final currentOutputs = await _generateCurrentOutputs(
      scenario.config,
      outputDir,
    );

    expect(currentOutputs.keys.toSet(), equals(baselineOutputs.keys.toSet()));

    for (final entry in baselineOutputs.entries) {
      expect(currentOutputs[entry.key], equals(entry.value), reason: entry.key);
    }
  });

  test('generator config accepts legacy json keys', () {
    final config = GeneratorConfig.fromJson({
      'name': 'Order',
      'methods': ['get'],
      'repo_method': 'fetch',
      'service_method': 'send',
      'append': true,
      'data': true,
      'id_field': 'orderId',
      'id_field_type': 'int',
      'query_field_type': 'NoParams',
      'cache': true,
      'cache_policy': 'ttl',
      'ttl': 15,
      'mock': true,
      'generate_route': true,
    }, 'Order');

    expect(config.name, equals('Order'));
    expect(config.repoMethod, equals('fetch'));
    expect(config.serviceMethod, equals('send'));
    expect(config.appendToExisting, isTrue);
    expect(config.generateData, isTrue);
    expect(config.idField, equals('orderId'));
    expect(config.idType, equals('int'));
    expect(config.queryFieldType, equals('NoParams'));
    expect(config.enableCache, isTrue);
    expect(config.cachePolicy, equals('ttl'));
    expect(config.ttlMinutes, equals(15));
    expect(config.generateMock, isTrue);
    expect(config.generateRoute, isTrue);
  });
}

Future<Map<String, String>> _generateCurrentOutputs(
  GeneratorConfig config,
  String outputDir,
) async {
  final generator = CodeGenerator(
    config: config,
    outputDir: outputDir,
    dryRun: true,
    force: true,
    verbose: false,
  );
  final result = await generator.generate();

  final outputs = <String, String>{};
  for (final file in result.files) {
    final relative = path.relative(file.path, from: outputDir);
    outputs[relative] = file.content ?? '';
  }
  return outputs;
}

String _tempOutputDir() {
  return path.join(
    Directory.systemTemp.path,
    'zfa_regression_${DateTime.now().microsecondsSinceEpoch}',
    'lib',
    'src',
  );
}
