import 'dependency_scope.dart';

/// Marks a class as a datasource implementation.
///
/// ```dart
/// @Datasource(name: 'stripe_api', scope: DependencyScope.singleton, env: ['prod'])
/// class StripeApiDatasource implements PaymentDatasource { ... }
/// ```
class Datasource {
  const Datasource({
    this.name,
    this.scope = DependencyScope.singleton,
    this.env = const ['*'],
  });

  /// Logical name for this datasource. Defaults to the class name.
  final String? name;

  /// Lifecycle scope.
  final DependencyScope scope;

  /// Environments where this datasource is active.
  /// `['*']` means all environments.
  final List<String> env;
}
