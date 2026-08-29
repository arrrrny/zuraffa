// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Note _$NoteFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Note', json, ($checkedConvert) {
      final val = Note(
        id: $checkedConvert('id', (v) => v as String),
        body: $checkedConvert('body', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$NoteToJson(Note instance) => <String, dynamic>{
  'id': instance.id,
  'body': instance.body,
};
