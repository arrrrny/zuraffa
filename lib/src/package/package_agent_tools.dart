import '../core/module/di_container.dart';
import '../core/module/mcp_tool.dart';
import '../core/module/mcp_tool_registry.dart';
import '../core/module/package_module.dart';

/// Namespaced agent-tool bridge for Zuraffa-native packages (spec 025,
/// FR-008/FR-009).
///
/// A package's [PackageModule] exposes its agent tools with plain,
/// un-namespaced usecase names. The consuming app merges them into its
/// agent tool registry via [registerInto], which applies the
/// `"$packageName.$toolName"` namespace — so `my_pkg`'s `do_something`
/// usecase surfaces as `my_pkg.do_something`, tools from different
/// packages never collide (FR-009), and tools are strictly import-scoped:
/// absent until the app registers the module's tools (FR-005 semantics).
///
/// ```dart
/// final registry = McpToolRegistry();
/// PackageAgentTools.registerInto(registry, MyPkgPackageModule());
/// // registry now exposes `my_pkg.do_something`, …
/// ```
class PackageAgentTools {
  const PackageAgentTools._();

  /// The canonical namespaced tool id for [toolName] contributed by
  /// [packageName].
  static String namespaced(String packageName, String toolName) =>
      '$packageName.$toolName';

  /// Registers every tool of [module] into [registry] under the module's
  /// package namespace, building the tools against [di] (the consuming
  /// app's container, populated by the module's registrar).
  ///
  /// Throws [StateError] (from [McpToolRegistry.register]) when a
  /// namespaced name is already taken — typically the same package
  /// registered twice, which is a wiring bug the operator must fix
  /// (FR-009: collision-safe, never silently overwritten).
  static void registerInto(
    McpToolRegistry registry,
    PackageModule module,
    ZuraffaDIContainer di,
  ) {
    for (final tool in module.buildAgentTools(di)) {
      registry.register(_NamespacedTool(module.packageName, tool));
    }
  }
}

/// A [McpTool] wrapper that presents [delegate] under a namespaced id
/// (`"$namespace.$name"`), delegating description/schema/execution
/// unchanged.
class _NamespacedTool implements McpTool {
  const _NamespacedTool(this.namespace, this.delegate);

  final String namespace;
  final McpTool delegate;

  @override
  String get name => PackageAgentTools.namespaced(namespace, delegate.name);

  @override
  String get description => delegate.description;

  @override
  Map<String, dynamic> get inputSchema => delegate.inputSchema;

  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) =>
      delegate.call(arguments);
}

/// Invokes a resolved usecase with the tool's arguments.
typedef PackageUseCaseInvoker<T> =
    Future<Object?> Function(T usecase, Map<String, dynamic> arguments);

/// A ready-made [McpTool] adapter that resolves a usecase from a DI
/// container and invokes it (spec 025, FR-008).
///
/// The tool executes against the container the package's module
/// registered into — the package's own dependency context — so the tool
/// never hand-constructs its dependencies. Errors (unregistered usecase,
/// execution failure) surface as `isError` results, never as exceptions
/// across the tool boundary.
///
/// ```dart
/// PackageUseCaseTool<GetProductUseCase>(
///   name: 'get_product',
///   description: 'Fetches a product by id',
///   container: engine.di,
///   invoke: (usecase, args) async =>
///       usecase(GetProductParams(id: args['id'] as String)),
/// )
/// ```
class PackageUseCaseTool<T extends Object> implements McpTool {
  PackageUseCaseTool({
    required this.name,
    required this.description,
    required this.container,
    required this.invoke,
    this.inputSchema = const {'type': 'object', 'additionalProperties': true},
  });

  @override
  final String name;

  @override
  final String description;

  /// The container the usecase is resolved from (the consuming app's
  /// container, populated by the package's registrar).
  final ZuraffaDIContainer container;

  /// Maps the tool arguments to a usecase invocation and returns its
  /// result.
  final PackageUseCaseInvoker<T> invoke;

  @override
  final Map<String, dynamic> inputSchema;

  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    try {
      final usecase = container.get<T>();
      final result = await invoke(usecase, arguments);
      return McpToolResult(text: result?.toString() ?? 'null');
    } catch (e) {
      return McpToolResult.error('Package usecase tool "$name" failed: $e');
    }
  }
}
