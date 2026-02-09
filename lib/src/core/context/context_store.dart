typedef VoidCallback = void Function();

class ContextStore {
  final Map<String, dynamic> _data = {};
  final Map<String, Set<VoidCallback>> _listeners = {};

  T get<T>(String key, {T Function()? defaultValue}) {
    if (_data.containsKey(key)) {
      final value = _data[key];
      if (value is T) {
        return value;
      }
      throw StateError('Key has different type: $key');
    }
    if (defaultValue != null) {
      return defaultValue();
    }
    throw StateError('Key not found: $key');
  }

  T? getOrNull<T>(String key) {
    if (_data.containsKey(key)) {
      final value = _data[key];
      if (value is T) {
        return value;
      }
      return null;
    }
    return null;
  }

  void set<T>(String key, T value) {
    final previous = _data[key];
    _data[key] = value;
    _notifyListeners(key, previous, value);
  }

  void remove(String key) {
    final previous = _data[key];
    _data.remove(key);
    _notifyListeners(key, previous, null);
  }

  bool has(String key) => _data.containsKey(key);

  void clear() {
    _data.clear();
    _listeners.clear();
  }

  void addListener(String key, VoidCallback callback) {
    _listeners.putIfAbsent(key, () => <VoidCallback>{}).add(callback);
  }

  void removeListener(String key, VoidCallback callback) {
    _listeners[key]?.remove(callback);
  }

  void _notifyListeners(String key, dynamic previous, dynamic current) {
    for (final callback in _listeners[key] ?? const <VoidCallback>{}) {
      callback();
    }
  }

  Map<String, dynamic> toJson() => Map.unmodifiable(_data);
}
