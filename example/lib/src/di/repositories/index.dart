import 'package:zuraffa/zuraffa.dart';

import 'concert_repository_di.dart';
import 'product_repository_di.dart';
import 'todo_repository_di.dart';

void registerAllRepositories(GetIt getIt) {
  registerConcertRepository(getIt);
  registerProductRepository(getIt);
  registerTodoRepository(getIt);
}
