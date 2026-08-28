/// Re-export of Zuraffa's [ZuraffaDIContainer] for the TUI plugin's DI surface.
///
/// The TUI plugin resolves dependencies through the caller's existing
/// [ZuraffaDIContainer] and its underlying [GetIt] instance (FR-008). It does
/// NOT create a separate container — this file just re-exports the existing
/// type so TUI consumers only need a single import.
///
/// ```dart
/// import 'package:zuraffa/src/plugins/tui/di/tui_di_resolver.dart';
///
/// final di = ZuraffaDIContainer(); // wraps GetIt.instance by default
/// final repo = di.get<ProductRepository>();
/// ```
library;

import 'package:get_it/get_it.dart';

import '../../../core/module/di_container.dart';

export '../../../core/module/di_container.dart' show ZuraffaDIContainer;

/// Thin wrapper that resolves dependencies through the caller-supplied
/// [ZuraffaDIContainer].
///
/// Pure indirection layer: every call delegates to [container.getIt]. The
/// class exists so that TUI code can name a single resolution surface
/// (`TuiDiResolver.of(context)`) and so tests can substitute a fake
/// container without touching [GetIt] directly.
class TuiDiResolver {
  /// Creates a resolver that delegates to [container].
  ///
  /// [container] MUST be the caller's existing [ZuraffaDIContainer]. The
  /// resolver never constructs its own container (FR-008).
  const TuiDiResolver(this.container);

  /// The caller-supplied DI container backing this resolver.
  final ZuraffaDIContainer container;

  /// Resolves a registered dependency of type [T].
  ///
  /// Delegates to `container.getIt<T>()` so registrations made through the
  /// caller's [ZuraffaDIContainer.registerLazySingleton] etc. are visible.
  T call<T extends Object>() => container.getIt<T>();

  /// Resolves a registered dependency of type [T] (named form).
  T get<T extends Object>() => container.getIt<T>();

  /// Whether [T] is registered with the underlying container.
  bool isRegistered<T extends Object>() => container.getIt.isRegistered<T>();

  @override
  String toString() => 'TuiDiResolver(container: $container)';
}
