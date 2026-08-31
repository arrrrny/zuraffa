// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_registrar.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class TodoAdapter extends TypeAdapter<Todo> {
  @override
  final typeId = 0;

  @override
  Todo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Todo(
      id: (fields[0] as num).toInt(),
      title: fields[1] as String,
      description: fields[2] as String,
      isCompleted: fields[3] as bool,
      priority: fields[4] as TodoPriority,
      tags: (fields[5] as List).cast<String>(),
      createdAt: fields[6] as DateTime,
      completedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Todo obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
