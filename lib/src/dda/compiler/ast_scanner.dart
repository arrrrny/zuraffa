import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../models/decorator_ast.dart';
import 'zorphy_decorator_plugin.dart';

/// Scans a Dart project for all decorator annotations and produces
/// [ScanResult]s containing [MethodAST] + [DecoratorAST] pairs.
class ASTScanner {
  ASTScanner({
    required this.projectRoot,
    this.includeGlobs = const ['lib/**/*.dart'],
    this.excludeGlobs = const ['lib/**/*.g.dart', 'lib/**/*.freezed.dart'],
  });

  final String projectRoot;
  final List<String> includeGlobs;
  final List<String> excludeGlobs;

  Future<List<ScanResult>> scan() async {
    final collection = AnalysisContextCollection(
      includedPaths: [p.absolute(projectRoot)],
    );
    final results = <ScanResult>[];
    final context = collection.contexts.first;

    for (final filePath in _dartFiles()) {
      final resolved = await context.currentSession.getResolvedUnit(filePath);
      if (resolved is! ResolvedUnitResult) continue;

      final visitor = _DecoratorVisitor(
        filePath: filePath,
        onDecorator: (methodAst, decoratorAst) {
          results.add(ScanResult(method: methodAst, decorator: decoratorAst));
        },
      );
      resolved.unit.accept(visitor);
    }

    return results;
  }

  List<String> _dartFiles() {
    final root = Directory(projectRoot);
    if (!root.existsSync()) return [];
    final files = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      if (_isExcluded(entity.path)) continue;
      if (!_isIncluded(entity.path)) continue;
      files.add(entity.path);
    }
    return files;
  }

  bool _isExcluded(String path) => excludeGlobs.any((p) => _globMatch(path, p));
  bool _isIncluded(String path) => includeGlobs.any((p) => _globMatch(path, p));

  bool _globMatch(String path, String pattern) {
    final regex = pattern
        .replaceAll('.', r'\.')
        .replaceAll('**', '<<<ANY_DIRS>>>')
        .replaceAll('*', '[^/]*')
        .replaceAll('<<<ANY_DIRS>>>', '.*');
    return RegExp(regex).hasMatch(path);
  }
}

class ScanResult {
  ScanResult({required this.method, required this.decorator});
  final MethodAST method;
  final DecoratorAST decorator;
}

class _DecoratorVisitor extends RecursiveAstVisitor<void> {
  _DecoratorVisitor({required this.filePath, required this.onDecorator});

  final String filePath;
  final void Function(MethodAST method, DecoratorAST decorator) onDecorator;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.namePart.typeName.lexeme;
    final classAst = MethodAST(
      name: className,
      elementKind: 'class',
      libraryUri: filePath,
    );

    for (final annotation in node.metadata) {
      final decorator = _parseAnnotation(annotation, classAst);
      if (decorator != null) onDecorator(classAst, decorator);
    }

    for (final member in node.body.members) {
      if (member is MethodDeclaration) {
        _visitMethod(member, className);
      }
    }
    super.visitClassDeclaration(node);
  }

  void _visitMethod(MethodDeclaration node, String className) {
    final methodAst = MethodAST(
      name: node.name.lexeme,
      elementKind: 'method',
      className: className,
      libraryUri: filePath,
      returnType: node.returnType?.toSource(),
      isAsync: node.body.isAsynchronous,
      isStatic: node.isStatic,
    );

    for (final annotation in node.metadata) {
      final decorator = _parseAnnotation(annotation, methodAst);
      if (decorator != null) onDecorator(methodAst, decorator);
    }
  }

  DecoratorAST? _parseAnnotation(Annotation annotation, MethodAST owner) {
    final name = annotation.name.name;
    if (name.startsWith('_')) return null;

    final posArgs = <String>[];
    final namedArgs = <String, dynamic>{};

    final args = annotation.arguments;
    if (args != null) {
      for (final arg in args.arguments) {
        if (arg is NamedArgument) {
          namedArgs[arg.name.lexeme] = arg.argumentExpression.toSource();
        } else {
          posArgs.add(arg.toSource());
        }
      }
    }

    return DecoratorAST(
      name: name,
      target: annotation,
      positionalArgs: posArgs,
      namedArgs: namedArgs,
    );
  }
}
