import 'package:analyzer/dart/ast/ast.dart';

class NodeFinder {
  static ClassDeclaration? findClass(CompilationUnit unit, String className) {
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration &&
          declaration.namePart.beginToken.lexeme == className) {
        return declaration;
      }
    }
    return null;
  }

  static List<MethodDeclaration> findMethods(
    ClassDeclaration classNode, {
    String? name,
  }) {
    final body = classNode.body;
    if (body is! BlockClassBody) return [];
    final methods = body.members.whereType<MethodDeclaration>();
    if (name == null) {
      return methods.toList();
    }
    return methods.where((m) => m.name.toString() == name).toList();
  }

  static List<VariableDeclaration> findFields(
    ClassDeclaration classNode, {
    String? name,
  }) {
    final fields = <VariableDeclaration>[];
    final body = classNode.body;
    if (body is BlockClassBody) {
      // ignore: deprecated_member_use
      for (final member in body.members.whereType<FieldDeclaration>()) {
        for (final variable in member.fields.variables) {
          fields.add(variable);
        }
      }
    }
    if (name == null) {
      return fields;
    }
    // ignore: deprecated_member_use
    return fields.where((f) => f.name.lexeme == name).toList();
  }

  static ExtensionDeclaration? findExtension(
    CompilationUnit unit,
    String extensionName,
  ) {
    for (final declaration in unit.declarations) {
      if (declaration is ExtensionDeclaration &&
          declaration.name?.lexeme == extensionName) {
        return declaration;
      }
    }
    return null;
  }

  // ignore: deprecated_member_use
  static List<MethodDeclaration> findExtensionMethods(
    ExtensionDeclaration extensionNode, {
    String? name,
  }) {
    final body = extensionNode.body;
    final methods = body.members.whereType<MethodDeclaration>();
    if (name == null) {
      return methods.toList();
    }
    return methods.where((m) => m.name.toString() == name).toList();
  }

  static FunctionDeclaration? findFunction(
    CompilationUnit unit,
    String functionName,
  ) {
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration &&
          declaration.name.toString() == functionName) {
        return declaration;
      }
    }
    return null;
  }
}
