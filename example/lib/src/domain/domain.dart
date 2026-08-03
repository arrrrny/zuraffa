/// Domain layer barrel.
///
/// The domain layer is the innermost circle of Clean Architecture.
/// It contains entities, repository contracts, and use cases —
/// all independent of Flutter, Hive, HTTP, or any framework.
library;

export 'entities/todo.dart';
export 'repositories/todo_repository.dart';
export 'usecases/usecases.dart';
