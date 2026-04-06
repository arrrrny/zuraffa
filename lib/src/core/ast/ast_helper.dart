import 'package:analyzer/dart/ast/ast.dart';

import '../context/file_system.dart';
import 'ast_modifier.dart';
import 'file_parser.dart';
import 'node_finder.dart';

class AstHelper {
  final FileParser parser;

  const AstHelper({this.parser = const FileParser()});

  Future<AstParseResult> parseFile(String path, {FileSystem? fileSystem}) {
    return parser.parseFile(path, fileSystem: fileSystem);
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

  String addImport({
    required String source,
    required String importPath,
    bool format = true,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    return AstModifier.addImport(source, unit, importPath, format: format);
  }

  String addExport({
    required String source,
    required String exportPath,
    bool format = true,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) {
      return source;
    }
    return AstModifier.addExport(source, unit, exportPath, format: format);
  }

  String addMethodToClass({
    required String source,
    required String className,
    required String methodSource,
    bool format = true,
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
      format: format,
    );
  }

  String replaceMethodInClass({
    required String source,
    required String className,
    required String methodName,
    required String methodSource,
    bool format = true,
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
      format: format,
    );
  }

  String replaceConstructorInClass({
    required String source,
    required String className,
    required String constructorSource,
    bool format = true,
  }) {
    final parseResult = parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) return source;
    final classNode = findClass(unit, className);
    if (classNode == null) return source;
    final constructors = classNode.body.members
        .whereType<ConstructorDeclaration>();
    if (constructors.isEmpty) return source;

    return AstModifier.replaceConstructorInClass(
      source: source,
      classNode: classNode,
      oldConstructor: constructors.first,
      constructorSource: constructorSource,
      format: format,
    );
  }

  String replaceFieldInClass({
    required String source,
    required String className,
    required String fieldName,
    required String fieldSource,
    bool format = true,
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
      format: format,
    );
  }

  String removeMethodFromClass({
    required String source,
    required String className,
    required String methodName,
    bool format = true,
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
        format: false, // Don't format inside loop
      );
    }
    return format ? AstModifier.format(updated) : updated;
  }

  String removeMethodFromExtension({
    required String source,
    required String extensionName,
    required String methodName,
    bool format = true,
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
    final body = extensionNode.body;
    final methods = body.members
        .whereType<MethodDeclaration>()
        .where((m) => m.name.lexeme == methodName)
        .toList();
    if (methods.isEmpty) {
      return source;
    }
    return AstModifier.removeMethodFromClass(
      source: source,
      method: methods.first,
      format: format,
    );
  }

  String removeFieldFromClass({
    required String source,
    required String className,
    required String fieldName,
    bool format = true,
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

      updated = AstModifier.removeField(
        source: updated,
        field: fields.first,
        format: false, // Don't format inside loop
      );
    }
    return format ? AstModifier.format(updated) : updated;
  }

  String removeElementFromReturnListInFunction({
    required String source,
    required String functionName,
    required String elementSource,
    bool format = true,
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
      format: format,
    );
  }

  String removeConstructorFromClass({
    required String source,
    required String className,
    bool format = true,
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
    final body = classNode.body;
    if (body is! BlockClassBody) return source;
    final constructors = body.members.whereType<ConstructorDeclaration>();
    if (constructors.isEmpty) {
      return source;
    }
    final constructor = constructors.first;
    final result =
        source.substring(0, constructor.offset) +
        source.substring(constructor.end);
    return format ? AstModifier.format(result) : result;
  }

  String addFieldToClass({
    required String source,
    required String className,
    required String fieldSource,
    bool format = true,
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
      format: format,
    );
  }

  String addMethodToExtension({
    required String source,
    required String extensionName,
    required String methodSource,
    bool format = true,
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
      format: format,
    );
  }

  String addStatementToFunction({
    required String source,
    required String functionName,
    required String statementSource,
    bool format = true,
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
      format: format,
    );
  }

  String addElementToReturnListInFunction({
    required String source,
    required String functionName,
    required String elementSource,
    bool format = true,
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
      format: format,
    );
  }

  String removeStatementFromFunction({
    required String source,
    required String functionName,
    required String statementSource,
    bool format = true,
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
    final body = functionNode.functionExpression.body;
    if (body is! BlockFunctionBody) {
      return source;
    }
    return AstModifier.removeStatement(
      source: source,
      statements: body.block.statements,
      statementSource: statementSource,
      format: format,
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
    final body = classNode.body;
    return body is BlockClassBody && body.members.isEmpty;
  }

  /// Returns true if two method declarations are structurally equal
  /// (including return type, parameters, and body).
  static bool areMethodsEqual(MethodDeclaration a, MethodDeclaration b) {
    if (a.name.lexeme != b.name.lexeme) return false;
    if (a.returnType?.toSource() != b.returnType?.toSource()) return false;
    if (a.parameters?.parameters.length != b.parameters?.parameters.length) {
      return false;
    }

    final paramsA = a.parameters?.parameters ?? [];
    final paramsB = b.parameters?.parameters ?? [];

    for (var i = 0; i < paramsA.length; i++) {
      if (paramsA[i].toSource() != paramsB[i].toSource()) return false;
    }

    if (a.body.toSource() != b.body.toSource()) return false;

    return true;
  }

  /// Returns true if two constructor declarations are structurally equal
  /// (including parameters and initializers).
  static bool areConstructorsEqual(
    ConstructorDeclaration a,
    ConstructorDeclaration b,
  ) {
    if (a.name?.lexeme != b.name?.lexeme) return false;
    if (a.parameters.parameters.length != b.parameters.parameters.length) {
      return false;
    }

    final paramsA = a.parameters.parameters;
    final paramsB = b.parameters.parameters;

    for (var i = 0; i < paramsA.length; i++) {
      if (paramsA[i].toSource() != paramsB[i].toSource()) return false;
    }

    if (a.initializers.length != b.initializers.length) return false;
    for (var i = 0; i < a.initializers.length; i++) {
      if (a.initializers[i].toSource() != b.initializers[i].toSource()) {
        return false;
      }
    }

    if (a.body.toSource() != b.body.toSource()) return false;

    return true;
  }

  /// Returns true if two variable declarations (fields) are equal
  /// (including type and name).
  static bool areFieldsEqual(VariableDeclaration a, VariableDeclaration b) {
    if (a.name.lexeme != b.name.lexeme) return false;
    final parentA = a.parent;
    final parentB = b.parent;
    if (parentA is VariableDeclarationList &&
        parentB is VariableDeclarationList) {
      if (parentA.type?.toSource() != parentB.type?.toSource()) return false;
    }
    return true;
  }
}
