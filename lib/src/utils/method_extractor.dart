import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart';
import '../core/ast/ast_helper.dart';
import '../models/parsed_usecase_info.dart';
import '../utils/string_utils.dart';

class MethodExtractor {
  static Future<List<ParsedUseCaseInfo>> extractMethodsFromInterface(
    String filePath,
    String className,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return [];

    final helper = const AstHelper();
    final parseResult = await helper.parseFile(filePath);
    final unit = parseResult.unit;
    if (unit == null) return [];

    final classNode = helper.findClass(unit, className);
    if (classNode == null) return [];

    final methods = <ParsedUseCaseInfo>[];
    for (final method in helper.findMethods(classNode)) {
      final methodName = method.name.toString();
      final returns = method.returnType?.toString() ?? 'void';
      
      // We expect one parameter named 'params' for Zuraffa services
      String? paramsType;
      final parameters = method.parameters?.parameters;
      if (parameters != null && parameters.isNotEmpty) {
        final firstParam = parameters.first;
        if (firstParam is SimpleFormalParameter) {
          paramsType = firstParam.type?.toString();
        }
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
          className: className, // Not used here as the class name of the method itself
          fieldName: methodName,
          paramsType: paramsType ?? 'NoParams',
          returnsType: _cleanReturnType(returns),
          useCaseType: useCaseType,
        ),
      );
    }

    return methods;
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
