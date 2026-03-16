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

  String addImport({required String source, required String importPath}) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    return AstModifier.addImport(source, unit, importPath);
  }

  String addExport({required String source, required String exportPath}) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    return AstModifier.addExport(source, unit, exportPath);
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

  String replaceFieldInClass({
    required String source,
    required String className,
    required String fieldName,
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
    final fields = findFields(classNode, name: fieldName);
    if (fields.isEmpty) {
      return source;
    }
    return AstModifier.replaceFieldInClass(
      source: source,
      classNode: classNode,
      oldField: fields.first,
      fieldSource: fieldSource,
    );
  }

  String removeMethodFromClass({
    required String source,
    required String className,
    required String methodName,
  }) {
    var updated = source;
    while (true) {
      final parseResult = parseSource(updated);
      final unit = parseResult.unit;
      if (unit == null) break;

      final classNode = findClass(unit, className);
      if (classNode == null) break;

      final methods = findMethods(classNode, name: methodName);
      if (methods.isEmpty) break;

      updated = AstModifier.removeMethodFromClass(
        source: updated,
        method: methods.first,
      );
    }
    return updated;
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
    // Use extensionNode.body.members instead of deprecated extensionNode.members
    final methods = extensionNode.body.members
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
    var updated = source;
    while (true) {
      final parseResult = parseSource(updated);
      final unit = parseResult.unit;
      if (unit == null) break;

      final classNode = findClass(unit, className);
      if (classNode == null) break;

      final fields = findFields(classNode, name: fieldName);
      if (fields.isEmpty) break;

      updated = AstModifier.removeField(source: updated, field: fields.first);
    }
    return updated;
  }

  String removeElementFromReturnListInFunction({
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
    return AstModifier.removeElementFromReturnListInFunction(
      source: source,
      functionNode: functionNode,
      elementSource: elementSource,
    );
  }

  String removeConstructorFromClass({
    required String source,
    required String className,
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
    final constructors = classNode.members.whereType<ConstructorDeclaration>();
    if (constructors.isEmpty) {
      return source;
    }
    final constructor = constructors.first;
    return source.substring(0, constructor.offset) +
        source.substring(constructor.end);
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

  bool isClassEmpty(String source, String className) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return false;
    }
    final classNode = findClass(unit, className);
    if (classNode == null) {
      return false;
    }
    return classNode.members.isEmpty;
  }
}
