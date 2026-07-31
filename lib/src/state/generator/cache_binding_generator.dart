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

    // Inject cache binding into the constructor or class init
    context.addConstructorCode(
      cb.Code('// Cache binding: $entityType (strategy: $strategy)'),
    );

    // Mark this class as cache-backed for the state generator
    context.injectExpression(
      InjectionPoint.beforeExecution,
      cb.refer('CacheObserver.instance.listen<$entityType>').call([
        cb.Method(
          (m) => m
            ..requiredParameters.add(cb.Parameter((p) => p..name = 'entity'))
            ..body = cb.Block.of([
              cb.refer('_cacheUpdate').call([cb.refer('entity')]).statement,
            ]),
        ).closure,
      ]),
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
