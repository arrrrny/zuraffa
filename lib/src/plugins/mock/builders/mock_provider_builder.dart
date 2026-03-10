import 'dart:io';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';
import 'mock_type_helper.dart';

class MockProviderBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockTypeHelper typeHelper;
  final AppendExecutor appendExecutor;

  MockProviderBuilder({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
    SpecLibrary? specLibrary,
    MockTypeHelper? typeHelper,
    AppendExecutor? appendExecutor,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ),
       specLibrary = specLibrary ?? const SpecLibrary(),
       typeHelper = typeHelper ?? const MockTypeHelper(),
       appendExecutor = appendExecutor ?? AppendExecutor();

  Future<GeneratedFile> generateMockProvider(GeneratorConfig config) async {
    final serviceName = config.effectiveService;
    final providerName = config.effectiveProvider;
    final providerSnake = config.providerSnake;
    final serviceSnake = config.serviceSnake;

    if (serviceName == null ||
        providerName == null ||
        providerSnake == null ||
        serviceSnake == null) {
      return GeneratedFile(
        path: '',
        content: '',
        action: 'skip',
        type: 'mock_provider',
      );
    }

    final mockProviderName = providerName.replaceAll(
      'Provider',
      'MockProvider',
    );
    final fileName = '${providerSnake}_mock_provider.dart';
    final filePath = path.join(
      outputDir,
      'data',
      'providers',
      config.effectiveDomain,
      fileName,
    );

    final targetEntity = config.isCustomUseCase && config.returnsType != null
        ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
              config.name
        : config.name;

    final returns = config.returnsType ?? 'void';
    final baseReturns = returns.replaceAll('?', '');
    final isList = baseReturns.startsWith('List<');

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
    final isPrimitive =
        primitives.contains(baseReturns) ||
        (isList &&
            primitives.contains(
              baseReturns
                  .substring(5, baseReturns.length - 1)
                  .replaceAll('?', ''),
            ));

    final directives = [
      Directive.import('dart:async'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import('../../../domain/services/${serviceSnake}_service.dart'),
    ];

    final entityTypes = <String>[];
    if (config.returnsType != null) {
      entityTypes.addAll(EntityUtils.extractEntityTypes(config.returnsType!));
    }
    if (config.paramsType != null) {
      entityTypes.addAll(EntityUtils.extractEntityTypes(config.paramsType!));
    }

    for (final type in entityTypes.toSet()) {
      final snake = StringUtils.camelToSnake(type);
      directives.add(
        Directive.import('../../../domain/entities/$snake/$snake.dart'),
      );
    }

    if (!isPrimitive) {
      directives.add(
        Directive.import(
          '../../mock/${StringUtils.camelToSnake(targetEntity)}_mock_data.dart',
        ),
      );
    }

    final delayField = Field(
      (f) => f
        ..name = '_delay'
        ..modifier = FieldModifier.final$
        ..type = refer('Duration'),
    );

    final constructor = Constructor(
      (c) => c
        ..optionalParameters.add(
          Parameter(
            (p) => p
              ..name = 'delay'
              ..type = refer('Duration?'),
          ),
        )
        ..initializers.add(
          refer('_delay')
              .assign(
                refer('delay').ifNullThen(
                  refer(
                    'Duration',
                  ).constInstance(const [], {'milliseconds': literalNum(100)}),
                ),
              )
              .code,
        ),
    );

    final methods = <Method>[];
    methods.addAll(_generateMockProviderMethods(config));

    final clazz = Class(
      (c) => c
        ..name = mockProviderName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer(serviceName))
        ..docs.add('/// Mock provider for $serviceName')
        ..fields.add(delayField)
        ..constructors.add(constructor)
        ..methods.addAll(methods),
    );

    if (config.appendToExisting && File(filePath).existsSync()) {
      final existing = await File(filePath).readAsString();
      var updated = existing;
      for (final method in methods) {
        final methodSource = specLibrary.emitSpec(method);
        final result = appendExecutor.execute(
          AppendRequest.method(
            source: updated,
            className: mockProviderName,
            memberSource: methodSource,
          ),
        );
        updated = result.source;
      }
      return FileUtils.writeFile(
        filePath,
        updated,
        'mock_provider',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: config.revert,
      );
    }

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'mock_provider',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );
  }

  List<Method> _generateMockProviderMethods(GeneratorConfig config) {
    final methods = <Method>[];
    final methodName = config.getServiceMethodName();
    final returns = config.returnsType ?? 'void';
    final baseReturns = returns.replaceAll('?', '');
    final isList = baseReturns.startsWith('List<');

    final targetEntity = config.isCustomUseCase && config.returnsType != null
        ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
              config.name
        : config.name;

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
    final isPrimitive =
        primitives.contains(baseReturns) ||
        (isList &&
            primitives.contains(
              baseReturns
                  .substring(5, baseReturns.length - 1)
                  .replaceAll('?', ''),
            ));

    final mockDataClass = '${targetEntity}MockData';
    final sampleProperty = 'sample$targetEntity';

    final isStream = config.useCaseType == 'stream';
    final returnType = isStream ? 'Stream<$returns>' : 'Future<$returns>';

    methods.add(
      Method(
        (m) => m
          ..name = methodName
          ..annotations.add(refer('override'))
          ..returns = refer(returnType)
          ..modifier = isStream ? null : MethodModifier.async
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = 'params'
                ..type = refer(config.paramsType ?? 'NoParams'),
            ),
          )
          ..body = Block(
            (b) => b
              ..statements.addAll([
                refer('logger').property('info').call([
                  literalString('$methodName called with params: \$params'),
                ]).statement,
                if (isStream) ...[
                  refer('Stream')
                      .property('fromFuture')
                      .call([
                        refer('Future').property('delayed').call([
                          refer('_delay'),
                          Method(
                            (mm) => mm
                              ..lambda = true
                              ..body = isPrimitive
                                  ? (isList
                                        ? literalList([]).code
                                        : (baseReturns == 'void'
                                              ? literalNull.code
                                              : _primitiveValue(
                                                  baseReturns,
                                                ).code))
                                  : (isList
                                        ? refer(
                                            mockDataClass,
                                          ).property('sampleList').code
                                        : refer(
                                            mockDataClass,
                                          ).property(sampleProperty).code),
                          ).closure,
                        ]),
                      ])
                      .returned
                      .statement,
                ] else ...[
                  refer('Future')
                      .property('delayed')
                      .call([refer('_delay')])
                      .awaited
                      .statement,
                  if (isPrimitive) ...[
                    if (isList)
                      literalList([]).returned.statement
                    else if (baseReturns == 'void')
                      literalNull.returned.statement
                    else
                      _primitiveValue(baseReturns).returned.statement,
                  ] else if (isList) ...[
                    refer(
                      mockDataClass,
                    ).property('sampleList').returned.statement,
                  ] else ...[
                    refer(
                      mockDataClass,
                    ).property(sampleProperty).returned.statement,
                  ],
                ],
              ]),
          ),
      ),
    );

    return methods;
  }

  Expression _primitiveValue(String type) {
    switch (type) {
      case 'String':
        return literalString('mock_value');
      case 'int':
        return literalNum(1);
      case 'double':
        return literalNum(1.0);
      case 'bool':
        return literalBool(true);
      case 'DateTime':
        return refer('DateTime').property('now').call([]);
      default:
        return literalNull;
    }
  }
}
