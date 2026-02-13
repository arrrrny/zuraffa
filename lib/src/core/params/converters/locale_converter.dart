import 'dart:ui';

/// Converter for [Locale] type.
///
/// Provides static methods for serializing and deserializing Locale objects.
///
/// Serializes a [Locale] to a JSON map with languageCode and optionally countryCode.
/// Deserializes a JSON map back to a [Locale].
///
/// Example:
/// ```dart
/// // Serialization
/// final locale = Locale('en', 'US');
/// final json = LocaleConverter.toJson(locale);
/// // json: {'languageCode': 'en', 'countryCode': 'US'}
///
/// // Deserialization
/// final decoded = LocaleConverter.fromJson({'languageCode': 'en', 'countryCode': 'US'});
/// // decoded: Locale('en', 'US')
/// ```
class LocaleConverter {
  LocaleConverter._();

  /// Deserializes a [Locale] from a JSON map.
  ///
  /// The JSON map should contain:
  /// - `languageCode`: The language code (e.g., 'en')
  /// - `countryCode`: The country code (e.g., 'US'), optional
  ///
  /// Defaults to 'en' if languageCode is missing or invalid.
  static Locale fromJson(Map<String, dynamic> json) {
    final languageCode = json['languageCode'] as String?;
    final countryCode = json['countryCode'] as String?;
    return Locale(languageCode ?? 'en', countryCode ?? '');
  }

  /// Serializes a [Locale] to a JSON map.
  ///
  /// The JSON map contains:
  /// - `languageCode`: The language code
  /// - `countryCode`: The country code (only if non-empty)
  static Map<String, dynamic> toJson(Locale locale) {
    return <String, dynamic>{
      'languageCode': locale.languageCode,
      if (locale.countryCode?.isNotEmpty ?? false)
        'countryCode': locale.countryCode,
    };
  }
}
