/// Secure, at-rest key/value storage seam (the analysis gap #1).
///
/// Auth tokens, subscription receipts, and session secrets need
/// encrypted-at-rest persistence — plaintext preferences are not an
/// option. [SecureStoragePort] is the technology-agnostic contract;
/// the built-in [InMemorySecureStorage] default keeps the package
/// pure-Dart and fully testable, while platform/keychain adapters plug
/// in behind the same interface in apps.
library;

/// Recoverable, typed secure-storage error.
class SecureStorageException implements Exception {
  /// Machine-readable reason, stable across releases.
  final String code;

  /// Human-readable description.
  final String message;

  const SecureStorageException(this.code, this.message);

  /// The key was not found (read/remove of an absent entry).
  factory SecureStorageException.notFound(String key) =>
      SecureStorageException('not_found', 'No secure entry under "$key".');

  /// The stored value could not be decoded.
  factory SecureStorageException.corrupt(String key) =>
      SecureStorageException('corrupt', 'Secure entry "$key" is unreadable.');

  @override
  String toString() => 'SecureStorageException($code): $message';
}

/// The secure-storage contract: typed JSON value storage at rest.
abstract class SecureStoragePort {
  /// Writes [value] under [key] (overwrites; atomic).
  Future<void> write(String key, Map<String, dynamic> value);

  /// Reads the value under [key], or `null` when absent. A corrupt entry
  /// is a typed [SecureStorageException.corrupt] (recoverable).
  Future<Map<String, dynamic>?> read(String key);

  /// Whether [key] exists.
  Future<bool> contains(String key);

  /// Removes [key]; returns whether an entry was removed.
  Future<bool> remove(String key);

  /// Removes every entry.
  Future<void> clear();
}

/// Pure-Dart default backend (test/dev): an in-memory map with an
/// optional corruption seam.
class InMemorySecureStorage implements SecureStoragePort {
  final Map<String, Map<String, dynamic>> _entries = {};

  /// Keys whose stored bytes are "corrupt" (simulate a damaged store);
  /// reading them throws [SecureStorageException.corrupt].
  final Set<String> corruptKeys = {};

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _entries[key] = Map<String, dynamic>.from(value);
    corruptKeys.remove(key);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    if (corruptKeys.contains(key)) {
      throw SecureStorageException.corrupt(key);
    }
    final value = _entries[key];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<bool> contains(String key) async => _entries.containsKey(key);

  @override
  Future<bool> remove(String key) async {
    corruptKeys.remove(key);
    return _entries.remove(key) != null;
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    corruptKeys.clear();
  }
}
