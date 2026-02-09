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
