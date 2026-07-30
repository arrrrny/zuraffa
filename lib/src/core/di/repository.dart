/// Marks a class as a repository implementation.
///
/// ```dart
/// @Repository()
/// class ProductRepositoryImpl implements ProductRepository { ... }
/// ```
class Repository {
  const Repository({this.name});

  /// Logical name for this repository. Defaults to the class name.
  final String? name;
}
