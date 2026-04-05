import 'package:zuraffa/zuraffa.dart';

import 'concert_remote_datasource_di.dart';
import 'product_local_datasource_di.dart';
import 'product_mock_datasource_di.dart';
import 'product_remote_datasource_di.dart';
import 'todo_local_datasource_di.dart';
import 'todo_mock_datasource_di.dart';
import 'todo_remote_datasource_di.dart';

void registerAllDataSources(GetIt getIt) {
  registerConcertRemoteDataSource(getIt);
  registerProductLocalDataSource(getIt);
  registerProductMockDataSource(getIt);
  registerProductRemoteDataSource(getIt);
  registerTodoLocalDataSource(getIt);
  registerTodoMockDataSource(getIt);
  registerTodoRemoteDataSource(getIt);
}
