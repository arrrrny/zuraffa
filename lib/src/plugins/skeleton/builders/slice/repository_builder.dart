/// Builds the repository layer of a working slice (042, FR-002).
library;

import '../../models/bone.dart';

/// Emits the clean-architecture boundary types for one entity: the abstract
/// repository, the abstract data-source interface it is implemented against,
/// and the data-layer implementation delegating to any data source.
class RepositoryBuilder {
  /// The abstract repository interface (domain layer).
  String buildRepositoryInterface(
    String entity, [
    List<EntityField> fields = const [],
  ]) {
    final snake = pascalToSnake(entity);
    return '''
import '../../entities/$snake.dart';

/// Contract for persisting [$entity] instances (clean-architecture boundary).
abstract class ${entity}Repository {
  /// Loads one $entity by id, or null when missing.
  Future<$entity?> get${entity}ById(String id);

  /// Loads every $entity.
  Future<List<$entity>> getAll${entity}s();

  /// Creates or updates the given $entity.
  Future<void> save$entity($entity instance);

  /// Deletes the $entity with [id]; missing ids are ignored.
  Future<void> delete$entity(String id);
}
''';
  }

  /// The abstract data-source interface mirroring the repository shape.
  String buildDataSourceInterface(String entity) {
    final snake = pascalToSnake(entity);
    return '''
import '../../entities/$snake.dart';

/// Transport-agnostic source/sink for [$entity] instances.
abstract class ${entity}DataSource {
  /// Loads one $entity by id, or null when missing.
  Future<$entity?> get${entity}ById(String id);

  /// Loads every $entity.
  Future<List<$entity>> getAll${entity}s();

  /// Creates or updates the given $entity.
  Future<void> save$entity($entity instance);

  /// Deletes the $entity with [id].
  Future<void> delete$entity(String id);
}
''';
  }

  /// The data-layer repository implementation delegating to a data source.
  String buildDataImplementation(String entity) {
    final snake = pascalToSnake(entity);
    return '''
import '../../domain/repositories/${snake}_repository.dart';
import '../../entities/$snake.dart';
import '../datasources/${snake}_datasource.dart';

/// [${entity}Repository] delegating to any [${entity}DataSource].
class Data${entity}Repository implements ${entity}Repository {
  const Data${entity}Repository(this.dataSource);

  final ${entity}DataSource dataSource;

  @override
  Future<$entity?> get${entity}ById(String id) =>
      dataSource.get${entity}ById(id);

  @override
  Future<List<$entity>> getAll${entity}s() => dataSource.getAll${entity}s();

  @override
  Future<void> save$entity($entity instance) =>
      dataSource.save$entity(instance);

  @override
  Future<void> delete$entity(String id) => dataSource.delete$entity(id);
}
''';
  }
}
