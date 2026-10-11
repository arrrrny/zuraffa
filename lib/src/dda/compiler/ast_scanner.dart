import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart' as analyzer_utilities;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../models/decorator_ast.dart';
import '../models/zorphy_context.dart';
import 'zorphy_decorator_plugin.dart';

/// Scans a Dart project for all decorator annotations and produces
/// [ScanResult]s containing [MethodAST] + [DecoratorAST] pairs.
///
/// Two scan modes:
/// - **Resolved** (default): full analyzer resolution through an
///   [AnalysisContextCollection]. Slower; requires a valid package context
///   (pubspec.yaml). Use when element-level information is needed.
/// - **Syntactic** (`resolve: false`): parses each file with `parseString` —
///   no analysis context, no pubspec requirement, an order of magnitude
///   faster. Annotation metadata (names, arguments, locations) is purely
///   syntactic, so decorator scanning is identical. This is the mode the
///   route build stage uses (SC-002: <2s for ≤100 Views).
class ASTScanner {
  ASTScanner({
    required this.projectRoot,
    this.includeGlobs = const ['**/*.dart'],
    this.excludeGlobs = const ['**/*.g.dart', '**/*.freezed.dart'],
    this.resolve = true,
    this.contentFilter,
  });

  final String projectRoot;
  final List<String> includeGlobs;
  final List<String> excludeGlobs;

  /// When false, files are parsed syntactically (`parseString`) instead of
  /// resolved through an analysis context — see class docs.
  final bool resolve;

  /// Optional cheap pre-filter: files whose content does NOT match this
  /// pattern are skipped entirely (no parse, no resolve). Callers scanning
  /// for one decorator family (e.g. the route build stage) use this to stay
  /// inside tight time budgets on large projects.
  final RegExp? contentFilter;

  Future<List<ScanResult>> scan() async {
    final results = <ScanResult>[];

    if (!resolve) {
      for (final filePath in _dartFiles()) {
        final parsed = analyzer_utilities.parseString(
          content: File(filePath).readAsStringSync(),
          throwIfDiagnostics: false,
        );
        final visitor = _DecoratorVisitor(
          filePath: filePath,
          onDecorator: (methodAst, decoratorAst) {
            results.add(ScanResult(method: methodAst, decorator: decoratorAst));
          },
        );
        parsed.unit.accept(visitor);
      }
      return results;
    }

    final collection = AnalysisContextCollection(
      includedPaths: [p.absolute(projectRoot)],
      sdkPath: _resolveSdkPath(),
    );
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

  /// Resolves the Dart SDK path for the analysis context.
  ///
  /// In some Flutter CI environments [AnalysisContextCollection] fails to
  /// locate `libraries.dart` via its default heuristic (it resolves to the
  /// Flutter engine layout instead of the `dart-sdk`), which throws a
  /// [FileSystemException] during resolution. Pointing the collection at the
  /// real `dart-sdk` fixes resolution without affecting normal local runs.
  ///
  /// Returns `null` when no candidate SDK root carries the SDK metadata
  /// marker, letting the analyzer fall back to its default behavior.
  static String? _resolveSdkPath() {
    final candidates = <String>[];
    // Running `dart`/`flutter test` executable lives at `<sdk>/bin/dart`.
    candidates.add(p.dirname(p.dirname(Platform.resolvedExecutable)));
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      candidates.add(p.join(flutterRoot, 'bin', 'cache', 'dart-sdk'));
    }
    for (final candidate in candidates) {
      final marker = p.join(
        candidate,
        'lib',
        '_internal',
        'sdk_library_metadata',
        'lib',
        'libraries.dart',
      );
      if (File(marker).existsSync()) return candidate;
    }
    return null;
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
      if (contentFilter != null) {
        try {
          if (!contentFilter!.hasMatch(entity.readAsStringSync())) continue;
        } catch (_) {
          // Unreadable file: skip it.
          continue;
        }
      }
      files.add(entity.path);
    }
    // Deterministic order across runs (and filesystems) so generated output
    // is idempotent (US1 scenario 3).
    files.sort();
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
    final params = <ParameterInfo>[];
    final paramList = node.parameters;
    if (paramList != null) {
      for (final param in paramList.parameters) {
        params.add(
          ParameterInfo(
            name: param.name?.lexeme ?? 'unnamed',
            type: param.type?.toSource() ?? 'dynamic',
            isNamed: param.isNamed,
            isOptional: param.isOptional,
          ),
        );
      }
    }

