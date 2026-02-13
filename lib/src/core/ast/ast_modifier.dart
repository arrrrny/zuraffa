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
