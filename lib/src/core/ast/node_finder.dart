import 'package:analyzer/dart/ast/ast.dart';

class NodeFinder {
  static ClassDeclaration? findClass(CompilationUnit unit, String className) {
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration &&
          declaration.namePart.typeName.lexeme == className) {
        return declaration;
      }
    }
    return null;
  }

  static List<MethodDeclaration> findMethods(
    ClassDeclaration classNode, {
    String? name,
  }) {
    final methods = classNode.body.childEntities.whereType<MethodDeclaration>();
    if (name == null) {
      return methods.toList();
    }
    return methods.where((m) => m.name.lexeme == name).toList();
  }

  static List<VariableDeclaration> findFields(
    ClassDeclaration classNode, {
    String? name,
  }) {
    final fields = <VariableDeclaration>[];
    for (final member
        in classNode.body.childEntities.whereType<FieldDeclaration>()) {
      for (final variable in member.fields.variables) {
        fields.add(variable);
      }
    }
    if (name == null) {
      return fields;
    }
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

  static List<MethodDeclaration> findExtensionMethods(
    ExtensionDeclaration extensionNode, {
    String? name,
  }) {
    final methods = extensionNode.body.members.whereType<MethodDeclaration>();
    if (name == null) {
      return methods.toList();
    }
    return methods.where((m) => m.name.lexeme == name).toList();
  }

  static FunctionDeclaration? findFunction(
    CompilationUnit unit,
    String functionName,
  ) {
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration &&
          declaration.name.lexeme == functionName) {
        return declaration;
      }
    }
    return null;
  }
}
