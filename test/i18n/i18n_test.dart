import 'package:get_it/get_it.dart';
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// i18n built-in: locale parsing, fallback chains, parameter
/// interpolation, pluralization, live switching, DI.
void main() {
  TranslationTable table() => {
    'en': {
      'app.title': 'Zuraffa',
      'welcome.title': 'Hello {name}!',
      'cart.items.one': '{count} item',
      'cart.items.other': '{count} items',
      'only.en': 'English only',
    },
    'en_US': {'welcome.title': 'Howdy {name}!'},
    'tr': {
      'app.title': 'Zuraffa',
      'welcome.title': 'Merhaba {name}!',
      'cart.items.one': '{count} ürün',
      'cart.items.other': '{count} ürün',
    },
  };

  group('AppLocale', () {
    test('parses language-only and language_region tags', () {
      expect(AppLocale.parse('en'), const AppLocale('en'));
      expect(AppLocale.parse('en_US').tag, 'en_US');
      expect(AppLocale.parse('en-US').tag, 'en_US');
      expect(AppLocale.parse('tr_tr').tag, 'tr_TR');
      expect(const AppLocale('en').languageOnly, const AppLocale('en'));
      expect(AppLocale.parse('en_US') == AppLocale.parse('en_US'), isTrue);
    });
  });

  group('InMemoryI18n — translation', () {
    test('translates with parameter interpolation', () {
      final i18n = InMemoryI18n(table: table());

      expect(
        i18n.translate('welcome.title', params: {'name': 'Ada'}).text,
        'Hello Ada!',
      );
    });

    test('pluralizes via the CLDR category subkeys', () {
      final i18n = InMemoryI18n(table: table());

      expect(i18n.translate('cart.items', pluralCount: 1).text, '1 item');
      expect(i18n.translate('cart.items', pluralCount: 5).text, '5 items');
    });

    test('regional tables win over language-only; fallbacks flagged', () {
      final i18n = InMemoryI18n(
        table: table(),
        initialLocale: const AppLocale('en', 'US'),
      );

      // en_US overrides welcome.title.
      final regional = i18n.translate('welcome.title', params: {'name': 'A'});
      expect(regional.text, 'Howdy A!');
      expect(regional.usedFallback, isFalse);

      // app.title lives only in en — a language-only fallback, flagged.
      final fallback = i18n.translate('app.title');
      expect(fallback.text, 'Zuraffa');
      expect(fallback.usedFallback, isTrue);
      expect(fallback.resolvedLocale, const AppLocale('en'));
    });

    test('missing keys resolve to the key itself (UI never blanks)', () {
      final i18n = InMemoryI18n(table: table());

      final resolved = i18n.translate('nope.missing', params: {'x': 1});
      expect(resolved.text, 'nope.missing');
      expect(resolved.usedFallback, isTrue);
    });

    test('keys missing in the active language fall back across languages', () {
      final i18n = InMemoryI18n(
        table: table(),
        initialLocale: const AppLocale('tr'),
      );

      // only.en exists only in English — the last-resort chain finds it.
      final resolved = i18n.translate('only.en');
      expect(resolved.text, 'English only');
      expect(resolved.usedFallback, isTrue);
    });
  });

  group('locale switching', () {
    test('setLocale switches translations and notifies listeners', () async {
      final i18n = InMemoryI18n(table: table());
      final seen = <AppLocale>[];
      final unsubscribe = i18n.onLocaleChanged(seen.add);

      expect(
        i18n.translate('welcome.title', params: {'name': 'A'}).text,
        'Hello A!',
      );

      await i18n.setLocale(const AppLocale('tr'));

      expect(i18n.locale, const AppLocale('tr'));
      expect(seen, [const AppLocale('tr')]);
      expect(
        i18n.translate('welcome.title', params: {'name': 'A'}).text,
        'Merhaba A!',
      );

      unsubscribe();
      await i18n.setLocale(const AppLocale('en'));
      expect(seen, hasLength(1), reason: 'unsubscribed listeners stay quiet');
    });

    test('setting the same locale is a no-op', () async {
      final i18n = InMemoryI18n(table: table());
      var notified = 0;
      i18n.onLocaleChanged((_) => notified++);

      await i18n.setLocale(const AppLocale('en'));

      expect(notified, 0);
    });
  });

  group('pluralCategoryFor', () {
    test('language rule shapes', () {
      // English/German: one vs other.
      expect(pluralCategoryFor(1, const AppLocale('en')), PluralCategory.one);
      expect(pluralCategoryFor(2, const AppLocale('en')), PluralCategory.other);
      // Turkish: same one/other split.
      expect(pluralCategoryFor(1, const AppLocale('tr')), PluralCategory.one);
      expect(pluralCategoryFor(0, const AppLocale('tr')), PluralCategory.other);
      // French: 0 and 1 are singular-ish.
      expect(pluralCategoryFor(0, const AppLocale('fr')), PluralCategory.one);
      expect(pluralCategoryFor(2, const AppLocale('fr')), PluralCategory.many);
      // Arabic: the full six-way split.
      expect(pluralCategoryFor(0, const AppLocale('ar')), PluralCategory.zero);
      expect(pluralCategoryFor(1, const AppLocale('ar')), PluralCategory.one);
      expect(pluralCategoryFor(2, const AppLocale('ar')), PluralCategory.two);
      expect(pluralCategoryFor(5, const AppLocale('ar')), PluralCategory.few);
      expect(pluralCategoryFor(15, const AppLocale('ar')), PluralCategory.many);
      // CJK: always other.
      expect(pluralCategoryFor(1, const AppLocale('zh')), PluralCategory.other);
    });
  });

  group('I18nService + DI', () {
    test('facade t() returns the resolved text', () {
      final service = I18nService(InMemoryI18n(table: table()));

      expect(service.t('welcome.title', params: {'name': 'Ada'}), 'Hello Ada!');
      expect(service.t('cart.items', pluralCount: 3), '3 items');
    });

    test('registerI18nDependencies wires the stack', () {
      final getIt = GetIt.asNewInstance();
      registerI18nDependencies(getIt, tableFor: table);

      final service = getIt<I18nService>();
      expect(service.locale, const AppLocale('en'));
      expect(service.t('app.title'), 'Zuraffa');
    });
  });
}
