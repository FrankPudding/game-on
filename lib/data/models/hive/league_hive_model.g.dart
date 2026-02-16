// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'league_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LeagueHiveModelAdapter extends TypeAdapter<LeagueHiveModel> {
  @override
  final typeId = 3;

  @override
  LeagueHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LeagueHiveModel(
      id: fields[0] as String,
      name: fields[1] as String,
      createdAt: fields[2] as DateTime,
      isArchived: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LeagueHiveModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.isArchived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeagueHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
