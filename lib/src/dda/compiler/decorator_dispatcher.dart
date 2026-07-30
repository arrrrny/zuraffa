import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';

import '../models/decorator_ast.dart';
import '../models/zorphy_context.dart';
import 'ast_scanner.dart';
import 'zorphy_decorator_plugin.dart';

/// Dispatches scanned decorator annotations to their registered plugins
/// and accumulates generated code into [GenerationResult]s.
///
/// The dispatcher produces **type-safe AST** via `package:code_builder`,
/// then stringifies with `dart_style` for clean output.
class DecoratorDispatcher {
  DecoratorDispatcher({this.onUnknownDecorator, this.onParseError});

  final void Function(String decoratorName, SourceLocation? location)?
  onUnknownDecorator;
  final void Function(DecoratorParseError error)? onParseError;

  /// Process all [scanResults] and return per-file generation outputs.
  ///
  /// Results are sorted by plugin priority before dispatch so that
  /// higher-priority plugins (outer wrappers) are applied after
  /// lower-priority ones (inner wrappers).
  Map<String, GenerationResult> dispatch(List<ScanResult> scanResults) {
    final results = <String, GenerationResult>{};

    // Sort by plugin priority: lower priority first (innermost wrapper),
    // higher priority last (outermost wrapper). Stable sort preserves
    // original order for equal-priority decorators.
    final sorted = List<ScanResult>.from(scanResults);
    sorted.sort((a, b) {
      final pa = ZorphyPluginRegistry.get(a.decorator.name);
      final pb = ZorphyPluginRegistry.get(b.decorator.name);
      final priorityCompare = (pa?.priority ?? 0).compareTo(pb?.priority ?? 0);
      if (priorityCompare != 0) return priorityCompare;
      // Tie-breaker: preserve original order
      return scanResults.indexOf(a).compareTo(scanResults.indexOf(b));
    });

    for (final scan in sorted) {
      final decoratorName = scan.decorator.name;
      final plugin = ZorphyPluginRegistry.get(decoratorName);

      if (plugin == null) {
        onUnknownDecorator?.call(decoratorName, scan.decorator.sourceLocation);
        continue;
      }

      try {
        final ctx = _buildZorphyContext(scan.method);
        try {
          plugin.onApply(scan.method, scan.decorator, ctx);
        } catch (e) {
          onParseError?.call(
            DecoratorParseError(
              'Plugin $decoratorName failed: $e',
              sourceLocation: scan.decorator.sourceLocation,
            ),
          );
          continue;
        }

        if (ctx.hasInjections) {
          final filePath = scan.method.libraryUri ?? 'unknown.dart';
          results
              .putIfAbsent(filePath, () => GenerationResult(filePath: filePath))
              .add(scan.method, ctx);
        }
      } on DecoratorParseError catch (e) {
        onParseError?.call(e);
      }
    }

    return results;
  }

  ZorphyContext _buildZorphyContext(MethodAST method) {
    return ZorphyContext(
      className: method.className ?? method.name,
      classLibraryUri: method.libraryUri ?? '',
      methodName: method.isClass ? null : method.name,
      methodReturnType: method.returnType,
      methodParameters: method.parameters,
      isAsync: method.isAsync,
      isStatic: method.isStatic,
      isGetter: method.isGetter,
      isSetter: method.isSetter,
    );
  }
}

/// Aggregated generation result for a single source file.
class GenerationResult {
  GenerationResult({required this.filePath});

  final String filePath;
  final List<_AnnotatedElement> _elements = [];

  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  void add(MethodAST method, ZorphyContext context) {
    _elements.add(_AnnotatedElement(method: method, context: context));
  }

  List<_AnnotatedElement> get elements => List.unmodifiable(_elements);
  bool get hasCode => _elements.any((e) => e.context.hasInjections);

  /// Generate the complete `.g.dart` part file as formatted Dart code.
  String generatePartFile() {
    final library = cb.Library((b) {
      b.generatedByComment = 'zfa DDA pipeline';

      for (final element in _elements) {
        final ctx = element.context;
        final method = element.method;

        if (ctx.isClassDecorator) {
          for (final spec in ctx.classTopSpecs) {
            b.body.add(spec);
          }
          if (ctx.constructorSpecs.isNotEmpty) {
            b.body.add(
              cb.Extension(
                (e) => e
                  ..name = '_${method.name}Constructor'
                  ..on = cb.refer(method.name)
                  ..methods.add(
                    cb.Method.returnsVoid(
                      (m) => m
                        ..name = '_init'
                        ..body = cb.Block.of(
                          ctx.constructorCode.map((c) => c).toList(),
                        ),
                    ),
                  ),
              ),
            );
          }
        } else {
          final wrapper = cb.Method((m) {
            m
              ..name = '_\$${method.name}'
              ..returns = method.returnType != null
                  ? cb.refer(method.returnType!)
                  : null
              ..types.addAll(_parseTypeParams(method.returnType));

            for (final param in method.parameters) {
              final p = cb.Parameter((pb) {
                pb
                  ..name = param.name
                  ..type = cb.refer(param.type);
                if (param.isNamed) pb.named = true;
                if (param.isOptional && !param.isNamed) pb.required = false;
                if (!param.isOptional && param.isNamed) pb.required = true;
              });
              if (param.isNamed) {
                m.optionalParameters.add(p);
              } else {
                m.requiredParameters.add(p);
              }
            }

            final originalBody = cb.Block.of([
              cb.CodeExpression(cb.Code('// ORIGINAL BODY')).statement,
            ]);
            m.body = ctx.buildMethodWrapper(originalBody);
          });

          b.body.add(wrapper);
        }
      }
    });

    final emitter = cb.DartEmitter();
    final raw = library.accept(emitter).toString();
    return _formatter.format(raw);
  }

  List<cb.Reference> _parseTypeParams(String? typeStr) {
    if (typeStr == null) return [];
    final match = RegExp(r'<(.+)>').firstMatch(typeStr);
    if (match == null) return [];
    return match.group(1)!.split(',').map((s) => cb.refer(s.trim())).toList();
  }

  @override
  String toString() =>
      'GenerationResult($filePath, ${_elements.length} elements)';
}

class _AnnotatedElement {
  _AnnotatedElement({required this.method, required this.context});
  final MethodAST method;
  final ZorphyContext context;
}
