import 'dart:io';

/// Zuraffa configuration from .env file
///
/// Supports:
/// - ENFORCE_ID=true/false - Require id field (default: false)
/// - AUTO_DETECT=true/false - Auto-detect Entity vs Value Object (default: true)
/// - DEFAULT_ID_TYPE=String/int - Preferred id type (default: String)
class ZuraffaConfig {
  final bool enforceId;
  final bool autoDetect;
  final String defaultIdType;

  ZuraffaConfig({
    required this.enforceId,
    required this.autoDetect,
    required this.defaultIdType,
  });

  /// Load config from .env file
  static ZuraffaConfig load(String projectPath) {
    final envFile = File('$projectPath/.env');

    // Defaults
    bool enforceId = false; // Allow Value Objects by default
    bool autoDetect = true; // Auto-detect by default
    String defaultIdType = 'String';

    if (envFile.existsSync()) {
      final lines = envFile.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();

        // Skip comments and empty lines
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        // Parse KEY=VALUE
        final parts = trimmed.split('=');
        if (parts.length != 2) continue;

        final key = parts[0].trim();
        final value = parts[1].trim();

        switch (key) {
          case 'ENFORCE_ID':
            enforceId = value.toLowerCase() == 'true';
            break;
          case 'AUTO_DETECT':
            autoDetect = value.toLowerCase() == 'true';
            break;
          case 'DEFAULT_ID_TYPE':
            if (value == 'String' || value == 'int') {
              defaultIdType = value;
            }
            break;
        }
      }
    }

    return ZuraffaConfig(
      enforceId: enforceId,
      autoDetect: autoDetect,
      defaultIdType: defaultIdType,
    );
  }

  @override
  String toString() {
    return 'ZuraffaConfig(enforceId: $enforceId, autoDetect: $autoDetect, defaultIdType: $defaultIdType)';
  }
}
