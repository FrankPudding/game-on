// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'side_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SideHiveModelAdapter extends TypeAdapter<SideHiveModel> {
  @override
  final typeId = 8;

  @override
  SideHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SideHiveModel(
      id: fields[0] as String,
      playerIds: (fields[2] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, SideHiveModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.playerIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SideHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
