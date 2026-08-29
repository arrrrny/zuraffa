// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/note/get_note_usecase.dart';

void registerGetNoteUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetNoteUseCase>(
    () => GetNoteUseCase(getIt<NoteRepository>()),
  );
}

// END GENERATED
