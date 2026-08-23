/// Localization seam (the last §4 built-in): locale negotiation, typed
/// translation lookup with parameters, pluralization, and live locale
/// switching — pure Dart, no Flutter dependency.
library;

/// A BCP-47-ish locale tag (language[-region]).
class AppLocale {
  /// Language subtag, lowercase (e.g. `en`, `tr`).
  final String language;

  /// Optional region subtag, uppercase (e.g. `US`, `TR`); null when absent.
  final String? region;

  const AppLocale(this.language, [this.region]);

  /// Parses `en`, `en_US`, `en-US`, `tr_TR` into an [AppLocale].
  factory AppLocale.parse(String tag) {
    final normalized = tag.trim().replaceAll('-', '_');
    final parts = normalized.split('_');
    final language = parts.first.toLowerCase();
    final region = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].toUpperCase()
        : null;
    return AppLocale(language, region);
  }

  /// The canonical tag form (`en`, `en_US`).
  String get tag => region == null ? language : '${language}_$region';

  /// The language-only fallback locale.
  AppLocale get languageOnly => AppLocale(language);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLocale &&
          other.language == language &&
          other.region == region;

  @override
  int get hashCode => Object.hash(language, region);

  @override
  String toString() => tag;
}

/// Plural categories (CLDR cardinal plurals).
enum PluralCategory { zero, one, two, few, many, other }

/// Recovers the CLDR cardinal plural category for [count] in [locale].
///
/// Covers the rule shapes used by the languages zuraffa apps ship in
/// today (en/tr/de/es/fr and friends); adapters with full CLDR rules
/// override via their own plural provider. English defaults otherwise.
PluralCategory pluralCategoryFor(int count, AppLocale locale) {
  switch (locale.language) {
    case 'tr':
      // Turkish: singular only at exactly 1.
      return count == 1 ? PluralCategory.one : PluralCategory.other;
    case 'en':
    case 'de':
    case 'es':
    case 'it':
    case 'pt':
      return count == 1 ? PluralCategory.one : PluralCategory.other;
    case 'fr':
      return count == 0 || count == 1
          ? PluralCategory.one
          : PluralCategory.many;
    case 'ar':
      if (count == 0) return PluralCategory.zero;
      if (count == 1) return PluralCategory.one;
      if (count == 2) return PluralCategory.two;
      if (count % 100 >= 3 && count % 100 <= 10) return PluralCategory.few;
      if (count % 100 >= 11) return PluralCategory.many;
      return PluralCategory.other;
    case 'zh':
    case 'ja':
    case 'ko':
      return PluralCategory.other;
    default:
      return count == 1 ? PluralCategory.one : PluralCategory.other;
  }
}

/// Recoverable, typed i18n error.
class I18nException implements Exception {
  /// Machine-readable reason, stable across releases.
  final String code;

  /// Human-readable description.
  final String message;

  const I18nException(this.code, this.message);

  /// A translations table for a locale failed to load.
  factory I18nException.loadFailed(String locale, String detail) =>
      I18nException(
        'load_failed',
        'Translations for "$locale" failed to load: $detail',
      );

  @override
  String toString() => 'I18nException($code): $message';
}

/// A resolved translation with its substitutions already applied.
class ResolvedMessage {
  /// The resolved, human-readable string.
  final String text;

  /// The locale the message resolved in (may be a fallback locale).
  final AppLocale resolvedLocale;

  /// Whether resolution fell back to a locale other than the requested one.
  final bool usedFallback;

  const ResolvedMessage(
    this.text,
    this.resolvedLocale, {
    this.usedFallback = false,
  });
}

/// The localization contract.
abstract class I18nPort {
  /// The currently active locale.
  AppLocale get locale;

  /// Switches the active locale (loads its table if needed) and notifies
  /// listeners.
  Future<void> setLocale(AppLocale locale);

  /// Translates [key] with [params] (`{name}` placeholders); pluralizes
  /// via [pluralCount] against `key.one`/`key.other`-style subkeys.
  ResolvedMessage translate(
    String key, {
    Map<String, Object?> params = const {},
    int? pluralCount,
  });

  /// Subscribes to locale changes; returns the unsubscribe function.
  void Function() onLocaleChanged(void Function(AppLocale locale) listener);
}

/// The message table shape: locale tag → (key → message).
typedef TranslationTable = Map<String, Map<String, String>>;
