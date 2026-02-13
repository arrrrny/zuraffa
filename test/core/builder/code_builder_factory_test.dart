import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:code_builder/code_builder.dart';

void main() {
  test('CodeBuilderFactory builds usecase library', () {
    final factory = CodeBuilderFactory();
    final library = factory.usecase(
      const UseCaseSpecConfig(
        className: 'GetOrderUseCase',
        baseClass: 'UseCase<Order, OrderParams>',
        repositoryType: 'OrderRepository',
        repositoryField: '_repository',
        returnType: 'Future<Order>',
        paramsType: 'OrderParams',
        executeBody: 'return _repository.get(params);',
        imports: ['package:zuraffa/zuraffa.dart'],
      ),
    );

    final output = const SpecLibrary().emitLibrary(library);
    expect(output.contains('class GetOrderUseCase'), isTrue);
    expect(
      output.contains('Future<Order> execute(OrderParams params)'),
      isTrue,
    );
  });

  test('CodeBuilderFactory builds repository library', () {
    final factory = CodeBuilderFactory();
    final library = factory.repository(
      RepositorySpecConfig(
        className: 'OrderRepository',
        methods: [
          RepositoryMethodSpec(
            name: 'get',
            returnType: 'Future<Order>',
            parameters: [
              Parameter(
                (b) => b
                  ..name = 'id'
                  ..type = refer('String'),
              ),
            ],
          ),
        ],
      ),
    );

    final output = const SpecLibrary().emitLibrary(library);
    expect(output.contains('abstract class OrderRepository'), isTrue);
  });

  test('CodeBuilderFactory builds route library', () {
    final factory = CodeBuilderFactory();
    final library = factory.route(
      const RouteSpecConfig(
        className: 'OrderRoutes',
        routes: {'orderList': '/orders'},
      ),
    );

    final output = const SpecLibrary().emitLibrary(library);
    expect(
      output.contains("static const String orderList = '/orders';"),
      isTrue,
    );
  });
}
