import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_style/dart_style.dart';

class AstModifier {
  static String addMethodToClass({
    required String source,
    required ClassDeclaration classNode,
    required String methodSource,
    bool format = true,
  }) {
    final body = classNode.body;
    if (body is! BlockClassBody) return source;
    return _addMemberToBlock(
      source: source,
      blockBody: body,
      memberSource: methodSource,
      format: format,
    );
  }

  static String replaceMethodInClass({
    required String source,
    required ClassDeclaration classNode,
    required MethodDeclaration oldMethod,
    required String methodSource,
    bool format = true,
  }) {
    return _replaceRange(
      source: source,
      offset: oldMethod.offset,
      end: oldMethod.end,
      newSource: methodSource,
      format: format,
    );
  }

  static String replaceConstructorInClass({
    required String source,
    required ClassDeclaration classNode,
    required ConstructorDeclaration oldConstructor,
    required String constructorSource,
    bool format = true,
  }) {
    return _replaceRange(
      source: source,
      offset: oldConstructor.offset,
      end: oldConstructor.end,
      newSource: constructorSource,
      format: format,
    );
  }

  static String replaceFieldInClass({
    required String source,
    required ClassDeclaration classNode,
    required VariableDeclaration oldField,
    required String fieldSource,
    bool format = true,
  }) {
    final parent = oldField.parent;
    if (parent is VariableDeclarationList) {
      final grandParent = parent.parent;
      if (grandParent is FieldDeclaration) {
        return _replaceRange(
          source: source,
          offset: grandParent.offset,
          end: grandParent.end,
          newSource: fieldSource,
          format: format,
        );
      }
    }
    return _replaceRange(
      source: source,
      offset: oldField.offset,
      end: oldField.end,
      newSource: fieldSource,
      format: format,
    );
  }

  static String removeMethodFromClass({
    required String source,
    required MethodDeclaration method,
    bool format = true,
  }) {
    return _replaceRange(
      source: source,
      offset: method.offset,
      end: method.end,
      newSource: '',
      format: format,
    );
  }

  static String removeField({
    required String source,
    required VariableDeclaration field,
    bool format = true,
  }) {
    final parent = field.parent;
    if (parent is VariableDeclarationList) {
      final grandParent = parent.parent;
      if (grandParent is FieldDeclaration) {
        return _replaceRange(
          source: source,
          offset: grandParent.offset,
          end: grandParent.end,
          newSource: '',
          format: format,
        );
      }
    }
    return _replaceRange(
      source: source,
      offset: field.offset,
      end: field.end,
      newSource: '',
      format: format,
    );
  }

  static String addImport(
    String source,
    CompilationUnit unit,
    String importPath, {
    bool format = true,
  }) {
    final existingImports = unit.directives.whereType<ImportDirective>();
    for (final imp in existingImports) {
      if (imp.uri.stringValue == importPath) {
        return source;
      }
    }

    final importDirective = "import '$importPath';";
    final imports = unit.directives.whereType<ImportDirective>().toList();
    if (imports.isNotEmpty) {
      final lastImport = imports.last;
      final insertOffset = lastImport.end;
      final result =
          '${source.substring(0, insertOffset)}\n$importDirective'
          '${source.substring(insertOffset)}';
      return format ? _formatSafe(result) : result;
    }
    final firstDirective = unit.directives.isEmpty
        ? null
        : unit.directives.first;
    if (firstDirective != null) {
      final insertOffset = firstDirective.offset;
      final result = '$importDirective\n${source.substring(insertOffset)}';
      return format ? _formatSafe(result) : result;
    }
    final result = '$importDirective\n\n$source';
    return format ? _formatSafe(result) : result;
  }

  static String removeImport(
    String source,
    CompilationUnit unit,
    String importPath, {
    bool format = true,
  }) {
    final imports = unit.directives.whereType<ImportDirective>().toList();
    for (final imp in imports) {
      if (imp.uri.stringValue == importPath) {
        final result =
            source.substring(0, imp.offset) + source.substring(imp.end);
        return format ? _formatSafe(result) : result;
      }
    }
    return source;
  }

  static String addExport(
    String source,
    CompilationUnit unit,
    String exportPath, {
    bool format = true,
  }) {
    final existingExports = unit.directives.whereType<ExportDirective>();
    for (final exp in existingExports) {
      if (exp.uri.stringValue == exportPath) {
        return source;
      }
    }

    final exportDirective = "export '$exportPath';";
    final exports = unit.directives.whereType<ExportDirective>().toList();
    if (exports.isNotEmpty) {
      final lastExport = exports.last;
      final insertOffset = lastExport.end;
      final result =
          '${source.substring(0, insertOffset)}\n$exportDirective'
          '${source.substring(insertOffset)}';
      return format ? _formatSafe(result) : result;
    }
    final lastImport = unit.directives.whereType<ImportDirective>().lastOrNull;
    if (lastImport != null) {
      final insertOffset = lastImport.end;
      final result =
          '${source.substring(0, insertOffset)}\n\n$exportDirective'
          '${source.substring(insertOffset)}';
      return format ? _formatSafe(result) : result;
    }
    final result = '$exportDirective\n\n$source';
    return format ? _formatSafe(result) : result;
  }

