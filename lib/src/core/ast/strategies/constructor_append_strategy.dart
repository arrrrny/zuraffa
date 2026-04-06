import 'package:analyzer/dart/ast/ast.dart';

import '../ast_helper.dart';
import '../node_finder.dart';
import 'append_strategy.dart';

/// Appends or replaces constructors inside a class declaration.
class ConstructorAppendStrategy implements AppendStrategy {
  final AstHelper helper;

  const ConstructorAppendStrategy({this.helper = const AstHelper()});

  @override
  bool canHandle(AppendRequest request) {
    return request.target == AppendTarget.constructor &&
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

    final body = classNode.body;
    if (body is! BlockClassBody) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Class body not found',
      );
    }

    final newConstructor = _parseConstructor(
      request.memberSource!,
      request.className!,
    );
    if (newConstructor == null) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Invalid constructor source',
      );
    }

    final existingConstructors = body.members.whereType<ConstructorDeclaration>();
    for (final constructor in existingConstructors) {
      if (constructor.name?.lexeme == newConstructor.name?.lexeme) {
        if (!request.force) {
          if (AstHelper.areConstructorsEqual(constructor, newConstructor)) {
            return AppendResult(
              source: request.source,
              changed: false,
              message: 'Constructor already exists',
            );
          }

          if (!AstHelper.areConstructorSignaturesEqual(
            constructor,
            newConstructor,
          )) {
            return AppendResult(
              source: request.source,
              changed: false,
              message:
                  'Constructor with same name but different signature already exists',
            );
          }
        }

        // Replace existing constructor
        final updated = request.source.substring(0, constructor.offset) +
            request.memberSource! +
            request.source.substring(constructor.end);
        return AppendResult(
          source: updated,
          changed: true,
          message: 'Constructor replaced',
        );
      }
    }

    // Add new constructor - using the generic member addition logic
    final updated = helper.addMethodToClass(
      source: request.source,
      className: request.className!,
      methodSource: request.memberSource!,
    );
    return AppendResult(
      source: updated,
      changed: updated != request.source,
      message: 'Constructor added',
    );
  }

  @override
  AppendResult undo(AppendRequest request) {
    if (!canHandle(request)) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Request not supported',
      );
    }
    final updated = helper.removeConstructorFromClass(
      source: request.source,
      className: request.className!,
    );

    return AppendResult(
      source: updated,
      changed: updated != request.source,
      message: updated != request.source
          ? 'Constructor removed'
          : 'Constructor not found',
    );
  }

  ConstructorDeclaration? _parseConstructor(
    String constructorSource,
    String className,
  ) {
    final wrapper = '''
class $className {
$constructorSource
}
''';
    final result = helper.parseSource(wrapper);
    final unit = result.unit;
    if (unit == null) return null;
    final classNode = NodeFinder.findClass(unit, className);
    if (classNode == null) return null;
    final constructors =
        classNode.body.members.whereType<ConstructorDeclaration>();
    if (constructors.isEmpty) return null;
    return constructors.first;
  }
}
