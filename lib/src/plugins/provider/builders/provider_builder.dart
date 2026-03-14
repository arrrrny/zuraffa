import 'package:code_builder/code_builder.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../core/ast/ast_helper.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_analyzer.dart';

/// Generates provider implementation classes.
///
/// Builds Dart classes that implement domain service interfaces, handling
/// data mapping and error handling.
///
/// Example:
/// ```dart
/// final builder = ProviderBuilder(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final file = await builder.generate(GeneratorConfig(name: 'Auth'));
/// ```
class ProviderBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final DartEmitter emitter;

  ProviderBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    DartEmitter? emitter,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       emitter =
           emitter ??
           DartEmitter(orderDirectives: true, useNullSafetySyntax: true);

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final serviceName = config.effectiveService;
    final providerName = config.effectiveProvider;
    final providerSnake = config.providerSnake;
    final serviceSnake = config.serviceSnake;
    if (serviceName == null ||
        providerName == null ||
        providerSnake == null ||
        serviceSnake == null) {
      throw ArgumentError(
        'Service name must be specified via --service or config.service',
      );
    }

    final fileName = '${providerSnake}_provider.dart';
    final filePath = path.join(
      outputDir,
      'data',
      'providers',
      config.effectiveDomain,
      fileName,
    );

    final file = File(filePath);
    final fileExists = file.existsSync();

    if (config.revert && !config.appendToExisting) {
      return FileUtils.deleteFile(
        filePath,
        'provider',
        dryRun: options.dryRun,
        verbose: options.verbose,
      );
    }

    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';
    final methodName = config.getServiceMethodName();

    final returnType = _returnType(config.useCaseType, returnsType);

    final serviceImport = config.methods.isNotEmpty
        ? '../../../domain/services/${config.effectiveDomain}/${serviceSnake}_service.dart'
        : '../../../domain/services/${serviceSnake}_service.dart';

    final directives = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(serviceImport),
    ];

    if (config.methods.isNotEmpty) {
      final entityName = config.name;
      final entitySnake = StringUtils.camelToSnake(entityName);
      directives.add(Directive.import('../../../domain/entities/$entitySnake/$entitySnake.dart'));
    }

    final entityImports = _getPotentialEntityImports([paramsType, returnsType]);
    for (final entityName in entityImports) {
      final entitySnake = StringUtils.camelToSnake(entityName);
      if (EntityAnalyzer.isEnum(entityName, outputDir)) {
        directives.add(
          Directive.import('../../../domain/entities/enums/index.dart'),
        );
      } else {
        final entityPath =
            '../../../domain/entities/$entitySnake/$entitySnake.dart';
        directives.add(Directive.import(entityPath));
      }
    }

    final methods = <Method>[];

    if (config.methods.isNotEmpty) {
      for (final method in config.methods) {
        methods.add(_buildEntityMethod(config, method));
      }
    } else {
      methods.add(
        Method(
          (m) => m
            ..name = methodName
            ..returns = returnType
            ..annotations.add(refer('override'))
            ..modifier =
                config.useCaseType == 'sync' ? null : MethodModifier.async
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
        ),
      );
    }

    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..returns = refer('Stream<bool>')
            ..type = MethodType.getter
            ..annotations.add(refer('override'))
            ..body = refer('const Stream.empty()').returned.statement,
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..returns = refer('Future<void>')
            ..annotations.add(refer('override'))
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..body = Block((b) => b),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'dispose'
            ..returns = refer('Future<void>')
            ..annotations.add(refer('override'))
            ..modifier = MethodModifier.async
            ..body = Block((b) => b),
        ),
      );
    }

    final providerClass = Class(
      (c) => c
        ..name = providerName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer(serviceName))
        ..methods.addAll(methods),
    );

    if (config.appendToExisting && fileExists) {
      var content = await file.readAsString();
      final helper = const AstHelper();

      // Add imports if missing
      for (final directive in directives) {
        final importLine = specLibrary.emitLibrary(
          specLibrary.library(specs: [], directives: [directive]),
        );
        if (!content.contains(importLine.trim()) || config.force) {
          // If force is true, we might want to replace the import, but adding it again is safe if we don't duplicate.
          // Actually, adding if missing is usually enough.
          if (!content.contains(importLine.trim())) {
            content = '${importLine.trim()}\n$content';
          }
        }
      }

      for (final method in methods) {
        final methodSource = method.accept(emitter).toString();
        if (config.revert) {
          content = helper.removeMethodFromClass(
            source: content,
            className: providerName,
            methodName: method.name!,
          );
        } else if (config.force) {
          // Check if method exists to decide between replace and add
          if (content.contains(' ${method.name}(')) {
            content = helper.replaceMethodInClass(
              source: content,
              className: providerName,
              methodName: method.name!,
              methodSource: methodSource,
            );
          } else {
            content = helper.addMethodToClass(
              source: content,
              className: providerName,
              methodSource: methodSource,
            );
          }
        } else {
          // Add method to class if missing
          if (!content.contains(' ${method.name}(')) {
            content = helper.addMethodToClass(
              source: content,
              className: providerName,
              methodSource: methodSource,
            );
          }
        }
      }

      return FileUtils.writeFile(
        filePath,
        content,
        'provider',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: config.revert,
      );
    }

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [providerClass], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'provider',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );
  }

  Method _buildEntityMethod(GeneratorConfig config, String method) {
    final entityName = config.name;
    String name = method;
    Reference returnType;
    List<Parameter> parameters = [];

    switch (method) {
      case 'get':
        returnType = refer('Future<$entityName>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('QueryParams<$entityName>'),
          ),
        );
        break;
      case 'getList':
      case 'list':
        name = 'getList';
        returnType = refer('Future<List<$entityName>>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>'),
          ),
        );
        break;
      case 'create':
        returnType = refer('Future<$entityName>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'item'
              ..type = refer(entityName),
          ),
        );
        break;
      case 'update':
        returnType = refer('Future<$entityName>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(
                'UpdateParams<${config.idFieldType}, ${entityName}Patch>',
              ),
          ),
        );
        break;
      case 'delete':
        returnType = refer('Future<void>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('DeleteParams<${config.idFieldType}>'),
          ),
        );
        break;
      case 'watch':
        returnType = refer('Stream<$entityName>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('QueryParams<$entityName>'),
          ),
        );
        break;
      case 'watchList':
        returnType = refer('Stream<List<$entityName>>');
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>'),
          ),
        );
        break;
      default:
        throw ArgumentError('Unknown entity method: $method');
    }

    return Method(
      (m) => m
        ..name = name
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = method.startsWith('watch') ? null : MethodModifier.async
        ..requiredParameters.addAll(parameters)
        ..body = _buildMethodBody(name),
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
                refer(
                  'UnimplementedError',
                ).call([literalString('$methodName not implemented')]),
              )
              .statement,
        )
        ..statements.add(
          declareFinal(
            'stack',
          ).assign(refer('StackTrace').property('current')).statement,
        )
        ..statements.add(
          refer(
            'logAndHandleError',
          ).call([refer('error'), refer('stack')]).statement,
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
      'Params',
      'QueryParams',
      'ListQueryParams',
      'UpdateParams',
      'DeleteParams',
      'CreateParams',
      'Map',
      'Set',
      'List',
      'Result',
      'AppFailure',
      'Duration',
      'DateTime',
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
    final cleanType = type.replaceAll('?', '');
    final results = <List<String>>[];

    final genericMatch = RegExp(r'(\w+)<(.+)>').firstMatch(cleanType);
    if (genericMatch != null) {
      final innerType = genericMatch.group(2);
      if (innerType != null) {
        results.add(_extractBaseTypes(innerType));
      }
    } else {
      if (cleanType.isNotEmpty && cleanType != 'void') {
        results.add([cleanType]);
      }
    }

    return results.expand((e) => e).toList();
  }
}
