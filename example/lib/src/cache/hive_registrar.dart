// Auto-generated Hive registrar
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../domain/entities/todo/todo.dart';
import '../domain/entities/product/product.dart';

part 'hive_registrar.g.dart';

@GenerateAdapters([AdapterSpec<Todo>(), AdapterSpec<Product>()])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(TodoAdapter());
    registerAdapter(ProductAdapter());
  }
}

extension IsolatedHiveRegistrar on IsolatedHiveInterface {
  void registerAdapters() {
    registerAdapter(TodoAdapter());
    registerAdapter(ProductAdapter());
  }
}
