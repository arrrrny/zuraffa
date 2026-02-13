import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:code_builder/code_builder.dart' as cb;

void main() {
  group('CodeBuilderFactory', () {
    test('builds usecase library', () {
      final factory = CodeBuilderFactory();
      final usecaseLib = factory.usecase(
        UseCaseSpecConfig(
          className: 'GetProductUseCase',
          baseClass: 'UseCase',
          repositoryType: 'ProductRepository',
          repositoryField: '_repository',
          returnType: 'Product',
          paramsType: 'String',
          executeBody:
              'cancelToken?.throwIfCancelled(); return _repository.get(params);',
        ),
      );

      expect(usecaseLib, isNotNull);
    });

    test('builds repository library', () {
      final factory = CodeBuilderFactory();
      final repoLib = factory.repository(
        RepositorySpecConfig(
          className: 'ProductRepository',
          methods: [
            RepositoryMethodSpec(name: 'get', returnType: 'Product'),
            RepositoryMethodSpec(name: 'getList', returnType: 'List<Product>'),
          ],
        ),
      );

      expect(repoLib, isNotNull);
    });

    test('builds route library', () {
      final factory = CodeBuilderFactory();
      final routeLib = factory.route(
        RouteSpecConfig(
          className: 'ProductRoutes',
          routes: {
            'list': '/product',
            'detail': '/product/:id',
            'create': '/product/create',
          },
        ),
      );

      expect(routeLib, isNotNull);
    });

    test('builds vpc controller', () {
      final factory = CodeBuilderFactory();
      final controllerLib = factory.vpcController(
        VpcSpecConfig(
          className: 'ProductController',
          baseClass: 'Controller',
          fields: [
            cb.Field(
              (b) => b
                ..name = '_presenter'
                ..type = cb.refer('ProductPresenter'),
            ),
          ],
          methods: [
            cb.Method(
              (b) => b
                ..name = 'getProduct'
                ..returns = cb.refer('void'),
            ),
          ],
        ),
      );

      expect(controllerLib, isNotNull);
    });

    test('builds vpc presenter', () {
      final factory = CodeBuilderFactory();
      final presenterLib = factory.vpcPresenter(
        VpcSpecConfig(
          className: 'ProductPresenter',
          methods: [
            cb.Method(
              (b) => b
                ..name = 'getProduct'
                ..returns = cb.refer('Future<Product>'),
            ),
          ],
        ),
      );

      expect(presenterLib, isNotNull);
    });

    test('builds vpc state', () {
      final factory = CodeBuilderFactory();
      final stateLib = factory.vpcState(
        VpcSpecConfig(
          className: 'ProductState',
          fields: [
            cb.Field(
              (b) => b
                ..name = 'isLoading'
                ..type = cb.refer('bool')
                ..modifier = cb.FieldModifier.final$,
            ),
            cb.Field(
              (b) => b
                ..name = 'items'
                ..type = cb.refer('List<Product>')
                ..modifier = cb.FieldModifier.final$,
            ),
          ],
        ),
      );

      expect(stateLib, isNotNull);
    });

    test('emits formatted dart code', () {
      final factory = CodeBuilderFactory();
      final repoLib = factory.repository(
        RepositorySpecConfig(
          className: 'ProductRepository',
          methods: [RepositoryMethodSpec(name: 'get', returnType: 'Product')],
        ),
      );

      final code = factory.specLibrary.emitLibrary(repoLib, format: false);

      expect(code, contains('abstract class ProductRepository'));
      expect(code, contains('Product get()'));
    });
  });
}
