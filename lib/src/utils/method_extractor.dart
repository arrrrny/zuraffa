import '../core/ast/ast_helper.dart';
import '../core/context/file_system.dart';
import '../models/parsed_usecase_info.dart';

class MethodExtractor {
  static Future<List<ParsedUseCaseInfo>> extractMethodsFromInterface(
    String filePath,
    String className, {
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    if (!await fs.exists(filePath)) {
      return [];
    }

    final helper = const AstHelper();
    final parseResult = await helper.parseFile(filePath, fileSystem: fs);
    final unit = parseResult.unit;
    if (unit == null) return [];

    final classNode = helper.findClass(unit, className);
    if (classNode == null) return [];

    final methods = <ParsedUseCaseInfo>[];
    final helperMethods = helper.findMethods(classNode);
    for (final method in helperMethods) {
      final methodName = method.name.toString();
      final returns = method.returnType?.toString() ?? 'void';

      // We expect one parameter named 'params' for Zuraffa services
      String? paramsType;
      final parameters = method.parameters?.parameters;
      if (parameters != null && parameters.isNotEmpty) {
        final firstParam = parameters.first;
        paramsType = _getParameterType(firstParam);
      }

      // Determine usecase type based on return type
      var useCaseType = 'usecase';
      if (returns.startsWith('Stream<')) {
        useCaseType = 'stream';
      } else if (returns == 'Future<void>') {
        useCaseType = 'completable';
      } else if (!returns.startsWith('Future<')) {
        useCaseType = 'sync';
      }

      methods.add(
        ParsedUseCaseInfo(
          className:
              className, // Not used here as the class name of the method itself
          fieldName: methodName,
          paramsType: paramsType ?? 'NoParams',
          returnsType: _cleanReturnType(returns),
          useCaseType: useCaseType,
        ),
      );
    }

    return methods;
  }

  static String? _getParameterType(dynamic p) {
    try {
      // Analyzer < 13: SimpleFormalParameter has type property
      // Analyzer >= 13: RegularFormalParameter has type property
      // If p is DefaultFormalParameter (Analyzer < 13), it has a 'parameter' property
      dynamic param = p;
      try {
        param = p.parameter;
      } catch (_) {
        // Not a DefaultFormalParameter or Analyzer >= 13
      }
      return param.type?.toString();
    } catch (_) {
      return null;
    }
  }

  static String _cleanReturnType(String returns) {
    if (returns.startsWith('Future<') && returns.endsWith('>')) {
      return returns.substring(7, returns.length - 1);
    }
    if (returns.startsWith('Stream<') && returns.endsWith('>')) {
      return returns.substring(7, returns.length - 1);
    }
    return returns;
  }
}
