// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timed_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimedStateAdapter extends TypeAdapter<TimedState> {
  @override
  final int typeId = 13;

  @override
  TimedState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimedState(
      matchId: fields[0] as String,
      teamId: fields[1] as String,
      finalScore: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TimedState obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.matchId)
      ..writeByte(1)
      ..write(obj.teamId)
      ..writeByte(2)
      ..write(obj.finalScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimedStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimedState _$TimedStateFromJson(Map<String, dynamic> json) => TimedState(
      matchId: json['matchId'] as String,
      teamId: json['teamId'] as String,
      finalScore: (json['finalScore'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$TimedStateToJson(TimedState instance) =>
    <String, dynamic>{
      'matchId': instance.matchId,
      'teamId': instance.teamId,
      'finalScore': instance.finalScore,
    };
