/// In-memory data source for todo items.
class TodoLocalDataSource {
  final List<Map<String, dynamic>> _store = [];

  /// Returns all stored todo items as immutable snapshots.
  List<Map<String, dynamic>> getAll() => List.unmodifiable(
        _store.map((todo) => Map<String, dynamic>.unmodifiable(todo)),
      );

  /// Adds a [todo] to the store and returns its index.
  int add(Map<String, dynamic> todo) {
    _store.add(Map<String, dynamic>.from(todo));
    return _store.length - 1;
  }

  /// Removes the todo at [index].
  void removeAt(int index) {
    if (index >= 0 && index < _store.length) {
      _store.removeAt(index);
    }
  }

  /// Toggles the 'completed' field at [index].
  void toggleCompleted(int index) {
    if (index >= 0 && index < _store.length) {
      _store[index] = Map<String, dynamic>.from(_store[index])
        ..['completed'] = !(_store[index]['completed'] as bool? ?? false);
    }
  }

  /// Seeds the store with sample data.
  void seed() {
    _store
      ..clear()
      ..addAll([
        {'title': 'Buy groceries', 'completed': false},
        {'title': 'Read a book', 'completed': true},
        {'title': 'Write code', 'completed': false},
      ]);
  }
}
