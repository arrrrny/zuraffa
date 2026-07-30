import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as p;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/context/file_system.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

// ---------------------------------------------------------------------------
// UseCase descriptor — extracted from scanning source files
// ---------------------------------------------------------------------------

/// Describes a single UseCase discovered in the entity's usecase folder.
class _UseCaseDescriptor {
  /// PascalCase name of the UseCase class, e.g. `GetProductUseCase`
  final String className;

  /// camelCase method name derived from class name, e.g. `getProduct`
  final String methodName;

  /// The type parameter T from `extends UseCase<T, P>` or `StreamUseCase<T,P>`
  final String returnType;

  /// The type parameter P (params type)
  final String paramsType;

  /// True when extends `StreamUseCase`
  final bool isStream;

  /// True when the params type has a Zorphy entity directory
  /// (i.e. `fromJson` is available for JSON deserialization).
  final bool hasFromJson;

  const _UseCaseDescriptor({
    required this.className,
    required this.methodName,
    required this.returnType,
    required this.paramsType,
    required this.isStream,
    required this.hasFromJson,
  });
}

/// Generates VM Service extension bridge files for Zuraffa entities.
///
/// Given an entity name (e.g. `Product`), scans `lib/src/domain/usecases/{snake}/`
/// for all UseCase subclasses and generates a bridge file at
/// `lib/src/api/bridges/{snake}_api_bridge.dart`.
///
/// The generated file contains:
/// - One top-level `register{Entity}ApiBridge()` function guarded by
///   `kReleaseMode` / `kProfileMode` checks.
/// - One private handler function per discovered UseCase.
class ApiBridgeBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final FileSystem fileSystem;
  final SpecLibrary specLibrary;

  ApiBridgeBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
    SpecLibrary? specLibrary,
  }) : fileSystem = fileSystem ?? FileSystem.create(),
       specLibrary = specLibrary ?? const SpecLibrary();

  /// Generate the bridge file for the entity described by [config].
  ///
  /// Returns an empty list when no UseCases are found — never throws.
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final domain = config.domain ?? entitySnake; // e.g. "product"

    // Scan for UseCases in the entity's usecase folder.
    final useCases = _discoverUseCases(entityName, entitySnake);

    if (useCases.isEmpty) {
      print(
        '⚠️  No UseCases found for $entityName in '
        'lib/src/domain/usecases/$entitySnake/. '
        'Ensure UseCases extend UseCase<T,P> or StreamUseCase<T,P>.',
      );
      return [];
    }

    final content = _generateBridgeFile(
      entityName: entityName,
      entitySnake: entitySnake,
      domain: domain,
      useCases: useCases,
      outputDir: outputDir,
    );

    final outPath = p.join(
      outputDir,
      'api',
      'bridges',
      '${entitySnake}_api_bridge.dart',
    );

    final generated = await FileUtils.writeFile(
      outPath,
      content,
      'api_bridge',
      force: config.force,
      dryRun: config.dryRun,
      verbose: config.verbose,
      fileSystem: fileSystem,
    );

    return [generated];
  }

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// Scan `lib/src/domain/usecases/{entitySnake}/` for UseCase subclasses.
  List<_UseCaseDescriptor> _discoverUseCases(
    String entityName,
    String entitySnake,
  ) {
    final usecaseDir = p.join(outputDir, 'domain', 'usecases', entitySnake);

    if (!fileSystem.existsSync(usecaseDir)) {
      return [];
    }

    final descriptors = <_UseCaseDescriptor>[];

    try {
      final files = Directory(usecaseDir).listSync(recursive: false);
      for (final file in files) {
        if (file is! File || !file.path.endsWith('.dart')) continue;

        final content = fileSystem.readSync(file.path);
        final descriptor = _parseUseCaseFile(content);
        if (descriptor != null) {
          // Only include if params can be deserialized from JSON.
          if (descriptor.hasFromJson) {
            descriptors.add(descriptor);
          } else {
            print(
              '⚠️  Skipping ${descriptor.className}: params type '
              '${descriptor.paramsType} has no fromJson — '
              'create a Zorphy entity or add a factory.',
            );
          }
        }
      }
    } catch (_) {
      // If the directory can't be read, return empty — generate() will report.
    }

    return descriptors;
  }

  /// Parse a single UseCase file and return its descriptor, or null if not a UseCase.
  _UseCaseDescriptor? _parseUseCaseFile(String content) {
    // Match: class FooUseCase extends UseCase<ReturnType, ParamsType> {
    //    or: class WatchFooUseCase extends StreamUseCase<ReturnType, ParamsType> {
    // The type-argument list is captured whole and split at the top-level
    // comma so nested generics survive intact:
    // `UseCase<List<Product>, UpdateParams<String, ProductPatch>>` must yield
    // `List<Product>` and `UpdateParams<String, ProductPatch>`, not truncated
    // fragments that would produce uncompilable bridges.
    final re = RegExp(
      r'class\s+(\w+UseCase)\s+extends\s+(StreamUseCase|UseCase)<(.+)>\s*\{',
    );
    final match = re.firstMatch(content);
    if (match == null) return null;

    final typeArgs = match.group(3)!;
    final comma = _topLevelComma(typeArgs);
    if (comma == -1) return null;

    final className = match.group(1)!.trim();
    final baseClass = match.group(2)!.trim();
    final returnType = typeArgs.substring(0, comma).trim();
    final paramsType = typeArgs.substring(comma + 1).trim();
    final isStream = baseClass == 'StreamUseCase';

    // Convert `GetProductUseCase` → `getProduct`
    final methodName = _classNameToMethodName(className);

    return _UseCaseDescriptor(
      className: className,
      methodName: methodName,
      returnType: returnType,
      paramsType: paramsType,
      isStream: isStream,
      hasFromJson: _paramsTypeHasFromJson(paramsType),
    );
  }

  /// Index of the first comma at generic nesting depth 0 in [s], or -1.
  int _topLevelComma(String s) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == '<') depth++;
      if (ch == '>') depth--;
      if (ch == ',' && depth == 0) return i;
    }
    return -1;
  }

  /// Returns true if [paramsType] is NoParams, a primitive, a known Zuraffa
  /// core type with fromJson (e.g. QueryParams), or has a Zorphy entity
  /// directory (meaning `fromJson` is available).
  ///
  /// Strips generic type parameters before checking (e.g.
  /// `QueryParams<Product>` → checks `QueryParams`).
  bool _paramsTypeHasFromJson(String paramsType) {
    // Strip generic params: QueryParams<Product> → QueryParams
    final baseType = paramsType.split('<').first.trim();
    if (_isNoParams(baseType) || _isPrimitive(baseType)) return true;

    // Known Zuraffa core types that have fromJson
    if (baseType == 'QueryParams' ||
        baseType == 'QueryParamsPatch' ||
        baseType == 'ListQueryParams') {
      return true;
    }

    final paramSnake = StringUtils.camelToSnake(baseType);
    final entityDir = '$outputDir/domain/entities/$paramSnake';
    return fileSystem.existsSync(entityDir);
  }

  /// `GetProductUseCase` → `getProduct`
  String _classNameToMethodName(String className) {
    // Remove trailing "UseCase"
    var name = className.replaceAll(RegExp(r'UseCase$'), '');
    if (name.isEmpty) return className;
    // Lowercase first character
    return name[0].toLowerCase() + name.substring(1);
  }

  // ---------------------------------------------------------------------------
  // Code generation
  // ---------------------------------------------------------------------------

  String _generateBridgeFile({
    required String entityName,
    required String entitySnake,
    required String domain,
    required List<_UseCaseDescriptor> useCases,
    required String outputDir,
  }) {
    final buf = StringBuffer();

    // Header
    buf.writeln('// GENERATED BY `zfa api $entityName` — DO NOT EDIT BY HAND');
    buf.writeln(
      '// Regenerate with: zfa api $entityName (--force to overwrite)',
    );
    buf.writeln();

    // Imports
    buf.writeln("import 'dart:convert';");
    buf.writeln("import 'dart:developer' as developer;");
    buf.writeln();
    buf.writeln(
      "import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;",
    );
    buf.writeln("import 'package:zuraffa/zuraffa.dart';");
    buf.writeln();

    // UseCase imports — strip "UseCase" suffix, snake_case the rest,
    // then re-append "usecase" as one word (matches DI command convention).
    final usecaseImportBase = 'domain/usecases/$entitySnake';
    for (final uc in useCases) {
      final nameWithoutSuffix = uc.className.replaceAll('UseCase', '');
      final fileName = '${StringUtils.camelToSnake(nameWithoutSuffix)}_usecase';
      buf.writeln("import '../../$usecaseImportBase/$fileName.dart';");
    }
    buf.writeln();

    // Entity import (for return types that have toJson)
    buf.writeln(
      "import '../../domain/entities/$entitySnake/$entitySnake.dart';",
    );

    // Param type imports — only for types that exist as Zorphy entities
    // (have their own directory under domain/entities/).
    // Non-entity param classes (like *Params in the usecases directory)
    // must be manually imported if needed.
    // Seeded with the entity itself — its import is already emitted above.
    final addedParamImports = <String>{entitySnake};
    for (final uc in useCases) {
      final pt = uc.paramsType;
      if (_isNoParams(pt) || _isPrimitive(pt)) continue;
      // Resolve imports by the base type: `QueryParams<Product>` needs no
      // entity-dir lookup, `Product` must not duplicate the entity import.
      final paramSnake = StringUtils.camelToSnake(pt.split('<').first.trim());
      if (!addedParamImports.add(paramSnake)) continue;

      // Only import if a domain/entities/{snake} directory exists.
      final entityDir = '$outputDir/domain/entities/$paramSnake';
      if (fileSystem.existsSync(entityDir)) {
        buf.writeln(
          "import '../../domain/entities/$paramSnake/$paramSnake.dart';"
          '  // param: $pt',
        );
      }
    }
    buf.writeln();

    // Top-level GetIt instance for handler resolution
    buf.writeln('final getIt = GetIt.instance;');
    buf.writeln();

    // Registration function
    buf.writeln(
      '/// Registers all $entityName UseCase extensions with [ZuraffaApiBridge].',
    );
    buf.writeln('///');
    buf.writeln(
      '/// Prerequisites: call [ZuraffaApiBridge.init] first, configure DI,',
    );
    buf.writeln('/// then call this function before `runApp()`.');
    buf.writeln('void register${entityName}ApiBridge() {');
    buf.writeln('  if (kReleaseMode) return;');
    buf.writeln('  if (kProfileMode && !Zuraffa.enableApiInProfile) return;');
    buf.writeln();

    for (final uc in useCases) {
      final method = 'ext.zuraffa.$domain.${uc.methodName}';
      final paramsMap = _buildParamsMap(uc.paramsType, isStream: uc.isStream);
      buf.writeln('  ZuraffaApiBridge.registerEndpoint(');
      buf.writeln('    endpoint: const ApiEndpoint(');
      buf.writeln("      method: '$method',");
      buf.writeln("      domain: '$domain',");
      buf.writeln("      usecase: '${uc.methodName}',");
      buf.writeln('      params: $paramsMap,');
      buf.writeln("      returns: '${uc.returnType}',");
      buf.writeln('      isStream: ${uc.isStream},');
      buf.writeln('    ),');
      buf.writeln('    handler: _handle${_capitalize(uc.methodName)},');
      buf.writeln('  );');
    }

    buf.writeln('}');
    buf.writeln();

    // Handler functions
    for (final uc in useCases) {
      buf.write(_generateHandler(uc, domain));
      buf.writeln();
    }

    return buf.toString();
  }

  /// Emit a [Method] spec as formatted source via [specLibrary].
  String _methodToString(Method method) {
    return specLibrary.emitSpec(method);
  }

  /// Build a shared try-catch handler body wrapping the given [tryStatements].
  /// The catch block logs via `developer.log` and returns an error response.
  Block _handlerBlock(String method, List<Code> tryStatements) {
    return Block(
      (b) => b
        ..statements.addAll([
          const Code('try {'),
          ...tryStatements,
          Code("""
  } catch (e, st) {
    developer.log('Bridge error: $method',
      error: e, stackTrace: st,
      name: 'ZuraffaApiBridge');
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }"""),
        ]),
    );
  }

  /// Emit a handler function as a `Method` with the standard
  /// `Future<developer.ServiceExtensionResponse>` signature.
  String _emitHandler(String handlerName, Block body) {
    return _methodToString(
      Method(
        (m) => m
          ..name = handlerName
          ..returns = refer('Future<developer.ServiceExtensionResponse>')
          ..modifier = MethodModifier.async
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = 'method'
                ..type = refer('String'),
            ),
          )
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = 'args'
                ..type = refer('Map<String, String>'),
            ),
          )
          ..body = body,
      ),
    );
  }

  String _generateHandler(_UseCaseDescriptor uc, String domain) {
    final handlerName = '_handle${_capitalize(uc.methodName)}';
    final method = 'ext.zuraffa.$domain.${uc.methodName}';

    if (uc.isStream) {
      return _generateStreamHandler(uc, handlerName, method);
    } else if (_isQueryParams(uc.paramsType)) {
      return _generateQueryParamsHandler(uc, handlerName, method);
    } else if (_isListQueryParams(uc.paramsType)) {
      return _generateListQueryParamsHandler(uc, handlerName, method);
    } else if (_isPrimitive(uc.paramsType) || _isNoParams(uc.paramsType)) {
      return _generateSimpleHandler(uc, handlerName, method);
    } else {
      return _generateComplexHandler(uc, handlerName, method);
    }
  }

  /// Handler for UseCases with primitive or NoParams params.
  String _generateSimpleHandler(
    _UseCaseDescriptor uc,
    String handlerName,
    String method,
  ) {
    final paramExtract = _generatePrimitiveParamExtraction(uc.paramsType);
    final tryStmts = <Code>[];

    if (_isNoParams(uc.paramsType)) {
      tryStmts.add(
        Code("""
    final useCase = getIt<${uc.className}>();
    final result = await useCase(const NoParams());
    return ZuraffaApiBridge.serializeResult(
      result,
      (v) => _toJsonFor${_capitalize(uc.methodName)}(v),
    );"""),
      );
    } else {
      tryStmts.add(
        Code("""
    $paramExtract
    final useCase = getIt<${uc.className}>();
    final result = await useCase(params);
    return ZuraffaApiBridge.serializeResult(
      result,
      (v) => _toJsonFor${_capitalize(uc.methodName)}(v),
    );"""),
      );
    }

    return '${_emitHandler(handlerName, _handlerBlock(method, tryStmts))}\n'
        '${_generateToJsonHelper(uc)}';
  }

  /// Handler for UseCases with `QueryParams<Entity>` params (entity-lookup-by-id).
  String _generateQueryParamsHandler(
    _UseCaseDescriptor uc,
    String handlerName,
    String method,
  ) {
    final entityName = _extractEntityFromGeneric(uc.paramsType);
    final tryStmts = <Code>[
      Code("""
    final id = args['id'];
    if (id == null || id.isEmpty) {
      return ZuraffaApiBridge.errorResponse('badRequest', 'id is required');
    }
    final params = ${uc.paramsType}(filter: ${entityName}Fields.id.eq(id));
    final useCase = getIt<${uc.className}>();
    final result = await useCase(params);
    return ZuraffaApiBridge.serializeResult(
      result,
      (v) => _toJsonFor${_capitalize(uc.methodName)}(v),
    );"""),
    ];

    return '${_emitHandler(handlerName, _handlerBlock(method, tryStmts))}\n'
        '${_generateToJsonHelper(uc)}';
  }

  /// Handler for UseCases with `ListQueryParams<Entity>` params — full-list
  /// queries take no arguments (matches the hand-written example bridges).
  String _generateListQueryParamsHandler(
    _UseCaseDescriptor uc,
    String handlerName,
    String method,
  ) {
    final entityName = _extractEntityFromGeneric(uc.paramsType);
    final tryStmts = <Code>[
      Code("""
    final params = ListQueryParams<$entityName>();
    final useCase = getIt<${uc.className}>();
    final result = await useCase(params);
    return ZuraffaApiBridge.serializeResult(
      result,
      (v) => _toJsonFor${_capitalize(uc.methodName)}(v),
    );"""),
    ];

    return '${_emitHandler(handlerName, _handlerBlock(method, tryStmts))}\n'
        '${_generateToJsonHelper(uc)}';
  }

  /// Handler for UseCases with complex (JSON-deserializable) params.
  String _generateComplexHandler(
    _UseCaseDescriptor uc,
    String handlerName,
    String method,
  ) {
    final tryStmts = <Code>[
      Code("""
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(args['args'] ?? '{}') as Map<String, dynamic>;
    } catch (e) {
      return ZuraffaApiBridge.errorResponse('deserialization', e.toString());
    }
    json.putIfAbsent('id', () => DateTime.now().microsecondsSinceEpoch.toString());
    final params = ${uc.paramsType}.fromJson(json);
    final useCase = getIt<${uc.className}>();
    final result = await useCase(params);
    return ZuraffaApiBridge.serializeResult(
      result,
      (v) => _toJsonFor${_capitalize(uc.methodName)}(v),
    );"""),
    ];

    return '${_emitHandler(handlerName, _handlerBlock(method, tryStmts))}\n'
        '${_generateToJsonHelper(uc)}';
  }

  /// Handler for StreamUseCase — subscribe/poll/cancel pattern.
  String _generateStreamHandler(
    _UseCaseDescriptor uc,
    String handlerName,
    String method,
  ) {
    final tryStmts = <Code>[];

    if (_isNoParams(uc.paramsType)) {
      tryStmts.add(const Code("    final params = const NoParams();"));
    } else if (_isPrimitive(uc.paramsType)) {
      // Primitives arrive as args['value'] — the same contract as non-stream
      // handlers and as the advertised params metadata.
      tryStmts.add(Code(_generatePrimitiveParamExtraction(uc.paramsType)));
    } else {
      tryStmts.add(
        Code("""
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(args['args'] ?? '{}') as Map<String, dynamic>;
    } catch (e) {
      return ZuraffaApiBridge.errorResponse('deserialization', e.toString());
    }
    json.putIfAbsent('id', () => DateTime.now().microsecondsSinceEpoch.toString());
    final params = ${uc.paramsType}.fromJson(json);"""),
      );
    }

    tryStmts.add(
      Code("""
    final useCase = getIt<${uc.className}>();
    final stream = useCase(params);
    final subscriptionId = ZuraffaApiBridge.generateSubscriptionId();

    // Subscribe and cache each emitted Result value for polling.
    final subscription = stream.listen(
      (result) {
        final serialized = result.fold(
          (v) => <String, dynamic>{'status': 'success', 'data': _toJsonFor${_capitalize(uc.methodName)}(v)},
          (f) => <String, dynamic>{'status': 'error', 'failure': {'type': f.runtimeType.toString(), 'message': f.message}},
        );
        ZuraffaApiBridge.updateStreamValue(subscriptionId, serialized);
      },
      onError: (Object e, StackTrace st) {
        developer.log('Bridge stream error: $method',
          error: e, stackTrace: st, name: 'ZuraffaApiBridge');
        ZuraffaApiBridge.updateStreamValue(subscriptionId, {'status': 'error', 'failure': {'type': 'unknown', 'message': e.toString()}});
      },
    );

    ZuraffaApiBridge.registerStreamSubscription(subscriptionId, subscription, (_) {});

    return developer.ServiceExtensionResponse.result(
      jsonEncode({'status': 'streaming', 'subscriptionId': subscriptionId}),
    );"""),
    );

    return '${_emitHandler(handlerName, _handlerBlock(method, tryStmts))}\n'
        '${_generateToJsonHelper(uc)}';
  }

  /// Generates a `_toJsonForX(v)` helper that handles `List<T>` and plain T.
  String _generateToJsonHelper(_UseCaseDescriptor uc) {
    final helperName = '_toJsonFor${_capitalize(uc.methodName)}';
    final rt = uc.returnType.trim();

    // List<T> → map each element
    if (rt.startsWith('List<')) {
      return 'Map<String, dynamic> $helperName($rt v) =>'
          " {'items': v.map((e) => e.toJson()).toList()};\n";
    }

    // void → empty map
    if (rt == 'void') {
      return 'Map<String, dynamic> $helperName($rt v) => {};\n';
    }

    // Plain T with toJson()
    return 'Map<String, dynamic> $helperName($rt v) => v.toJson();\n';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _isNoParams(String paramsType) {
    final t = paramsType.trim();
    return t == 'NoParams' || t == 'void';
  }

  bool _isPrimitive(String paramsType) {
    final t = paramsType.trim();
    return t == 'String' || t == 'int' || t == 'double' || t == 'bool';
  }

  /// Returns true when paramsType is `QueryParams<Entity>` (a query-by-id).
  bool _isQueryParams(String paramsType) {
    final base = paramsType.trim().split('<').first.trim();
    return base == 'QueryParams' && paramsType.contains('<');
  }

  /// Returns true when paramsType is `ListQueryParams<Entity>`.
  bool _isListQueryParams(String paramsType) {
    final base = paramsType.trim().split('<').first.trim();
    return base == 'ListQueryParams' && paramsType.contains('<');
  }

  /// Extracts the entity type from a generic like `QueryParams<Product>` → `Product`.
  String _extractEntityFromGeneric(String paramsType) {
    final match = RegExp(r'^\w+<(\w+)>?$').firstMatch(paramsType.trim());
    return match?.group(1) ?? paramsType.trim();
  }

  String _generatePrimitiveParamExtraction(String paramsType) {
    // For complex Params types like QueryParams<Product> we use a different path.
    // This helper is only called when isPrimitive() is true.
    final t = paramsType.trim();
    switch (t) {
      case 'int':
        return "    final params = int.tryParse(args['value'] ?? '0') ?? 0;";
      case 'double':
        return "    final params = double.tryParse(args['value'] ?? '0') ?? 0.0;";
      case 'bool':
        return "    final params = (args['value'] ?? 'false') == 'true';";
      default: // String
        return "    final params = args['value'] ?? '';";
    }
  }

  String _buildParamsMap(String paramsType, {required bool isStream}) {
    if (_isNoParams(paramsType)) return '{}';
    if (_isPrimitive(paramsType)) return "{'value': '$paramsType'}";
    // Stream handlers always take a JSON blob via the args key.
    if (isStream) return "{'args': '$paramsType'}";
    if (_isQueryParams(paramsType)) return "{'id': 'String'}";
    // Full-list queries take no arguments.
    if (_isListQueryParams(paramsType)) return '{}';
    // Complex type — advertise as JSON blob via args key
    return "{'args': '$paramsType'}";
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
