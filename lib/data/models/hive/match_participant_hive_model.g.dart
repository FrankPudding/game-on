// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_participant_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MatchParticipantHiveModelAdapter
    extends TypeAdapter<MatchParticipantHiveModel> {
  @override
  final int typeId = 5;

  @override
  MatchParticipantHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MatchParticipantHiveModel(
      id: fields[0] as String,
      playerId: fields[1] as String,
      matchId: fields[2] as String,
      score: fields[3] as int?,
      isWinner: fields[4] as bool?,
      pointsEarned: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, MatchParticipantHiveModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.playerId)
      ..writeByte(2)
      ..write(obj.matchId)
      ..writeByte(3)
      ..write(obj.score)
      ..writeByte(4)
      ..write(obj.isWinner)
      ..writeByte(5)
      ..write(obj.pointsEarned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchParticipantHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
