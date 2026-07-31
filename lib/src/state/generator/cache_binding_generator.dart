import 'package:code_builder/code_builder.dart' as cb;

import '../../dda/compiler/zorphy_decorator_plugin.dart';
import '../../dda/models/decorator_ast.dart';
import '../../dda/models/zorphy_context.dart';

/// DDA plugin that detects `@Cacheable` on UseCase return types
/// and generates cache observer bindings in DomainState.
///
/// When a UseCase is annotated with `@Cacheable`, the generated
/// DomainState automatically calls `.bindCache()` on the slice,
/// enabling cross-view state synchronization.
class CacheBindingPlugin extends ZorphyDecoratorPlugin {
  @override
  String get targetDecorator => 'Cacheable';

  @override
  void onApply(
    MethodAST method,
    DecoratorAST decorator,
    ZorphyContext context,
  ) {
    // Only apply to class-level decorators on repositories/datasources
    if (method.elementKind != 'class') return;

    final entityType = decorator.get<String>('entityType') ?? method.name;
    final strategy = decorator.get<String>('strategy') ?? 'offlineFirst';

    // Class-decorator injections are emitted by the dispatcher into the
    // generated `_<ClassName>Constructor._init()` extension body. The actual
    // cache binding (updates + deletes routed to a SignalSlice) is generated
    // by the state generator as `..bindCache()` on the slice — the runtime
    // CacheBinding extension — where a SignalSlice is in scope and the
    // subscription can be retained and cancelled. Emitting a functional
    // listener here would be dead code: there is no SignalSlice at the
    // repository/datasource level to route events into.
    context.addConstructorCode(
      cb.Code('// @Cacheable: $entityType (strategy: $strategy)'),
    );
  }
}

/// Configuration for cache binding generation.
class CacheBindingConfig {
  const CacheBindingConfig({this.enabled = false});

  /// Whether cache binding is enabled globally.
  /// Controlled by `.zfa.json` key `state.cacheBinding`.
  final bool enabled;

  factory CacheBindingConfig.fromJson(Map<String, dynamic> json) {
    return CacheBindingConfig(
      enabled: json['state']?['cacheBinding'] as bool? ?? false,
    );
  }
}
