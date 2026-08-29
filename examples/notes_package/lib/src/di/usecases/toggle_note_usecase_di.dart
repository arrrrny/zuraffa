// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/note/toggle_note_usecase.dart';

void registerToggleNoteUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleNoteUseCase>(
    () => ToggleNoteUseCase(getIt<NoteRepository>()),
  );
}

// END GENERATED
