import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;
import '../core/builder/shared/spec_library.dart';
import '../core/generation/generation_context.dart';
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../utils/file_utils.dart';
import '../utils/string_utils.dart';

/// Generates provider implementation files for services.
///
/// Providers are the concrete implementations of service interfaces
/// in the data layer. They handle external API integrations,
/// third-party SDKs, and infrastructure concerns.
///
/// Pattern: Service (domain) -> Provider (data)
/// Analogous to: Repository (domain) -> DataSource (data)
class ProviderGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  ProviderGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  ProviderGenerator.fromContext(GenerationContext context)
    : this(
        config: context.config,
        outputDir: context.outputDir,
        dryRun: context.dryRun,
        force: context.force,
        verbose: context.verbose,
      );

  /// Generates a provider implementation file for a service.
  Future<GeneratedFile> generate() async {
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

    String returnSignature;
    switch (config.useCaseType) {
      case 'stream':
        returnSignature = 'Stream<$returnsType>';
        break;
      case 'completable':
        returnSignature = 'Future<void>';
        break;
      case 'sync':
        returnSignature = returnsType;
        break;
      default: // usecase, background
        returnSignature = 'Future<$returnsType>';
    }

    final directives = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        '../../../domain/services/${serviceSnake}_service.dart',
      ),
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
        ..returns = refer(returnSignature)
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
        ..body = Code(
          _lines([
            'try {',
            "  throw UnimplementedError('$methodName not implemented');",
            '} catch (e, stack) {',
            '  logAndHandleError(e, stack);',
            '  rethrow;',
            '}',
          ]),
        ),
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

  /// Extract potential entity types from type strings for auto-imports.
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
      // Extract base types from generic wrappers like List<X>, Stream<X>, etc.
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

  /// Extract base types from complex type strings.
  List<String> _extractBaseTypes(String type) {
    final results = <List<String>>[];

    // Handle List<X>, Stream<X>, Future<X>, etc.
    final genericMatch = RegExp(r'(\w+)<(.+)>').firstMatch(type);
    if (genericMatch != null) {
      final innerType = genericMatch.group(2)!;
      // Recursively extract from inner types
      results.add(_extractBaseTypes(innerType));
    } else {
      // Simple type
      if (type.isNotEmpty && type != 'void') {
        results.add([type]);
      }
    }

    return results.expand((e) => e).toList();
  }

  String _lines(List<String> lines) => lines.join('\n');
}
