import 'dart:io';

import 'package:path/path.dart' as p;

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

  ApiBridgeBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

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
    final re = RegExp(
      r'class\s+(\w+UseCase)\s+extends\s+(StreamUseCase|UseCase)<([^,]+),\s*([^>]+)>',
    );
    final match = re.firstMatch(content);
    if (match == null) return null;

    final className = match.group(1)!.trim();
    final baseClass = match.group(2)!.trim();
    final returnType = match.group(3)!.trim();
    final paramsType = match.group(4)!.trim();
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
    if (baseType == 'QueryParams' || baseType == 'QueryParamsPatch') {
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
    final addedParamImports = <String>{};
    for (final uc in useCases) {
      final pt = uc.paramsType;
      if (_isNoParams(pt) || _isPrimitive(pt)) continue;
      final paramSnake = StringUtils.camelToSnake(pt);
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
      final paramsMap = _buildParamsMap(uc.paramsType);
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

  String _generateHandler(_UseCaseDescriptor uc, String domain) {
    final handlerName = '_handle${_capitalize(uc.methodName)}';
    final method = 'ext.zuraffa.$domain.${uc.methodName}';
    final buf = StringBuffer();

    if (uc.isStream) {
      buf.write(_generateStreamHandler(uc, handlerName, method));
    } else if (_isPrimitive(uc.paramsType) || _isNoParams(uc.paramsType)) {
      buf.write(_generateSimpleHandler(uc, handlerName));
    } else {
      buf.write(_generateComplexHandler(uc, handlerName));
    }

    return buf.toString();
  }

  /// Handler for UseCases with primitive or NoParams params.
  String _generateSimpleHandler(_UseCaseDescriptor uc, String handlerName) {
    final paramExtract = _generatePrimitiveParamExtraction(uc.paramsType);
    final buf = StringBuffer();

    buf.writeln('Future<developer.ServiceExtensionResponse> $handlerName(');
    buf.writeln('  String method,');
    buf.writeln('  Map<String, String> args,');
    buf.writeln(') async {');
    buf.writeln('  try {');

    if (_isNoParams(uc.paramsType)) {
      buf.writeln('    final useCase = GetIt.I<${uc.className}>();');
      buf.writeln('    final result = await useCase(const NoParams());');
    } else {
      buf.writeln(paramExtract);
      buf.writeln('    final useCase = GetIt.I<${uc.className}>();');
      buf.writeln('    final result = await useCase(params);');
    }

    buf.writeln('    return ZuraffaApiBridge.serializeResult(');
    buf.writeln('      result,');
    buf.writeln('      (v) => _toJsonFor${_capitalize(uc.methodName)}(v),');
    buf.writeln('    );');
    buf.writeln('  } catch (e, st) {');
    buf.writeln("    developer.log('Bridge error: \$method',");
    buf.writeln('      error: e, stackTrace: st,');
    buf.writeln("      name: 'ZuraffaApiBridge');");
    buf.writeln(
      "    return ZuraffaApiBridge.errorResponse('unknown', e.toString());",
    );
    buf.writeln('  }');
    buf.writeln('}');
    buf.writeln();
    // toJson helper
    buf.write(_generateToJsonHelper(uc));
    return buf.toString();
  }

  /// Handler for UseCases with complex (JSON-deserializable) params.
  String _generateComplexHandler(_UseCaseDescriptor uc, String handlerName) {
    final buf = StringBuffer();

    buf.writeln('Future<developer.ServiceExtensionResponse> $handlerName(');
    buf.writeln('  String method,');
    buf.writeln('  Map<String, String> args,');
    buf.writeln(') async {');
    buf.writeln('  try {');
    buf.writeln('    final Map<String, dynamic> json;');
    buf.writeln('    try {');
    buf.writeln(
      "      json = jsonDecode(args['args'] ?? '{}') as Map<String, dynamic>;",
    );
    buf.writeln('    } catch (e) {');
    buf.writeln(
      "      return ZuraffaApiBridge.errorResponse('deserialization', e.toString());",
    );
    buf.writeln('    }');
    buf.writeln(
      "    json.putIfAbsent('id', () => DateTime.now().microsecondsSinceEpoch.toString());",
    );
    buf.writeln('    final params = ${uc.paramsType}.fromJson(json);');
    buf.writeln('    final useCase = GetIt.I<${uc.className}>();');
    buf.writeln('    final result = await useCase(params);');
    buf.writeln('    return ZuraffaApiBridge.serializeResult(');
    buf.writeln('      result,');
    buf.writeln('      (v) => _toJsonFor${_capitalize(uc.methodName)}(v),');
    buf.writeln('    );');
    buf.writeln('  } catch (e, st) {');
    buf.writeln("    developer.log('Bridge error: \$method',");
    buf.writeln('      error: e, stackTrace: st,');
    buf.writeln("      name: 'ZuraffaApiBridge');");
    buf.writeln(
      "    return ZuraffaApiBridge.errorResponse('unknown', e.toString());",
    );
    buf.writeln('  }');
    buf.writeln('}');
    buf.writeln();
    buf.write(_generateToJsonHelper(uc));
    return buf.toString();
  }

  /// Handler for StreamUseCase — subscribe/poll/cancel pattern.
  String _generateStreamHandler(
    _UseCaseDescriptor uc,
    String handlerName,
    String method,
  ) {
    final buf = StringBuffer();

    buf.writeln('Future<developer.ServiceExtensionResponse> $handlerName(');
    buf.writeln('  String method,');
    buf.writeln('  Map<String, String> args,');
    buf.writeln(') async {');
    buf.writeln('  try {');
    buf.writeln('    final Map<String, dynamic> json;');
    buf.writeln('    try {');
    buf.writeln(
      "      json = jsonDecode(args['args'] ?? '{}') as Map<String, dynamic>;",
    );
    buf.writeln('    } catch (e) {');
    buf.writeln(
      "      return ZuraffaApiBridge.errorResponse('deserialization', e.toString());",
    );
    buf.writeln('    }');

    if (_isNoParams(uc.paramsType)) {
      buf.writeln('    final params = const NoParams();');
    } else if (_isPrimitive(uc.paramsType)) {
      // Primitive values are passed as json['value'] in stream handlers
      final t = uc.paramsType.trim();
      switch (t) {
        case 'int':
          buf.writeln(
            "    final params = int.tryParse(json['value']?.toString() ?? '0') ?? 0;",
          );
          break;
        case 'double':
          buf.writeln(
            "    final params = double.tryParse(json['value']?.toString() ?? '0') ?? 0.0;",
          );
          break;
        case 'bool':
          buf.writeln(
            "    final params = (json['value']?.toString() ?? 'false') == 'true';",
          );
          break;
        default:
          buf.writeln(
            "    final params = json['value']?.toString() ?? '';",
          );
      }
    } else {
      buf.writeln(
        "    json.putIfAbsent('id', () => DateTime.now().microsecondsSinceEpoch.toString());",
      );
      buf.writeln('    final params = ${uc.paramsType}.fromJson(json);');
    }

    buf.writeln('    final useCase = GetIt.I<${uc.className}>();');
    buf.writeln('    final stream = useCase(params);');
    buf.writeln(
      '    final subscriptionId = ZuraffaApiBridge.generateSubscriptionId();',
    );
    buf.writeln();
    buf.writeln(
      '    // Subscribe and cache each emitted Result value for polling.',
    );
    buf.writeln('    final subscription = stream.listen(');
    buf.writeln('      (result) {');
    buf.writeln('        final serialized = result.fold(');
    buf.writeln(
      "          (v) => <String, dynamic>{'status': 'success', 'data': _toJsonFor${_capitalize(uc.methodName)}(v)},",
    );
    buf.writeln(
      "          (f) => <String, dynamic>{'status': 'error', 'failure': {'type': f.runtimeType.toString(), 'message': f.message}},",
    );
    buf.writeln('        );');
    buf.writeln(
      '        ZuraffaApiBridge.updateStreamValue(subscriptionId, serialized);',
    );
    buf.writeln('      },');
    buf.writeln('      onError: (Object e, StackTrace st) {');
    buf.writeln("        developer.log('Bridge stream error: \$method',");
    buf.writeln(
      "          error: e, stackTrace: st, name: 'ZuraffaApiBridge');",
    );
    buf.writeln(
      "        ZuraffaApiBridge.updateStreamValue(subscriptionId, {'status': 'error', 'failure': {'type': 'unknown', 'message': e.toString()}});",
    );
    buf.writeln('      },');
    buf.writeln('    );');
    buf.writeln();
    buf.writeln(
      '    ZuraffaApiBridge.registerStreamSubscription(subscriptionId, subscription, (_) {});',
    );
    buf.writeln();
    buf.writeln("    return developer.ServiceExtensionResponse.result(");
    buf.writeln(
      "      jsonEncode({'status': 'streaming', 'subscriptionId': subscriptionId}),",
    );
    buf.writeln('    );');
    buf.writeln('  } catch (e, st) {');
    buf.writeln("    developer.log('Bridge error: \$method',");
    buf.writeln('      error: e, stackTrace: st,');
    buf.writeln("      name: 'ZuraffaApiBridge');");
    buf.writeln(
      "    return ZuraffaApiBridge.errorResponse('unknown', e.toString());",
    );
    buf.writeln('  }');
    buf.writeln('}');
    buf.writeln();
    buf.write(_generateToJsonHelper(uc));
    return buf.toString();
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

  String _buildParamsMap(String paramsType) {
    if (_isNoParams(paramsType)) return '{}';
    if (_isPrimitive(paramsType)) return "{'value': '$paramsType'}";
    // Complex type — advertise as JSON blob via args key
    return "{'args': '$paramsType'}";
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
