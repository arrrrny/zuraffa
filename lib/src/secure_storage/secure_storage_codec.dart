import 'dart:convert';

import 'secure_storage.dart';

/// JSON-string codec for [SecureStoragePort] entries — the wire form a
/// platform adapter stores inside its native vault (Keychain/Keystore/
/// encrypted file).
///
/// Keeping the codec here means every backend (and every test) shares one
/// serialization: an entry is a JSON object `{"k": key, "v": value}`;
/// decoding anything else raises [SecureStorageException.corrupt].
abstract final class SecureStorageCodec {
  /// Encodes [key]/[value] into the stored string form.
  static String encode(String key, Map<String, dynamic> value) =>
      jsonEncode({'k': key, 'v': value});

  /// Decodes a stored string; throws [SecureStorageException.corrupt]
  /// when malformed.
  static (String, Map<String, dynamic>) decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const SecureStorageException('corrupt', 'not valid JSON');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['k'] is! String ||
        decoded['v'] is! Map<String, dynamic>) {
      throw const SecureStorageException(
        'corrupt',
        'expected {"k": String, "v": Object}',
      );
    }
    return (decoded['k'] as String, decoded['v'] as Map<String, dynamic>);
  }
}
