/// Converter for locale data.
///
/// Uses a lightweight [Locale] value class instead of
/// `dart:ui` Locale so this file works in pure Dart.
class Locale {
  final String languageCode;
  final String? countryCode;

  const Locale(this.languageCode, [this.countryCode]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Locale &&
          languageCode == other.languageCode &&
          countryCode == other.countryCode;

  @override
  int get hashCode => Object.hash(languageCode, countryCode);

  @override
  String toString() =>
      countryCode != null ? '${languageCode}_$countryCode' : languageCode;
}

/// Converter for [Locale] type.
///
/// Provides static methods for serializing and deserializing Locale objects.
class LocaleConverter {
  LocaleConverter._();

  /// Deserializes a [Locale] from a JSON map.
  static Locale fromJson(Map<String, dynamic> json) {
    final languageCode = json['languageCode'] as String?;
    final countryCode = json['countryCode'] as String?;
    return Locale(languageCode ?? 'en', countryCode ?? '');
  }

  /// Serializes a [Locale] to a JSON map.
  static Map<String, dynamic> toJson(Locale locale) {
    return <String, dynamic>{
      'languageCode': locale.languageCode,
      if (locale.countryCode?.isNotEmpty ?? false)
        'countryCode': locale.countryCode,
    };
  }
}
