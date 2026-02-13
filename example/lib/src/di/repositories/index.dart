import 'package:get_it/get_it.dart';

import 'product_repository_di.dart';
import 'todo_repository_di.dart';

void registerAllRepositories(GetIt getIt) {
  registerTodoRepository(getIt);
  registerProductRepository(getIt);
}
