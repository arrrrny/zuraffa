// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/note/note.dart';
import 'note_datasource.dart';

class NoteRemoteDataSource
    with Loggable, FailureHandler
    implements NoteDataSource {
  @override
  Future<Note> get(QueryParams<Note> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Note> update(UpdateParams<String, NotePatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Note> toggle(ToggleParams<String, Field<Note, dynamic>> params) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
