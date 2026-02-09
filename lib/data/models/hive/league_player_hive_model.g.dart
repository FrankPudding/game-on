// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'league_player_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LeaguePlayerHiveModelAdapter extends TypeAdapter<LeaguePlayerHiveModel> {
  @override
  final int typeId = 1;

  @override
  LeaguePlayerHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LeaguePlayerHiveModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      leagueId: fields[2] as String,
      name: fields[3] as String,
      avatarColorHex: fields[4] as String,
      icon: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LeaguePlayerHiveModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.leagueId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.avatarColorHex)
      ..writeByte(5)
      ..write(obj.icon);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaguePlayerHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
