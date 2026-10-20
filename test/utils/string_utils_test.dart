// Unit tests for StringUtils.pluralize.
//
// Guards the heuristic pluralization used by the mock data generator so
// entity names like `SearchQuery`, `Category`, `Entry`, `Address` produce
// conventional plurals (`searchQueries`, `categories`, `entries`,
// `addresses`) instead of a naive `+ 's'`.

import 'package:test/test.dart';
import 'package:zuraffa/src/utils/string_utils.dart';

void main() {
  group('StringUtils.pluralize', () {
    test('consonant + y -> ies', () {
      expect(StringUtils.pluralize('Category'), 'Categories');
      expect(StringUtils.pluralize('SearchQuery'), 'SearchQueries');
      expect(StringUtils.pluralize('Entry'), 'Entries');
      expect(StringUtils.pluralize('category'), 'categories');
      expect(StringUtils.pluralize('searchQuery'), 'searchQueries');
      expect(StringUtils.pluralize('entry'), 'entries');
    });

    test('s/x/z/ch/sh -> es', () {
      expect(StringUtils.pluralize('Address'), 'Addresses');
      expect(StringUtils.pluralize('Box'), 'Boxes');
      expect(StringUtils.pluralize('Quiz'), 'Quizes');
    });

    test('default -> s', () {
      expect(StringUtils.pluralize('Product'), 'Products');
      expect(StringUtils.pluralize('day'), 'days');
      expect(StringUtils.pluralize('key'), 'keys');
      expect(StringUtils.pluralize('User'), 'Users');
    });

    test('empty input', () {
      expect(StringUtils.pluralize(''), '');
    });
  });
}
