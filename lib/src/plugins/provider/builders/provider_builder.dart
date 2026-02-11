import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

class ProviderBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  ProviderBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final serviceName = config.effectiveService!;
    final providerName = config.effectiveProvider!;
    final providerSnake = config.providerSnake!;
    final serviceSnake = config.serviceSnake!;

    final fileName = '${providerSnake}_provider.dart';
    final filePath = path.join(
      outputDir,
      'data',
      'providers',
      config.effectiveDomain,
      fileName,
    );

    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';
    final methodName = config.getServiceMethodName();

    final returnType = _returnType(config.useCaseType, returnsType);

    final directives = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import('../../../domain/services/${serviceSnake}_service.dart'),
    ];

    final entityImports = _getPotentialEntityImports([paramsType, returnsType]);
    for (final entityImport in entityImports) {
      final entitySnake = StringUtils.camelToSnake(entityImport);
      final entityPath =
          '../../../domain/entities/$entitySnake/$entitySnake.dart';
      directives.add(Directive.import(entityPath));
    }

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = config.useCaseType == 'sync' ? null : MethodModifier.async
        ..requiredParameters.addAll(
          paramsType == 'NoParams'
              ? const []
              : [
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(paramsType),
                  ),
                ],
        )
        ..body = _buildMethodBody(methodName),
    );

    final providerClass = Class(
      (c) => c
        ..name = providerName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer(serviceName))
        ..methods.add(method),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [providerClass], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'provider',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Reference _returnType(String useCaseType, String returnsType) {
    switch (useCaseType) {
      case 'stream':
        return TypeReference(
          (b) => b
            ..symbol = 'Stream'
            ..types.add(refer(returnsType)),
        );
      case 'completable':
        return TypeReference(
          (b) => b
            ..symbol = 'Future'
            ..types.add(refer('void')),
        );
      case 'sync':
        return refer(returnsType);
      default:
        return TypeReference(
          (b) => b
            ..symbol = 'Future'
            ..types.add(refer(returnsType)),
        );
    }
  }

  Code _buildMethodBody(String methodName) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('error')
              .assign(
                refer('UnimplementedError')
                    .call([literalString('$methodName not implemented')]),
              )
              .statement,
        )
        ..statements.add(
          declareFinal('stack')
              .assign(refer('StackTrace').property('current'))
              .statement,
        )
        ..statements.add(
          refer('logAndHandleError')
              .call([refer('error'), refer('stack')]).statement,
        )
        ..statements.add(refer('error').thrown.statement),
    );
  }

  List<String> _getPotentialEntityImports(List<String> types) {
    final entities = <String>[];
    final primitives = {
      'void',
      'String',
      'int',
      'double',
      'bool',
      'dynamic',
      'Object',
      'NoParams',
      'Map',
      'Set',
    };

    for (final type in types) {
      final baseTypes = _extractBaseTypes(type);
      for (final baseType in baseTypes) {
        if (!primitives.contains(baseType) &&
            !baseType.startsWith('Map<') &&
            !baseType.startsWith('Set<')) {
          entities.add(baseType);
        }
      }
    }

    return entities.toSet().toList();
  }

  List<String> _extractBaseTypes(String type) {
    final results = <List<String>>[];

    final genericMatch = RegExp(r'(\w+)<(.+)>').firstMatch(type);
    if (genericMatch != null) {
      final innerType = genericMatch.group(2)!;
      results.add(_extractBaseTypes(innerType));
    } else {
      if (type.isNotEmpty && type != 'void') {
        results.add([type]);
      }
    }

    return results.expand((e) => e).toList();
  }
}
