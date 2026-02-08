// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tennis_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TennisStateAdapter extends TypeAdapter<TennisState> {
  @override
  final int typeId = 19;

  @override
  TennisState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TennisState(
      matchId: fields[0] as String,
      teamId: fields[1] as String,
      setsWon: fields[2] as int,
      currentSetGames: fields[3] as int,
      currentGamePoints: fields[4] as int,
      tiebreakPoints: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TennisState obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.matchId)
      ..writeByte(1)
      ..write(obj.teamId)
      ..writeByte(2)
      ..write(obj.setsWon)
      ..writeByte(3)
      ..write(obj.currentSetGames)
      ..writeByte(4)
      ..write(obj.currentGamePoints)
      ..writeByte(5)
      ..write(obj.tiebreakPoints);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TennisStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TennisState _$TennisStateFromJson(Map<String, dynamic> json) => TennisState(
      matchId: json['matchId'] as String,
      teamId: json['teamId'] as String,
      setsWon: (json['setsWon'] as num?)?.toInt() ?? 0,
      currentSetGames: (json['currentSetGames'] as num?)?.toInt() ?? 0,
      currentGamePoints: (json['currentGamePoints'] as num?)?.toInt() ?? 0,
      tiebreakPoints: (json['tiebreakPoints'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TennisStateToJson(TennisState instance) =>
    <String, dynamic>{
      'matchId': instance.matchId,
      'teamId': instance.teamId,
      'setsWon': instance.setsWon,
      'currentSetGames': instance.currentSetGames,
      'currentGamePoints': instance.currentGamePoints,
      'tiebreakPoints': instance.tiebreakPoints,
    };
