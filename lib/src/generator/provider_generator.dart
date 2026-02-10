import 'package:path/path.dart' as path;
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

  ProviderGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

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

    // Determine return type based on usecase type
    String returnSignature;
    String implementationComment;
    switch (config.useCaseType) {
      case 'stream':
        returnSignature = 'Stream<$returnsType>';
        implementationComment =
            '''
    // TODO: Implement stream logic
    // Return a stream of $returnsType
    throw UnimplementedError('$methodName not implemented');''';
        break;
      case 'completable':
        returnSignature = 'Future<void>';
        implementationComment = '''
    // TODO: Implement void operation logic
    throw UnimplementedError('$methodName not implemented');''';
        break;
      case 'sync':
        returnSignature = returnsType;
        implementationComment =
            '''
    // TODO: Implement synchronous logic
    // Return $returnsType immediately
    throw UnimplementedError('$methodName not implemented');''';
        break;
      default: // usecase, background
        returnSignature = 'Future<$returnsType>';
        implementationComment =
            '''
    // TODO: Implement business logic
    // Return $returnsType
    throw UnimplementedError('$methodName not implemented');''';
    }

    // Build method signature
    final methodSignature = paramsType == 'NoParams'
        ? (config.useCaseType == 'sync'
              ? '  @override\n  $returnSignature $methodName() {'
              : '  @override\n  $returnSignature $methodName() async {')
        : (config.useCaseType == 'sync'
              ? '  @override\n  $returnSignature $methodName($paramsType params) {'
              : '  @override\n  $returnSignature $methodName($paramsType params) async {');

    // Build imports
    final imports = <String>[];
    imports.add("import 'package:zuraffa/zuraffa.dart';");

    // Service is at domain/services/{service_name}_service.dart
    // Provider is at data/providers/{domain}/{provider_name}_provider.dart
    // So we need: ../../../domain/services/{service_name}_service.dart
    imports.add(
      "import '../../../domain/services/${serviceSnake}_service.dart';",
    );

    // Auto-import potential entity types from params and returns
    final entityImports = _getPotentialEntityImports([paramsType, returnsType]);
    for (final entityImport in entityImports) {
      final entitySnake = StringUtils.camelToSnake(entityImport);
      final entityPath =
          '../../../domain/entities/$entitySnake/$entitySnake.dart';
      imports.add("import '$entityPath';");
    }

    final cliCommand =
        '// zfa generate ${config.name} --service=${config.service} --domain=${config.effectiveDomain} --params=$paramsType --returns=$returnsType${config.useCaseType != 'usecase' ? ' --type=${config.useCaseType}' : ''}${config.serviceMethod != null ? ' --service-method=${config.serviceMethod}' : ''} --data';

    final content =
        '''
$cliCommand

${imports.join('\n')}

/// Provider implementation of [$serviceName].
///
/// This class implements the service interface in the data layer,
/// handling external API integrations, third-party SDKs, or
/// infrastructure operations.
///
/// ## Implementation Notes
/// - Add external service client as a dependency (e.g., SmtpClient, StripeClient)
/// - Implement error handling specific to the external service
/// - Add retry logic, rate limiting, or caching as needed
///
/// ## Example
/// ```dart
/// class SmtpEmailProvider implements EmailService {
///   final SmtpClient _client;
///
///   SmtpEmailProvider(this._client);
///
///   @override
///   Future<void> sendEmail(EmailMessage params) async {
///     await _client.send(
///       to: params.to,
///       subject: params.subject,
///       body: params.body,
///     );
///   }
/// }
/// ```
class $providerName with Loggable, FailureHandler implements $serviceName {
${_generateMethodDocstring(methodName, paramsType, returnsType)}
$methodSignature
    try {
$implementationComment
    } catch (e, stack) {
      logAndHandleError(e, stack);
      rethrow;
    }
  }
}
''';

    return FileUtils.writeFile(
      filePath,
      content,
      'provider',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  String _generateMethodDocstring(
    String methodName,
    String paramsType,
    String returnsType,
  ) {
    final paramsDoc = paramsType == 'NoParams'
        ? ''
        : '\n  /// [params] - The parameters for the operation';

    return '''  /// Implements the [$methodName] method.
  ///
  ///$paramsDoc
  ///
  /// Returns a [$returnsType].
  ///
  /// Throws [Exception] if the operation fails.''';
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
}
