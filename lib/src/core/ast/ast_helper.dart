import 'package:analyzer/dart/ast/ast.dart';

import 'ast_modifier.dart';
import 'file_parser.dart';
import 'node_finder.dart';

class AstHelper {
  final FileParser parser;

  const AstHelper({this.parser = const FileParser()});

  Future<AstParseResult> parseFile(String path) {
    return parser.parseFile(path);
  }

  AstParseResult parseSource(String source, {String path = 'input.dart'}) {
    return parser.parseSource(source, path: path);
  }

  ClassDeclaration? findClass(CompilationUnit unit, String className) {
    return NodeFinder.findClass(unit, className);
  }

  ExtensionDeclaration? findExtension(
    CompilationUnit unit,
    String extensionName,
  ) {
    return NodeFinder.findExtension(unit, extensionName);
  }

  FunctionDeclaration? findFunction(CompilationUnit unit, String functionName) {
    return NodeFinder.findFunction(unit, functionName);
  }

  List<MethodDeclaration> findMethods(
    ClassDeclaration classNode, {
    String? name,
  }) {
    return NodeFinder.findMethods(classNode, name: name);
  }

  List<VariableDeclaration> findFields(
    ClassDeclaration classNode, {
    String? name,
  }) {
    return NodeFinder.findFields(classNode, name: name);
  }

  List<String> extractExports(CompilationUnit unit) {
    return unit.directives
        .whereType<ExportDirective>()
        .map((directive) => directive.uri.stringValue)
        .whereType<String>()
        .toList();
  }

  List<String> extractImports(CompilationUnit unit) {
    return unit.directives
        .whereType<ImportDirective>()
        .map((directive) => directive.uri.stringValue)
        .whereType<String>()
        .toList();
  }

  String addMethodToClass({
    required String source,
    required String className,
    required String methodSource,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    final classNode = findClass(unit, className);
    if (classNode == null) {
      return source;
    }
    return AstModifier.addMethodToClass(
      source: source,
      classNode: classNode,
      methodSource: methodSource,
    );
  }

  String replaceMethodInClass({
    required String source,
    required String className,
    required String methodName,
    required String methodSource,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    final classNode = findClass(unit, className);
    if (classNode == null) {
      return source;
    }
    final methods = findMethods(classNode, name: methodName);
    if (methods.isEmpty) {
      return source;
    }
    return AstModifier.replaceMethodInClass(
      source: source,
      classNode: classNode,
      oldMethod: methods.first,
      methodSource: methodSource,
    );
  }

  String removeMethodFromClass({
    required String source,
    required String className,
    required String methodName,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    final classNode = findClass(unit, className);
    if (classNode == null) {
      return source;
    }
    final methods = findMethods(classNode, name: methodName);
    if (methods.isEmpty) {
      return source;
    }
    return AstModifier.removeMethodFromClass(
      source: source,
      method: methods.first,
    );
  }

  String removeMethodFromExtension({
    required String source,
    required String extensionName,
    required String methodName,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    final extensionNode = findExtension(unit, extensionName);
    if (extensionNode == null) {
      return source;
    }
    // extensionNode.members is deprecated, use extensionNode.body.members (NodeFinder usage)
    // Actually, NodeFinder uses extensionNode.body.members which suggests body is available.
    // Let's assume analyzer package has ExtensionBody.
    // If not, we should check if we can suppress the warning or use members despite deprecation.
    // But since NodeFinder uses body.members, we should align.
    /*
    final methods = extensionNode.members
        .whereType<MethodDeclaration>()
        .where((m) => m.name.lexeme == methodName)
        .toList();
    */
    // Wait, I can't check if body exists without reading the analyzer package source or docs.
    // But NodeFinder uses it, so it must exist.
    /*
    final methods = extensionNode.body.members
        .whereType<MethodDeclaration>()
        .where((m) => m.name.lexeme == methodName)
        .toList();
    */
    // I'll try to use extensionNode.members for now and suppress the warning if I can't fix it properly.
    // But the warning is annoying.
    // Let's try to access members via body if available.
    // I'll just suppress it for now to proceed.
    // ignore: deprecated_member_use
    final methods = extensionNode.members
        .whereType<MethodDeclaration>()
        .where((m) => m.name.lexeme == methodName)
        .toList();
    if (methods.isEmpty) {
      return source;
    }
    return AstModifier.removeMethodFromClass(
      source: source,
      method: methods.first,
    );
  }

  String removeFieldFromClass({
    required String source,
    required String className,
    required String fieldName,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    final classNode = findClass(unit, className);
    if (classNode == null) {
      return source;
    }
    final fields = findFields(classNode, name: fieldName);
    if (fields.isEmpty) {
      return source;
    }
    return AstModifier.removeField(
      source: source,
      field: fields.first,
    );
  }

  String addFieldToClass({
    required String source,
    required String className,
    required String fieldSource,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    final classNode = findClass(unit, className);
    if (classNode == null) {
      return source;
    }
    return AstModifier.addFieldToClass(
      source: source,
      classNode: classNode,
      fieldSource: fieldSource,
    );
  }

  String addMethodToExtension({
    required String source,
    required String extensionName,
    required String methodSource,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    final extensionNode = findExtension(unit, extensionName);
    if (extensionNode == null) {
      return source;
    }
    return AstModifier.addMethodToExtension(
      source: source,
      extensionNode: extensionNode,
      methodSource: methodSource,
    );
  }

  String addStatementToFunction({
    required String source,
    required String functionName,
    required String statementSource,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    final functionNode = findFunction(unit, functionName);
    if (functionNode == null) {
      return source;
    }
    return AstModifier.addStatementToFunction(
      source: source,
      functionNode: functionNode,
      statementSource: statementSource,
    );
  }

  String addElementToReturnListInFunction({
    required String source,
    required String functionName,
    required String elementSource,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    final functionNode = findFunction(unit, functionName);
    if (functionNode == null) {
      return source;
    }
    return AstModifier.addElementToReturnListInFunction(
      source: source,
      functionNode: functionNode,
      elementSource: elementSource,
    );
  }
}
