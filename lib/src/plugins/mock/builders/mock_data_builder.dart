import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import 'mock_entity_helper.dart';
import 'mock_type_helper.dart';
import 'mock_value_builder.dart';

class MockDataBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockValueBuilder valueBuilder;
  final MockEntityHelper entityHelper;
  final MockTypeHelper typeHelper;

  MockDataBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    MockValueBuilder? valueBuilder,
    MockEntityHelper? entityHelper,
    MockTypeHelper? typeHelper,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       valueBuilder = valueBuilder ?? MockValueBuilder(outputDir: outputDir),
       entityHelper = entityHelper ?? const MockEntityHelper(),
       typeHelper = typeHelper ?? const MockTypeHelper();

  Future<GeneratedFile> generateMockDataFile(GeneratorConfig config) async {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;

    // Skip generating mock data if the return type is a primitive or completable
    if (config.isCustomUseCase || config.useCaseType == 'completable') {
      final returnsType = config.useCaseType == 'completable'
          ? 'void'
          : config.returnsType;

      if (returnsType != null) {
        final primitives = {
          'String',
          'int',
          'double',
          'bool',
          'void',
          'DateTime',
          'dynamic',
          'Object',
        };
        final baseType = returnsType.replaceAll('?', '');
        if (primitives.contains(baseType) ||
            (baseType.startsWith('List<') &&
                primitives.contains(
                  baseType
                      .substring(5, baseType.length - 1)
                      .replaceAll('?', ''),
                ))) {
          return GeneratedFile(
            path: '',
            content: '',
            action: 'skipped',
            type: 'mock_data',
          );
        }
      }
    }

    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final collectionName = '${entityCamel}s';

    final isEnum = EntityAnalyzer.isEnum(entityName, outputDir);
    final entityFields = EntityAnalyzer.analyzeEntity(entityName, outputDir);

    final mockInstances = valueBuilder.generateMockDataInstances(
      entityName,
      entityFields,
    );

    final imports = entityHelper.collectNestedEntityImports(
      entityFields,
      outputDir,
    );

    final entityImport = isEnum
        ? '../../domain/entities/enums/index.dart'
        : '../../domain/entities/$entitySnake/$entitySnake.dart';

    final directives = <Directive>[
      Directive.import(entityImport),
      ...imports.map((import) => Directive.import(import)),
    ];

    final clazz = Class(
      (c) => c
        ..name = '${entityName}MockData'
        ..docs.add('/// Mock data for $entityName')
        ..fields.addAll([
          Field(
            (f) => f
              ..name = collectionName
              ..static = true
              ..modifier = FieldModifier.final$
              ..type = typeHelper.listOf(entityName)
              ..assignment = literalList(mockInstances).code,
          ),
        ])
        ..methods.addAll([
          Method(
            (m) => m
              ..name = 'sample$entityName'
              ..static = true
              ..type = MethodType.getter
              ..returns = refer(entityName)
              ..lambda = true
              ..body = refer(collectionName).property('first').code,
          ),
          Method(
            (m) => m
              ..name = 'sampleList'
              ..static = true
              ..type = MethodType.getter
              ..returns = typeHelper.listOf(entityName)
              ..lambda = true
              ..body = refer(collectionName).code,
          ),
          Method(
            (m) => m
              ..name = 'emptyList'
              ..static = true
              ..type = MethodType.getter
              ..returns = typeHelper.listOf(entityName)
              ..lambda = true
              ..body = literalList([], refer(entityName)).code,
          ),
          Method(
            (m) => m
              ..name = 'large${entityName}List'
              ..static = true
              ..type = MethodType.getter
              ..returns = typeHelper.listOf(entityName)
              ..lambda = true
              ..body = refer('List').property('generate').call([
                literalNum(100),
                Method(
                  (m) => m
                    ..requiredParameters.add(
                      Parameter((p) => p..name = 'index'),
                    )
                    ..lambda = true
                    ..body = refer(
                      '_create$entityName',
                    ).call([refer('index').operatorAdd(literalNum(1000))]).code,
                ).closure,
              ]).code,
          ),
          Method(
            (m) => m
              ..name = '_create$entityName'
              ..static = true
              ..returns = refer(entityName)
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'seed'
                    ..type = refer('int'),
                ),
              )
              ..body = Block((b) {
                if (EntityAnalyzer.isEnum(entityName, outputDir)) {
                  b.statements.add(
                    refer(entityName)
                        .property('values')
                        .index(
                          refer('seed').operatorEuclideanModulo(
                            refer(
                              entityName,
                            ).property('values').property('length'),
                          ),
                        )
                        .returned
                        .statement,
                  );
                } else {
                  b.statements.add(
                    refer(entityName)
                        .call(
                          const [],
                          valueBuilder.generateConstructorCallArgs(
                            entityFields,
                            useSeeds: true,
                          ),
                        )
                        .returned
                        .statement,
                  );
                }
              }),
          ),
        ]),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
      leadingComment: '// Generated by zfa for: ${config.name}',
    );

    final filePath = '$outputDir/data/mock/${entitySnake}_mock_data.dart';
    return FileUtils.writeFile(
      filePath,
      content,
      'mock_data',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      skipRevertIfExisted: true,
    );
  }
}
