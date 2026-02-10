import 'package:analyzer/dart/ast/ast.dart';

import '../ast_helper.dart';
import '../node_finder.dart';
import 'append_strategy.dart';

class FunctionStatementAppendStrategy implements AppendStrategy {
  final AstHelper helper;

  const FunctionStatementAppendStrategy({this.helper = const AstHelper()});

  @override
  bool canHandle(AppendRequest request) {
    return request.target == AppendTarget.functionStatement &&
        request.functionName != null &&
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
    final functionNode = helper.findFunction(unit, request.functionName!);
    if (functionNode == null) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Function not found',
      );
    }
    final newStatement = _parseStatement(request.memberSource!);
    if (newStatement == null) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Invalid statement source',
      );
    }
    final body = functionNode.functionExpression.body;
    if (body is! BlockFunctionBody) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Unsupported function body',
      );
    }
    for (final statement in body.block.statements) {
      if (statement.toSource() == newStatement.toSource()) {
        return AppendResult(
          source: request.source,
          changed: false,
          message: 'Duplicate statement',
        );
      }
    }
    final updated = helper.addStatementToFunction(
      source: request.source,
      functionName: request.functionName!,
      statementSource: request.memberSource!,
    );
    return AppendResult(source: updated, changed: updated != request.source);
  }

  Statement? _parseStatement(String statementSource) {
    final wrapper =
        '''
void _temp() {
$statementSource
}
''';
    final result = helper.parseSource(wrapper);
    final unit = result.unit;
    if (unit == null) {
      return null;
    }
    final functionNode = NodeFinder.findFunction(unit, '_temp');
    if (functionNode == null) {
      return null;
    }
    final body = functionNode.functionExpression.body;
    if (body is! BlockFunctionBody) {
      return null;
    }
    if (body.block.statements.isEmpty) {
      return null;
    }
    return body.block.statements.first;
  }
}
