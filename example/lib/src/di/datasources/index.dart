// Auto-generated - DO NOT EDIT
import 'todo_local_data_source_di.dart';
import 'todo_mock_data_source_di.dart';
import 'todo_remote_data_source_di.dart';

import 'package:get_it/get_it.dart';

void registerAllDataSources(GetIt getIt) {
  registerTodoLocalDataSource(getIt);
  registerTodoMockDataSource(getIt);
  registerTodoRemoteDataSource(getIt);
}
