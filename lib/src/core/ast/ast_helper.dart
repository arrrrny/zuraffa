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
}
