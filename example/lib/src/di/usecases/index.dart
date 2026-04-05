import 'package:zuraffa/zuraffa.dart';

import 'get_concert_list_usecase_di.dart';
import 'get_concert_usecase_di.dart';
import 'update_concert_usecase_di.dart';
import 'watch_concert_usecase_di.dart';

void registerAllUseCases(GetIt getIt) {
  registerGetConcertListUseCase(getIt);
  registerGetConcertUseCase(getIt);
  registerUpdateConcertUseCase(getIt);
  registerWatchConcertUseCase(getIt);
}
