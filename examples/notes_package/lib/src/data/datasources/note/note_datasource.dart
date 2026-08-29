// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/note/note.dart';

abstract class NoteDataSource with Loggable, FailureHandler {
  Future<Note> get(QueryParams<Note> params);
  Future<Note> update(UpdateParams<String, NotePatch> params);
  Future<Note> toggle(ToggleParams<String, Field<Note, dynamic>> params);
}

// END GENERATED
