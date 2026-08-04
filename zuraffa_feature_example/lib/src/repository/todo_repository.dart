import '../datasource/todo_local_datasource.dart';

/// Repository interface for todo operations.
abstract class TodoRepository {
  List<Map<String, dynamic>> getAll();
  void add(String title);
  void removeAt(int index);
  void toggleCompleted(int index);
}

/// Implementation backed by [TodoLocalDataSource].
class TodoRepositoryImpl implements TodoRepository {
  final TodoLocalDataSource _dataSource;

  TodoRepositoryImpl(this._dataSource);

  @override
  List<Map<String, dynamic>> getAll() => _dataSource.getAll();

  @override
  void add(String title) {
    _dataSource.add({'title': title, 'completed': false});
  }

  @override
  void removeAt(int index) => _dataSource.removeAt(index);

  @override
  void toggleCompleted(int index) => _dataSource.toggleCompleted(index);
}
