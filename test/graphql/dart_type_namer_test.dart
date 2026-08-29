import 'package:test/test.dart';
import 'package:zuraffa/src/graphql/mapping/dart_type_namer.dart';

void main() {
  group('DartTypeNamer.fieldName', () {
    test('camelCases snake_case identifiers', () {
      expect(DartTypeNamer.fieldName('snake_case'), 'snakeCase');
      expect(DartTypeNamer.fieldName('order_line_id'), 'orderLineId');
    });

    test('preserves camelCase identifiers', () {
      expect(DartTypeNamer.fieldName('camelCase'), 'camelCase');
      expect(DartTypeNamer.fieldName('createdAt'), 'createdAt');
    });

    test('camelCases kebab-case identifiers', () {
      expect(DartTypeNamer.fieldName('kebab-case'), 'kebabCase');
      expect(DartTypeNamer.fieldName('full-name'), 'fullName');
    });

    test('lowercases the first letter of PascalCase identifiers', () {
      expect(DartTypeNamer.fieldName('PascalCase'), 'pascalCase');
      expect(DartTypeNamer.fieldName('Product'), 'product');
    });

    test('reserved words are escaped with the documented prefix', () {
      expect(DartTypeNamer.fieldName('class'), '_\$class');
      expect(DartTypeNamer.fieldName('int'), '_\$int');
      expect(DartTypeNamer.fieldName('new'), '_\$new');
      expect(DartTypeNamer.fieldName('default'), '_\$default');
      expect(DartTypeNamer.fieldName('extension'), '_\$extension');
      expect(DartTypeNamer.fieldName('in'), '_\$in');
      expect(DartTypeNamer.fieldName('is'), '_\$is');
      expect(DartTypeNamer.fieldName('null'), '_\$null');
      expect(DartTypeNamer.fieldName('this'), '_\$this');
    });

    test('non-reserved words pass through the convention untouched', () {
      expect(DartTypeNamer.fieldName('name'), 'name');
      expect(DartTypeNamer.fieldName('id'), 'id');
      expect(DartTypeNamer.fieldName('SKU'), 'sku');
    });
  });

  group('DartTypeNamer.className', () {
    test('PascalCases lowercase identifiers', () {
      expect(DartTypeNamer.className('product'), 'Product');
      expect(DartTypeNamer.className('product_variant'), 'ProductVariant');
    });

    test('preserves PascalCase identifiers', () {
      expect(DartTypeNamer.className('Product'), 'Product');
      expect(DartTypeNamer.className('OrderLine'), 'OrderLine');
    });

    test('PascalCases SCREAMING_SNAKE identifiers', () {
      expect(DartTypeNamer.className('ORDER_LINE'), 'OrderLine');
    });

    test('reserved words are escaped with the documented suffix', () {
      expect(DartTypeNamer.className('int'), 'Int\$');
      expect(DartTypeNamer.className('String'), 'String\$');
      expect(DartTypeNamer.className('bool'), 'Bool\$');
      expect(DartTypeNamer.className('dynamic'), 'Dynamic\$');
    });

    test('non-reserved names pass through the convention untouched', () {
      expect(DartTypeNamer.className('Product'), 'Product');
      expect(DartTypeNamer.className('Collection'), 'Collection');
    });
  });
}
