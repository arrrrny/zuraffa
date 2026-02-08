// Auto-generated - DO NOT EDIT
import 'todo_local_data_source_di.dart';
import 'product_mock_data_source_di.dart';
import 'product_remote_data_source_di.dart';
import 'todo_mock_data_source_di.dart';
import 'todo_remote_data_source_di.dart';
import 'product_local_data_source_di.dart';

import 'package:get_it/get_it.dart';

void registerAllDataSources(GetIt getIt) {
  registerTodoLocalDataSource(getIt);
  registerProductMockDataSource(getIt);
  registerProductRemoteDataSource(getIt);
  registerTodoMockDataSource(getIt);
  registerTodoRemoteDataSource(getIt);
  registerProductLocalDataSource(getIt);
}
