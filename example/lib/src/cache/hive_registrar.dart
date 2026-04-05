import 'package:zuraffa/zuraffa.dart';

import '../domain/entities/concert/concert.dart';
import '../domain/entities/product/product.dart';
import '../domain/entities/todo/todo.dart';

part 'hive_registrar.g.dart';

@GenerateAdapters([
  AdapterSpec<Concert>(),
  AdapterSpec<Todo>(),
  AdapterSpec<Product>(),
])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(ConcertAdapter());
    registerAdapter(TodoAdapter());
    registerAdapter(ProductAdapter());
  }
}

extension IsolatedHiveRegistrar on IsolatedHiveInterface {
  void registerAdapters() {
    registerAdapter(ConcertAdapter());
    registerAdapter(TodoAdapter());
    registerAdapter(ProductAdapter());
  }
}
