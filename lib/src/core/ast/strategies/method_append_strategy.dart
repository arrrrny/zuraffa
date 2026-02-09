import 'package:analyzer/dart/ast/ast.dart';

import '../ast_helper.dart';
import '../node_finder.dart';
import 'append_strategy.dart';

class MethodAppendStrategy implements AppendStrategy {
  final AstHelper helper;

  const MethodAppendStrategy({this.helper = const AstHelper()});

  @override
  bool canHandle(AppendRequest request) {
    return request.target == AppendTarget.method &&
        request.className != null &&
        request.memberSource != null;
  }

  @override
  AppendResult apply(AppendRequest request) {
    if (!canHandle(request)) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Request not supported',
      );
    }
    final parseResult = helper.parseSource(request.source);
    final unit = parseResult.unit;
    if (unit == null) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Unable to parse source',
      );
    }
    final classNode = helper.findClass(unit, request.className!);
    if (classNode == null) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Class not found',
      );
    }

    final newMethod = _parseMethod(request.memberSource!);
    if (newMethod == null) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Invalid method source',
      );
    }

    final existingMethods = NodeFinder.findMethods(classNode);
    final newSignature = _methodSignature(newMethod);
    for (final method in existingMethods) {
      if (_methodSignature(method) == newSignature) {
        return AppendResult(
          source: request.source,
          changed: false,
          message: 'Duplicate method',
        );
      }
    }

    final updated = helper.addMethodToClass(
      source: request.source,
      className: request.className!,
      methodSource: request.memberSource!,
    );
    return AppendResult(source: updated, changed: updated != request.source);
  }

  MethodDeclaration? _parseMethod(String methodSource) {
    final wrapper = '''
class _Temp {
$methodSource
}
''';
    final result = helper.parseSource(wrapper);
    final unit = result.unit;
    if (unit == null) {
      return null;
    }
    final classNode = NodeFinder.findClass(unit, '_Temp');
    if (classNode == null) {
      return null;
    }
    final methods = NodeFinder.findMethods(classNode);
    if (methods.isEmpty) {
      return null;
    }
    return methods.first;
  }

  String _methodSignature(MethodDeclaration method) {
    final params = method.parameters?.toSource() ?? '';
    final returnType = method.returnType?.toSource() ?? '';
    return '${method.name.lexeme}::$returnType$params';
  }
}
