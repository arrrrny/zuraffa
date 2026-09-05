import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/generator/tui_screen_generator.dart';

void main() {
  group('TuiScreenGenerator (FR-011, SC-005)', () {
    final generator = TuiScreenGenerator();

    final productSpec = TuiEntitySpec(
      name: 'Product',
      fields: const [
        TuiFieldSpec(name: 'id', type: 'String'),
        TuiFieldSpec(name: 'name', type: 'String'),
        TuiFieldSpec(name: 'price', type: 'double'),
      ],
      useCases: const [
        TuiUseCaseSpec(
          name: 'get',
          returnsType: 'Product',
          paramsType: 'String',
        ),
        TuiUseCaseSpec(
          name: 'getList',
          returnsType: 'List<Product>',
          isStream: true,
        ),
      ],
      repositoryName: 'ProductRepository',
    );

    test('A22 / U34: generateListScreen produces a list screen wired to the '
        'entity\'s getList use case', () {
      final source = generator.generateListScreen(productSpec);

      // The generated file declares the list screen class.
      expect(source, contains('class ProductListScreen'));
      // ... extends StatefulScreen (FR-002 / FR-003 contract).
      expect(source, contains('extends StatefulScreen'));
      // ... wired to the getList use case (FR-011, SC-005).
      expect(source, contains('GetListUseCase'));
      // ... resolves deps through ZuraffaDIContainer (FR-008).
      expect(source, contains('ZuraffaDIContainer'));
      // ... uses a Binding, no TUI-local duplicate store (SC-004).
      expect(source, contains('UseCaseResultBinding'));
      // ... renders a ListView with the entity's primary field.
      expect(source, contains('ListView.builder'));
    });

    test('A22 / U35: generateDetailScreen produces a detail screen wired to '
        'the entity\'s get use case', () {
      final source = generator.generateDetailScreen(productSpec);

      expect(source, contains('class ProductDetailScreen'));
      expect(source, contains('extends StatefulScreen'));
      expect(source, contains('GetUseCase'));
      expect(source, contains('ZuraffaDIContainer'));
      expect(source, contains('UseCaseResultBinding'));
      // Renders the fields in a Table.
      expect(source, contains('Table('));
      // All entity fields appear as headers.
      expect(source, contains("'id'"));
      expect(source, contains("'name'"));
      expect(source, contains("'price'"));
    });

    test('U36 / FR-012: generated screens use only package:zuraffa and '
        'package:nocterm imports — never package:flutter', () {
      final listSource = generator.generateListScreen(productSpec);
      final detailSource = generator.generateDetailScreen(productSpec);

      for (final source in [listSource, detailSource]) {
        // No package:flutter import anywhere.
        expect(
          source.contains('package:flutter'),
          isFalse,
          reason: 'FR-012: generated TUI screens must be pure-Dart',
        );
        // Imports package:nocterm.
        expect(source, contains("import 'package:nocterm/nocterm.dart'"));
        // Imports zuraffa TUI plugin types.
        expect(source, contains('package:zuraffa/src/plugins/tui/'));
      }
    });

    // Issue #997 (TRUTH-FLOOR / epic #1011): the previous suite certified
    // `package:zuraffa/domain/...` as the correct entity import. That import
    // only resolves when the generated file lives INSIDE the zuraffa
    // package — for any consumer project it is a broken import the test
    // was rubber-stamping as correct. A green test manufacturing false
    // confidence is worse than no test at all. The generator now emits a
    // RELATIVE entity import (`../../../domain/<entity>/<entity>.dart`)
    // that resolves regardless of the host package name; this test pins
    // the honest contract so the next drift off it fails loudly.
    test(
      'U36 / #997: entity imports are RELATIVE — not package:zuraffa/...',
      () {
        final listSource = generator.generateListScreen(productSpec);
        final detailSource = generator.generateDetailScreen(productSpec);

        for (final source in [listSource, detailSource]) {
          // The entity import must NOT use `package:zuraffa/domain/...`.
          expect(
            source.contains('package:zuraffa/domain/'),
            isFalse,
            reason:
                'issue #997: generated entity imports must not reference '
                'package:zuraffa/domain/... — that import only resolves '
                'inside the zuraffa package itself. Consumer projects do '
                'not have zuraffa as a runtime dep, so the import would '
                'silently break at compile time while the test suite '
                'certifies it as correct.',
          );
          // The entity import must be a relative path that resolves
          // regardless of host package name.
          expect(
            source,
            contains("'../../../domain/product/product.dart'"),
            reason:
                'issue #997: generated entity import must be the relative '
                'path ../../../domain/<entity>/<entity>.dart (screens '
                'live at lib/src/presentation/tui/, entities at '
                'lib/domain/<entity>/).',
          );
          // The entity's usecase import is also relative.
          expect(
            source,
            contains('../../../domain/product/usecases/'),
            reason:
                'issue #997: usecase imports must also be relative '
                '(../../../domain/<entity>/usecases/<usecase>.dart).',
          );
        }
      },
    );

    test('A22 / SC-005: generated screens require zero manual wiring — they '
        'auto-resolve deps via ZuraffaDIContainer', () {
      final listSource = generator.generateListScreen(productSpec);
      final detailSource = generator.generateDetailScreen(productSpec);

      // No TODOs, no manual wiring comments, no "fill this in" markers.
      expect(listSource.toLowerCase(), isNot(contains('todo')));
      expect(listSource.toLowerCase(), isNot(contains('fixme')));
      expect(detailSource.toLowerCase(), isNot(contains('todo')));
      expect(detailSource.toLowerCase(), isNot(contains('fixme')));

      // Both screens have an initState that resolves the use case.
      expect(listSource, contains('initState'));
      expect(listSource, contains('di.get<'));
      expect(detailSource, contains('initState'));
      expect(detailSource, contains('di.get<'));

      // Both screens dispose their binding (FR-009 lifecycle).
      expect(listSource, contains('dispose'));
      expect(listSource, contains('_binding.dispose'));
      expect(detailSource, contains('dispose'));
      expect(detailSource, contains('_binding.dispose'));
    });

    test('throws ArgumentError when entity has no list-returning use case', () {
      final badSpec = TuiEntitySpec(
        name: 'BadEntity',
        fields: const [TuiFieldSpec(name: 'id', type: 'String')],
        useCases: const [TuiUseCaseSpec(name: 'get', returnsType: 'BadEntity')],
      );

      expect(() => generator.generateListScreen(badSpec), throwsArgumentError);
    });

    test('throws ArgumentError when entity has no get use case', () {
      final badSpec = TuiEntitySpec(
        name: 'BadEntity',
        fields: const [TuiFieldSpec(name: 'id', type: 'String')],
        useCases: const [
          TuiUseCaseSpec(name: 'getList', returnsType: 'List<BadEntity>'),
        ],
      );

      expect(
        () => generator.generateDetailScreen(badSpec),
        throwsArgumentError,
      );
    });
  });
}
