// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_match_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SimpleMatchHiveModelAdapter extends TypeAdapter<SimpleMatchHiveModel> {
  @override
  final typeId = 6;

  @override
  SimpleMatchHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SimpleMatchHiveModel(
      id: fields[0] as String,
      leagueId: fields[1] as String,
      playedAt: fields[2] as DateTime,
      isComplete: fields[3] as bool,
      isDraw: fields[4] as bool,
      sides: (fields[6] as List?)?.cast<SideHiveModel>(),
      winnerSideId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SimpleMatchHiveModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.leagueId)
      ..writeByte(2)
      ..write(obj.playedAt)
      ..writeByte(3)
      ..write(obj.isComplete)
      ..writeByte(4)
      ..write(obj.isDraw)
      ..writeByte(5)
      ..write(obj.winnerSideId)
      ..writeByte(6)
      ..write(obj.sides);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleMatchHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
