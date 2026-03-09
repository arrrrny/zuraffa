import 'package:analyzer/dart/ast/ast.dart';

class AstModifier {
  static String addMethodToClass({
    required String source,
    required ClassDeclaration classNode,
    required String methodSource,
  }) {
    final insertOffset = classNode.body.endToken.offset;
    final closingIndent = _indentBeforeOffset(source, insertOffset);
    final memberIndent = '$closingIndent  ';
    final normalized = methodSource.trimRight();
    final indented = normalized
        .split('\n')
        .map((line) => line.isEmpty ? '' : '$memberIndent$line')
        .join('\n');
    final insert = '\n$indented\n$closingIndent';
    return source.substring(0, insertOffset) +
        insert +
        source.substring(insertOffset);
  }

  static String replaceMethodInClass({
    required String source,
    required ClassDeclaration classNode,
    required MethodDeclaration oldMethod,
    required String methodSource,
  }) {
    final startOffset = oldMethod.offset;
    final endOffset = oldMethod.end;
    final methodIndent = _indentBeforeOffset(source, startOffset);
    final normalized = methodSource.trimRight();
    final indented = normalized
        .split('\n')
        .map((line) => line.isEmpty ? '' : '$methodIndent$line')
        .join('\n');
    return source.substring(0, startOffset) +
        indented +
        source.substring(endOffset);
  }

  static String removeMethodFromClass({
    required String source,
    required MethodDeclaration method,
  }) {
    return source.substring(0, method.offset) + source.substring(method.end);
  }

  static String removeField({
    required String source,
    required VariableDeclaration field,
  }) {
    final parent = field.parent;
    if (parent is VariableDeclarationList) {
      final grandParent = parent.parent;
      if (grandParent is FieldDeclaration) {
        return source.substring(0, grandParent.offset) +
            source.substring(grandParent.end);
      }
    }
    return source.substring(0, field.offset) + source.substring(field.end);
  }

  static String addFieldToClass({
    required String source,
    required ClassDeclaration classNode,
    required String fieldSource,
  }) {
    final insertOffset = classNode.body.endToken.offset;
    final closingIndent = _indentBeforeOffset(source, insertOffset);
    final memberIndent = '$closingIndent  ';
    final normalized = fieldSource.trimRight();
    final indented = normalized
        .split('\n')
        .map((line) => line.isEmpty ? '' : '$memberIndent$line')
        .join('\n');
    final insert = '\n$indented\n$closingIndent';
    return source.substring(0, insertOffset) +
        insert +
        source.substring(insertOffset);
  }

  static String addMethodToExtension({
    required String source,
    required ExtensionDeclaration extensionNode,
    required String methodSource,
  }) {
    final insertOffset = extensionNode.body.rightBracket.offset;
    final closingIndent = _indentBeforeOffset(source, insertOffset);
    final memberIndent = '$closingIndent  ';
    final normalized = methodSource.trimRight();
    final indented = normalized
        .split('\n')
        .map((line) => line.isEmpty ? '' : '$memberIndent$line')
        .join('\n');
    final insert = '\n$indented\n$closingIndent';
    return source.substring(0, insertOffset) +
        insert +
        source.substring(insertOffset);
  }

  static String addStatementToFunction({
    required String source,
    required FunctionDeclaration functionNode,
    required String statementSource,
  }) {
    final body = functionNode.functionExpression.body;
    if (body is! BlockFunctionBody) {
      return source;
    }
    final insertOffset = body.block.rightBracket.offset;
    final closingIndent = _indentBeforeOffset(source, insertOffset);
    final memberIndent = '$closingIndent  ';
    final normalized = statementSource.trimRight();
    final indented = normalized
        .split('\n')
        .map((line) => line.isEmpty ? '' : '$memberIndent$line')
        .join('\n');
    final insert = '\n$indented\n$closingIndent';
    return source.substring(0, insertOffset) +
        insert +
        source.substring(insertOffset);
  }

  static String addElementToReturnListInFunction({
    required String source,
    required FunctionDeclaration functionNode,
    required String elementSource,
  }) {
    final body = functionNode.functionExpression.body;
    if (body is! BlockFunctionBody) {
      return source;
    }

    final returnStatement = body.block.statements.whereType<ReturnStatement>().firstOrNull;
    if (returnStatement == null) {
      return source;
    }

    final expression = returnStatement.expression;
    if (expression is! ListLiteral) {
      return source;
    }

    final insertOffset = expression.rightBracket.offset;
    final closingIndent = _indentBeforeOffset(source, insertOffset);
    final elementIndent = '$closingIndent  ';
    final normalized = elementSource.trimRight();
    final indented = normalized
        .split('\n')
        .map((line) => line.isEmpty ? '' : '$elementIndent$line')
        .join('\n');
    final insert = '\n$indented,\n$closingIndent';
    return source.substring(0, insertOffset) +
        insert +
        source.substring(insertOffset);
  }

  static String _indentBeforeOffset(String source, int offset) {
    final lineStart = source.lastIndexOf('\n', offset);
    if (lineStart == -1) {
      return '';
    }
    final slice = source.substring(lineStart + 1, offset);
    final match = RegExp(r'^\s*').firstMatch(slice);
    return match?.group(0) ?? '';
  }
}
