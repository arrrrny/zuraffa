// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/note/note_mock_datasource.dart';
import '../../data/repositories/data_note_repository.dart';
import '../../domain/repositories/note_repository.dart';

void registerNoteRepository(GetIt getIt) {
  getIt.registerLazySingleton<NoteRepository>(
    () => DataNoteRepository(getIt<NoteMockDataSource>()),
  );
}

// END GENERATED
