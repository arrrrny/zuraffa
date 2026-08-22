import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('NamingUtils.documentVarName', () {
    test('converts snake_case to camelCase', () {
      expect(NamingUtils.documentVarName('get_todo'), 'getTodo');
      expect(NamingUtils.documentVarName('user_by_id'), 'userById');
      expect(NamingUtils.documentVarName('all_products'), 'allProducts');
    });

    test('passes through already-camelCase input unchanged', () {
      expect(NamingUtils.documentVarName('getTodo'), 'getTodo');
      expect(NamingUtils.documentVarName('productList'), 'productList');
    });

    test('converts PascalCase to camelCase', () {
      expect(NamingUtils.documentVarName('GetTodo'), 'getTodo');
      expect(NamingUtils.documentVarName('ProductList'), 'productList');
    });

    test('converts kebab-case to camelCase', () {
      expect(NamingUtils.documentVarName('get-todo'), 'getTodo');
      expect(NamingUtils.documentVarName('user-by-id'), 'userById');
    });

    test('strips .graphql extension', () {
      expect(NamingUtils.documentVarName('get_todo.graphql'), 'getTodo');
      expect(NamingUtils.documentVarName('getTodo.graphql'), 'getTodo');
    });

    test('handles spaces as separators', () {
      expect(NamingUtils.documentVarName('get todo'), 'getTodo');
      expect(NamingUtils.documentVarName('all products'), 'allProducts');
    });

    test('handles single-word input', () {
      expect(NamingUtils.documentVarName('todo'), 'todo');
      expect(NamingUtils.documentVarName('Todo'), 'todo');
    });

    test('is deterministic for collision detection', () {
      final a = NamingUtils.documentVarName('get_todo');
      final b = NamingUtils.documentVarName('get_todo');
      expect(a, b);
    });

    test('different inputs produce different outputs (collision-safe)', () {
      final names = {'get_todo', 'get_product', 'user_by_id', 'create_order'};
      final results = names.map(NamingUtils.documentVarName).toSet();
      expect(results.length, names.length);
    });

    test('handles consecutive separators gracefully', () {
      expect(NamingUtils.documentVarName('get__todo'), 'getTodo');
      expect(NamingUtils.documentVarName('get--todo'), 'getTodo');
    });

    test('handles empty string', () {
      expect(NamingUtils.documentVarName(''), '');
    });

    test('handles separators-only input', () {
      expect(NamingUtils.documentVarName('___'), '');
      expect(NamingUtils.documentVarName('---'), '');
    });
  });
}
