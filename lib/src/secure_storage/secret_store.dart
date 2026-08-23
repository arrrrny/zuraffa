import 'package:get_it/get_it.dart';

import 'secure_storage.dart';

export 'secure_storage.dart';

/// App-facing convenience over [SecureStoragePort]: typed accessors for
/// the two shapes every caller stores — tokens (String) and arbitrary
/// JSON maps — plus raw map access.
///
/// ```dart
/// final secrets = SecretStore();
/// await secrets.saveToken('auth', 'tok-1');
/// await secrets.readToken('auth'); // 'tok-1'
/// ```
class SecretStore {
  /// The storage backend (in-memory default; inject a platform adapter).
  final SecureStoragePort storage;

  SecretStore({SecureStoragePort? storage})
    : storage = storage ?? InMemorySecureStorage();

  // ── raw maps ─────────────────────────────────────────────────────────

  /// Writes a raw JSON map under [key].
  Future<void> write(String key, Map<String, dynamic> value) =>
      storage.write(key, value);

  /// Reads a raw JSON map; `null` when absent.
  Future<Map<String, dynamic>?> read(String key) => storage.read(key);

  /// Whether [key] exists.
  Future<bool> contains(String key) => storage.contains(key);

  /// Removes [key]; returns whether an entry was removed.
  Future<bool> remove(String key) => storage.remove(key);

  /// Clears every entry.
  Future<void> clear() => storage.clear();

  // ── tokens ───────────────────────────────────────────────────────────

  /// Saves an opaque token string under [key].
  Future<void> saveToken(String key, String token) =>
      storage.write(key, {'token': token});

  /// Reads the token under [key], or `null` when absent.
  Future<String?> readToken(String key) async {
    final entry = await storage.read(key);
    final token = entry?['token'];
    return token is String ? token : null;
  }

  // ── typed accessors ─────────────────────────────────────────────────

  /// Saves a typed entry under [key] via its [toJson].
  Future<void> saveObject<T>(
    String key,
    T value,
    Map<String, dynamic> Function(T) toJson,
  ) => storage.write(key, toJson(value));

  /// Reads a typed entry under [key] via [fromJson]; `null` when absent.
  Future<T?> readObject<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final entry = await storage.read(key);
    return entry == null ? null : fromJson(entry);
  }
}

/// Registers the secure-storage stack onto [getIt].
///
/// ```dart
/// registerSecureStorageDependencies(getIt);
/// final secrets = getIt<SecretStore>();
/// ```
void registerSecureStorageDependencies(
  GetIt getIt, {
  SecureStoragePort? storage,
}) {
  getIt
    ..registerLazySingleton<SecureStoragePort>(
      () => storage ?? InMemorySecureStorage(),
    )
    ..registerLazySingleton<SecretStore>(
      () => SecretStore(storage: getIt<SecureStoragePort>()),
    );
}
