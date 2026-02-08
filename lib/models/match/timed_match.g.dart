// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timed_match.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimedMatchAdapter extends TypeAdapter<TimedMatch> {
  @override
  final int typeId = 12;

  @override
  TimedMatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimedMatch(
      id: fields[0] as String,
      leagueId: fields[1] as String,
      playedAt: fields[2] as DateTime,
      isComplete: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TimedMatch obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.leagueId)
      ..writeByte(2)
      ..write(obj.playedAt)
      ..writeByte(3)
      ..write(obj.isComplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimedMatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimedMatch _$TimedMatchFromJson(Map<String, dynamic> json) => TimedMatch(
      id: json['id'] as String,
      leagueId: json['leagueId'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      isComplete: json['isComplete'] as bool? ?? false,
    );

Map<String, dynamic> _$TimedMatchToJson(TimedMatch instance) =>
    <String, dynamic>{
      'id': instance.id,
      'leagueId': instance.leagueId,
      'playedAt': instance.playedAt.toIso8601String(),
      'isComplete': instance.isComplete,
    };
