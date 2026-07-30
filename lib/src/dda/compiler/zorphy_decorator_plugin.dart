import '../models/decorator_ast.dart';
import '../models/zorphy_context.dart';

/// Abstract base class for all DDA (Decorator-Driven Architecture) plugins.
///
/// Each plugin handles one or more decorator names. When `zfa build` scans
/// the project and finds a matching annotation, it calls [onApply] with:
///
/// - [method]: metadata about the annotated element (class/method/field)
/// - [decorator]: the parsed `@DecoratorName(...)` with all arguments
/// - [context]: the mutable code-injection context (uses `package:code_builder`)
///
/// ## Priority
///
/// Plugins define a [priority] to control ordering when multiple plugins target
/// the same element. Higher-priority plugins are applied later, meaning their
/// wrappers end up outermost (e.g., tracing around auth).
abstract class ZorphyDecoratorPlugin {
  const ZorphyDecoratorPlugin();

  /// The decorator name this plugin handles, without the `@` prefix.
  String get targetDecorator;

  /// Priority for ordering when multiple plugins target the same method.
  ///
  /// Higher values → applied later → outermost wrapper.
  /// Default is 0. Infrastructure plugins (tracing, metrics): higher values.
  /// Fine-grained plugins (auth, validation): lower values.
  int get priority => 0;

  /// Called when the AST scanner finds [targetDecorator] on an element.
  void onApply(MethodAST method, DecoratorAST decorator, ZorphyContext context);

  /// Optional: called once per build before scanning begins.
  void onBuildStart(Map<String, dynamic> config) {}

  /// Optional: called once per build after all files are processed.
  void onBuildEnd(Map<String, dynamic> config) {}
}

/// Registry of all active decorator plugins.
class ZorphyPluginRegistry {
  static final Map<String, ZorphyDecoratorPlugin> _plugins = {};

  static void register(ZorphyDecoratorPlugin plugin) {
    _plugins[plugin.targetDecorator] = plugin;
  }

  static void registerAll(List<ZorphyDecoratorPlugin> plugins) {
    for (final p in plugins) register(p);
  }

  static ZorphyDecoratorPlugin? get(String decoratorName) =>
      _plugins[decoratorName];

  static bool has(String decoratorName) => _plugins.containsKey(decoratorName);

  static Set<String> get registeredDecorators =>
      Set.unmodifiable(_plugins.keys);

  static void clear() => _plugins.clear();
}

/// Metadata about the annotated element.
class MethodAST {
  MethodAST({
    required this.name,
    required this.elementKind,
    this.className,
    this.libraryUri,
    this.returnType,
    this.parameters = const [],
    this.isAsync = false,
    this.isStatic = false,
    this.isGetter = false,
    this.isSetter = false,
    this.isAbstract = false,
    this.superclassName,
    this.interfaces = const [],
    this.mixins = const [],
  });

  final String name;
  final String elementKind;
  final String? className;
  final String? libraryUri;
  final String? returnType;
  final List<ParameterInfo> parameters;
  final bool isAsync;
  final bool isStatic;
  final bool isGetter;
  final bool isSetter;
  final bool isAbstract;
  final String? superclassName;
  final List<String> interfaces;
  final List<String> mixins;

  bool get isClass => elementKind == 'class';
  bool get isMethod => elementKind == 'method';

  @override
  String toString() =>
      'MethodAST($elementKind: $name, class=$className, return=$returnType)';
}
