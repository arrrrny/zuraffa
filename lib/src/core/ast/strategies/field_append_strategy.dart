import 'package:analyzer/dart/ast/ast.dart';

import '../ast_helper.dart';
import '../node_finder.dart';
import 'append_strategy.dart';

class FieldAppendStrategy implements AppendStrategy {
  final AstHelper helper;

  const FieldAppendStrategy({this.helper = const AstHelper()});

  @override
  bool canHandle(AppendRequest request) {
    return request.target == AppendTarget.field &&
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

    final newField = _parseField(request.memberSource!);
    if (newField == null) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Invalid field source',
      );
    }

    final existingFields = NodeFinder.findFields(classNode);
    for (final field in existingFields) {
      if (field.name.lexeme == newField.name.lexeme) {
        return AppendResult(
          source: request.source,
          changed: false,
          message: 'Duplicate field',
        );
      }
    }

    final updated = helper.addFieldToClass(
      source: request.source,
      className: request.className!,
      fieldSource: request.memberSource!,
    );
    return AppendResult(source: updated, changed: updated != request.source);
  }

  VariableDeclaration? _parseField(String fieldSource) {
    final wrapper =
        '''
class _Temp {
$fieldSource
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
    final fields = NodeFinder.findFields(classNode);
    if (fields.isEmpty) {
      return null;
    }
    return fields.first;
  }
}