    final methodAst = MethodAST(
      name: node.name.lexeme,
      elementKind: 'method',
      className: className,
      libraryUri: filePath,
      returnType: node.returnType?.toSource(),
      parameters: params,
      isAsync: node.body.isAsynchronous,
      isStatic: node.isStatic,
    );

    for (final annotation in node.metadata) {
      final decorator = _parseAnnotation(annotation, methodAst);
      if (decorator != null) onDecorator(methodAst, decorator);
    }
  }

  DecoratorAST? _parseAnnotation(Annotation annotation, MethodAST owner) {
    // For named-constructor annotations (`@Route.redirect(...)`), analyzer
    // 14.x exposes the WHOLE prefixed form ('Route.redirect') through
    // `annotation.name.name` and leaves `constructorName` null. Derive the
    // base class name and the constructor name from the dotted form. (A
    // library-prefixed annotation `@prefix.Name` is syntactically
    // indistinguishable; decorator consumers in this codebase do not use
    // library prefixes, so the constructor reading is the useful one.)
    final rawName = annotation.name.name;
    final String name;
    final String? ctorFromName;
    if (rawName.contains('.')) {
      final parts = rawName.split('.');
      name = parts.first;
      ctorFromName = parts.skip(1).join('.');
    } else {
      name = rawName;
      ctorFromName = null;
    }
    final constructorName = annotation.constructorName?.name ?? ctorFromName;
    if (name.startsWith('_')) return null;

    final posArgs = <dynamic>[];
    final namedArgs = <String, dynamic>{};

    final args = annotation.arguments;
    if (args != null) {
      for (final arg in args.arguments) {
        if (arg is NamedArgument) {
          namedArgs[arg.name.lexeme] = _parseLiteral(arg.argumentExpression);
        } else {
          posArgs.add(_parseLiteral(arg.argumentExpression));
        }
      }
    }

    final offset = annotation.offset;
    final root = annotation.root;
    final lineInfo = root is CompilationUnit ? root.lineInfo : null;
    final location = lineInfo != null
        ? SourceLocation(
            filePath: filePath,
            line: lineInfo.getLocation(offset).lineNumber,
            column: lineInfo.getLocation(offset).columnNumber,
            offset: offset,
          )
        : null;

    return DecoratorAST(
      name: name,
      constructorName: constructorName,
      target: annotation,
      positionalArgs: posArgs,
      namedArgs: namedArgs,
      sourceLocation: location,
    );
  }

  /// Converts an annotation argument expression into a typed value.
  ///
  /// - String literals lose their quotes: `'/home'` → the String `/home`.
  /// - Bool / int / double / null literals become Dart bool / int / double /
  ///   null.
  /// - List literals become `List<String>` of their elements' raw sources
  ///   (`[AuthGuard]` → `['AuthGuard']`).
  /// - Everything else (maps, constructor calls, identifiers, expressions)
  ///   stays the raw source string for the owning plugin to parse.
  Object? _parseLiteral(Expression expr) {
    if (expr is SingleStringLiteral) {
      // SimpleStringLiteral covers plain '...' and "..." literals without
      // interpolation; AdjacentStrings/StringInterpolation fall through to
      // the raw-source branch.
      if (expr is SimpleStringLiteral) {
        return expr.value;
      }
      return expr.toSource();
    }
    if (expr is BooleanLiteral) return expr.value;
    if (expr is IntegerLiteral) return expr.value;
    if (expr is DoubleLiteral) return double.parse(expr.literal.lexeme);
    if (expr is NullLiteral) return null;
    if (expr is ListLiteral) {
      return expr.elements.map((e) => e.toSource()).toList();
    }
    return expr.toSource();
  }
}