  static String removeExport(
    String source,
    CompilationUnit unit,
    String exportPath, {
    bool format = true,
  }) {
    final exports = unit.directives.whereType<ExportDirective>().toList();
    for (final export in exports) {
      if (export.uri.stringValue == exportPath) {
        final result =
            source.substring(0, export.offset) + source.substring(export.end);
        return format ? _formatSafe(result) : result;
      }
    }
    return source;
  }

  static String addFieldToClass({
    required String source,
    required ClassDeclaration classNode,
    required String fieldSource,
    bool format = true,
  }) {
    final body = classNode.body;
    if (body is! BlockClassBody) return source;
    return _addMemberToBlock(
      source: source,
      blockBody: body,
      memberSource: fieldSource,
      format: format,
    );
  }

  static String addMethodToExtension({
    required String source,
    required ExtensionDeclaration extensionNode,
    required String methodSource,
    bool format = true,
  }) {
    final body = extensionNode.body;
    if (body is! BlockClassBody) return source;
    return _addMemberToBlock(
      source: source,
      blockBody: body,
      memberSource: methodSource,
      format: format,
    );
  }

  static String addStatementToFunction({
    required String source,
    required FunctionDeclaration functionNode,
    required String statementSource,
    bool format = true,
  }) {
    final body = functionNode.functionExpression.body;
    if (body is! BlockFunctionBody) {
      return source;
    }
    return _insertInBlock(
      source: source,
      rightBracketOffset: body.block.rightBracket.offset,
      content: statementSource,
      format: format,
    );
  }

  static String addElementToReturnListInFunction({
    required String source,
    required FunctionDeclaration functionNode,
    required String elementSource,
    bool format = true,
  }) {
    final body = functionNode.functionExpression.body;
    if (body is! BlockFunctionBody) {
      return source;
    }

    final returnStatement = body.block.statements
        .whereType<ReturnStatement>()
        .firstOrNull;
    if (returnStatement == null) {
      return source;
    }

    final expression = returnStatement.expression;
    if (expression is! ListLiteral) {
      return source;
    }

    return _insertInBlock(
      source: source,
      rightBracketOffset: expression.rightBracket.offset,
      content: elementSource,
      suffix: ',',
      format: format,
    );
  }

  static String removeElementFromReturnListInFunction({
    required String source,
    required FunctionDeclaration functionNode,
    required String elementSource,
    bool format = true,
  }) {
    final body = functionNode.functionExpression.body;
    if (body is! BlockFunctionBody) {
      return source;
    }

    final returnStatement = body.block.statements
        .whereType<ReturnStatement>()
        .firstOrNull;
    if (returnStatement == null) {
      return source;
    }

    final expression = returnStatement.expression;
    if (expression is! ListLiteral) {
      return source;
    }

    final elements = expression.elements;
    for (final element in elements) {
      if (element.toSource() == elementSource) {
        final result =
            source.substring(0, element.offset) + source.substring(element.end);
        return format ? _formatSafe(result) : result;
      }
    }

    return source;
  }

  static String removeStatement({
    required String source,
    required List<Statement> statements,
    required String statementSource,
    bool format = true,
  }) {
    for (final statement in statements) {
      if (statement.toSource() == statementSource) {
        return _replaceRange(
          source: source,
          offset: statement.offset,
          end: statement.end,
          newSource: '',
          format: format,
        );
      }
    }
    return source;
  }

  static String _addMemberToBlock({
    required String source,
    required BlockClassBody blockBody,
    required String memberSource,
    bool format = true,
  }) {
    return _insertInBlock(
      source: source,
      rightBracketOffset: blockBody.rightBracket.offset,
      content: memberSource,
      format: format,
    );
  }

  static String _insertInBlock({
    required String source,
    required int rightBracketOffset,
    required String content,
    String suffix = '',
    bool format = true,
  }) {
    final result =
        source.substring(0, rightBracketOffset) +
        '\n$content$suffix\n' +
        source.substring(rightBracketOffset);
    return format ? _formatSafe(result) : result;
  }

  static String _replaceRange({
    required String source,
    required int offset,
    required int end,
    required String newSource,
    bool format = true,
  }) {
    final result =
        source.substring(0, offset) + newSource + source.substring(end);
    return format ? _formatSafe(result) : result;
  }

  static String format(String source) {
    return _formatSafe(source);
  }

  static String _formatSafe(String source) {
    try {
      return DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      ).format(source);
    } catch (_) {
      return source;
    }
  }
}
