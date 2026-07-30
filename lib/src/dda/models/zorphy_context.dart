import 'package:code_builder/code_builder.dart' as cb;
import 'package:meta/meta.dart';

/// Injection point identifiers for the DDA pipeline.
enum InjectionPoint {
  beforeExecution,
  afterExecution,
  onException,
  wrapMethod,
  constructor,
  classTop,
}

/// Context passed to each [ZorphyDecoratorPlugin] during code generation.
///
/// [ZorphyContext] accumulates **type-safe AST fragments** (via
/// `package:code_builder`) at various [InjectionPoint]s. Plugins inject
/// expressions and specs for type-safe code generation.
class ZorphyContext {
  ZorphyContext({
    required this.className,
    required this.classLibraryUri,
    this.methodName,
    this.methodReturnType,
    this.methodParameters = const [],
    this.isAsync = false,
    this.isStatic = false,
    this.isGetter = false,
    this.isSetter = false,
  });

  // ── Element metadata ──

  final String className;
  final String classLibraryUri;
  final String? methodName;
  final String? methodReturnType;
  final List<ParameterInfo> methodParameters;
  final bool isAsync;
  final bool isStatic;
  final bool isGetter;
  final bool isSetter;

  bool get isClassDecorator => methodName == null;

  // ── AST injection ──

  final Map<InjectionPoint, List<cb.Code>> _statements = {};
  final List<cb.Spec> _classTopSpecs = [];
  final List<cb.Code> _constructorCode = [];

  /// Inject a [statement] at the specified [point].
  void injectStatement(InjectionPoint point, cb.Code code) {
    _statements.putIfAbsent(point, () => []).add(code);
  }

  /// Inject an [expression] (as a statement) at the specified [point].
  void injectExpression(InjectionPoint point, cb.Expression expression) {
    _statements.putIfAbsent(point, () => []).add(expression.statement);
  }

  /// Add a class-level spec to classTop.
  void addClassSpec(cb.Spec spec) {
    _classTopSpecs.add(spec);
  }

  /// Add constructor body code.
  void addConstructorCode(cb.Code code) {
    _constructorCode.add(code);
  }

  // ── Retrieval ──

  List<cb.Code> statementsFor(InjectionPoint point) =>
      List.unmodifiable(_statements[point] ?? const []);

  List<cb.Spec> get classTopSpecs => List.unmodifiable(_classTopSpecs);
  List<cb.Code> get constructorCode => List.unmodifiable(_constructorCode);

  /// Alias for [constructorCode] used by GenerationResult.
  List<cb.Code> get constructorSpecs => constructorCode;

  bool get hasInjections =>
      _statements.isNotEmpty ||
      _classTopSpecs.isNotEmpty ||
      _constructorCode.isNotEmpty;

  Set<InjectionPoint> get activePoints => Set.unmodifiable(_statements.keys);

  // ── Merge ──

  void merge(ZorphyContext other) {
    for (final e in other._statements.entries) {
      _statements.putIfAbsent(e.key, () => []).addAll(e.value);
    }
    _classTopSpecs.addAll(other._classTopSpecs);
    _constructorCode.addAll(other._constructorCode);
  }

  // ── Method wrapper builder ──

  /// Builds a [cb.Block] containing all injected statements surrounding
  /// the [originalBody].
  cb.Block buildMethodWrapper(cb.Block originalBody) {
    final before = statementsFor(InjectionPoint.beforeExecution);
    final after = statementsFor(InjectionPoint.afterExecution);
    final onExc = statementsFor(InjectionPoint.onException);
    // TODO: support wrapMethod injection point — requires restructuring
    // to nest wrapper Code objects around the body.

    return cb.Block((b) {
      if (onExc.isNotEmpty) {
        b.statements.add(cb.Code('try {'));
      }
      b.statements.addAll(before);
      b.statements.add(originalBody);
      b.statements.addAll(after);
      if (onExc.isNotEmpty) {
        b.statements.add(cb.Code('} catch (e, st) {'));
        b.statements.addAll(onExc);
        b.statements.add(cb.Code('  rethrow;'));
        b.statements.add(cb.Code('}'));
      }
    });
  }

  @override
  String toString() =>
      'ZorphyContext(class=$className, method=$methodName, '
      'code=${_statements.keys.toList()}, specs=${_classTopSpecs.length})';
}

@immutable
class ParameterInfo {
  const ParameterInfo({
    required this.name,
    required this.type,
    this.isNamed = false,
    this.isOptional = false,
    this.defaultValue,
  });

  final String name;
  final String type;
  final bool isNamed;
  final bool isOptional;
  final String? defaultValue;

  @override
  String toString() =>
      '${isNamed ? '{' : ''}${isOptional ? '' : 'required '}$type $name'
      '${defaultValue != null ? ' = $defaultValue' : ''}'
      '${isNamed ? '}' : ''}';
}
