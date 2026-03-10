import 'package:get_it/get_it.dart';

import 'product_local_datasource_di.dart';
import 'product_mock_datasource_di.dart';
import 'product_remote_datasource_di.dart';
import 'todo_local_datasource_di.dart';
import 'todo_mock_datasource_di.dart';
import 'todo_remote_datasource_di.dart';

void registerAllDataSources(GetIt getIt) {
  registerTodoLocalDataSource(getIt);
  registerProductMockDataSource(getIt);
  registerProductRemoteDataSource(getIt);
  registerTodoMockDataSource(getIt);
  registerTodoRemoteDataSource(getIt);
  registerProductLocalDataSource(getIt);
}
