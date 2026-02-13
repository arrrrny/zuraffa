import 'package:get_it/get_it.dart';

import 'datasources/index.dart';
import 'repositories/index.dart';

export 'datasources/index.dart';
export 'repositories/index.dart';

void setupDependencies(GetIt getIt) {
  registerAllDataSources(getIt);
  registerAllRepositories(getIt);
}
