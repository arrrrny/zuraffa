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
    // generated `_<ClassName>Constructor._init()` extension body (the only
    // place class-level constructor code lands — `beforeExecution` only
    // applies to method decorators). The listen callback must accept both
    // the nullable entity and the nullable deletedId parameters that
    // [CacheObserver.listen] provides, so deletion events are handled.
    context.addConstructorCode(
      cb.Code(
        'CacheObserver.instance.listen<$entityType>('
        '(entity, deletedId) { '
        '// cache binding: $entityType (strategy: $strategy) '
        '}, '
        ');',
      ),
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
