import 'package:get_it/get_it.dart';

import 'i18n.dart';

export 'i18n.dart';

/// Pure-Dart [I18nPort] implementation: an in-memory table-backed
/// translator with locale fallback chains and live switching.
class InMemoryI18n implements I18nPort {
  final TranslationTable _table;

  @override
  AppLocale locale;

  final List<void Function(AppLocale locale)> _listeners = [];

  /// Creates the translator over [table]; [initialLocale] defaults to
  /// the first table entry (or `en`).
  InMemoryI18n({required TranslationTable table, AppLocale? initialLocale})
    : _table = table,
      locale =
          initialLocale ??
          (table.isEmpty
              ? const AppLocale('en')
              : AppLocale.parse(table.keys.first));

  @override
  Future<void> setLocale(AppLocale next) async {
    if (next == locale) return;
    locale = next;
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }

  @override
  ResolvedMessage translate(
    String key, {
    Map<String, Object?> params = const {},
    int? pluralCount,
  }) {
    // Resolution order: exact locale → language-only → any same-language
    // regional variant → first table entry as last resort.
    final candidates = _candidates();
    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final messages = _table[candidate.tag];
      if (messages == null) continue;

      String? message;
      if (pluralCount != null) {
        final category = pluralCategoryFor(pluralCount, candidate);
        message = messages['$key.${category.name}'] ?? messages['$key.other'];
      } else {
        message = messages[key];
      }
      if (message == null) continue;

      return ResolvedMessage(
        _interpolate(message, params, pluralCount),
        candidate,
        usedFallback: i > 0,
      );
    }
    // Missing everywhere: return the key itself so UI never blanks.
    return ResolvedMessage(
      _interpolate(key, params, pluralCount),
      locale,
      usedFallback: true,
    );
  }

  @override
  void Function() onLocaleChanged(void Function(AppLocale locale) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  List<AppLocale> _candidates() {
    final chain = <AppLocale>[locale, locale.languageOnly];
    for (final tag in _table.keys) {
      final candidate = AppLocale.parse(tag);
      if (candidate.language == locale.language && !chain.contains(candidate)) {
        chain.add(candidate);
      }
    }
    // Last resort: any available language (deterministic first entry).
    if (_table.isNotEmpty) {
      final first = AppLocale.parse(_table.keys.first);
      if (!chain.contains(first)) chain.add(first);
    }
    return chain;
  }

  static String _interpolate(
    String message,
    Map<String, Object?> params,
    int? pluralCount,
  ) {
    var result = message;
    if (pluralCount != null) {
      result = result.replaceAll('{count}', '$pluralCount');
    }
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }
}

/// App-facing localization facade.
///
/// ```dart
/// final i18n = I18nService(InMemoryI18n(table: myTable));
/// i18n.t('welcome.title', params: {'name': 'Ada'});
/// i18n.t('cart.items', pluralCount: 3);
/// await i18n.setLocale(const AppLocale('tr'));
/// ```
class I18nService {
  /// The translator port.
  final I18nPort port;

  I18nService(this.port);

  /// The active locale.
  AppLocale get locale => port.locale;

  /// Switches the locale and notifies listeners.
  Future<void> setLocale(AppLocale locale) => port.setLocale(locale);

  /// Translates [key]; returns the resolved text (the key itself when
  /// missing — never blanks).
  String t(
    String key, {
    Map<String, Object?> params = const {},
    int? pluralCount,
  }) => port.translate(key, params: params, pluralCount: pluralCount).text;

  /// Full-resolution variant (carries fallback info).
  ResolvedMessage translate(
    String key, {
    Map<String, Object?> params = const {},
    int? pluralCount,
  }) => port.translate(key, params: params, pluralCount: pluralCount);

  /// Subscribes to locale changes; returns the unsubscribe function.
  void Function() onLocaleChanged(void Function(AppLocale locale) listener) =>
      port.onLocaleChanged(listener);
}

/// Registers the i18n stack onto [getIt] with a table built by
/// [tableFor] (apps load their own translations; the loader decides the
/// source — assets, files, network).
void registerI18nDependencies(
  GetIt getIt, {
  required TranslationTable Function() tableFor,
  AppLocale? initialLocale,
}) {
  getIt
    ..registerLazySingleton<I18nPort>(
      () => InMemoryI18n(table: tableFor(), initialLocale: initialLocale),
    )
    ..registerLazySingleton<I18nService>(() => I18nService(getIt<I18nPort>()));
}
