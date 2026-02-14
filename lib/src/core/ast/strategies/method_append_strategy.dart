import 'package:analyzer/dart/ast/ast.dart';

import '../ast_helper.dart';
import '../node_finder.dart';
import 'append_strategy.dart';

/// Appends or replaces methods inside a class declaration.
class MethodAppendStrategy implements AppendStrategy {
  final AstHelper helper;

  const MethodAppendStrategy({this.helper = const AstHelper()});

  @override
  /// Returns true when the request targets a class method append.
  bool canHandle(AppendRequest request) {
    return request.target == AppendTarget.method &&
        request.className != null &&
        request.memberSource != null;
  }

  @override
  /// Applies the append operation, replacing existing methods when needed.
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
    final newMethodName = newMethod.name.lexeme;

    for (final method in existingMethods) {
      if (method.name.lexeme == newMethodName) {
        final existingSource = request.source.substring(
          method.offset,
          method.end,
        );
        if (_isSameMethodSource(existingSource, request.memberSource!)) {
          return AppendResult(
            source: request.source,
            changed: false,
            message: 'Method already exists',
          );
        }
        final updated = helper.replaceMethodInClass(
          source: request.source,
          className: request.className!,
          methodName: newMethodName,
          methodSource: request.memberSource!,
        );
        return AppendResult(
          source: updated,
          changed: updated != request.source,
          message: 'Method replaced',
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

  bool _isSameMethodSource(String existingSource, String newSource) {
    return _normalizeSource(existingSource) == _normalizeSource(newSource);
  }

  String _normalizeSource(String source) {
    return source.replaceAll(RegExp(r'\s+'), '');
  }

  MethodDeclaration? _parseMethod(String methodSource) {
    final wrapper =
        '''
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
}
