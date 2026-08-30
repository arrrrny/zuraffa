/// Builds the CRUD use cases of a working slice (042, FR-003).
library;

import '../../models/bone.dart';

/// Emits Get/Create/Update/Delete use cases per entity — the same shape
/// `zfa make` produces: repository injected via constructor, `call` method.
class UseCaseBuilder {
  /// Builds all four use case files for [entity].
  ///
  /// Returns a map of file name → Dart source.
  Map<String, String> buildAll(String entity) {
    final snake = pascalToSnake(entity);
    return {
      'get_${snake}_usecase.dart': _build(entity, 'Get', 'ById'),
      'create_${snake}_usecase.dart': _build(entity, 'Create', 'Save'),
      'update_${snake}_usecase.dart': _build(entity, 'Update', 'Save'),
      'delete_${snake}_usecase.dart': _build(entity, 'Delete', 'Delete'),
    };
  }

  String _build(String entity, String verb, String target) {
    final snake = pascalToSnake(entity);
    final buffer = StringBuffer();
    // The delete use case only passes the id through, so the entity type is
    // unused there — skip its import to keep generated code warning-free.
    if (target != 'Delete') {
      buffer.writeln("import '../../entities/$snake.dart';");
    }
    buffer.writeln("import '../repositories/${snake}_repository.dart';");
    buffer.writeln();
    buffer.writeln(
      '/// ${verb == 'Get'
          ? 'Loads'
          : verb == 'Create'
          ? 'Creates'
          : verb == 'Update'
          ? 'Updates'
          : 'Deletes'} '
      'a $entity through the injected repository.',
    );
    buffer.writeln('class $verb${entity}UseCase {');
    buffer.writeln('  const $verb${entity}UseCase(this.repository);');
    buffer.writeln();
    buffer.writeln('  final ${entity}Repository repository;');
    buffer.writeln();
    if (target == 'ById') {
      buffer.writeln('  /// Fetches the $entity with [id], or null.');
      buffer.writeln(
        '  Future<$entity?> call(String id) => repository.get${entity}ById(id);',
      );
    } else if (target == 'Save') {
      buffer.writeln('  /// Creates or updates [instance].');
      buffer.writeln(
        '  Future<void> call($entity instance) => '
        'repository.save$entity(instance);',
      );
    } else {
      buffer.writeln('  /// Deletes the $entity with [id].');
      buffer.writeln(
        '  Future<void> call(String id) => repository.delete$entity(id);',
      );
    }
    buffer.writeln('}');
    return buffer.toString();
  }
}
