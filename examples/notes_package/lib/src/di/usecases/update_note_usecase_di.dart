// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/note/update_note_usecase.dart';

void registerUpdateNoteUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateNoteUseCase>(
    () => UpdateNoteUseCase(getIt<NoteRepository>()),
  );
}

// END GENERATED
