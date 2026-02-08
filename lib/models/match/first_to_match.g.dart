// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'first_to_match.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FirstToMatchAdapter extends TypeAdapter<FirstToMatch> {
  @override
  final int typeId = 9;

  @override
  FirstToMatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FirstToMatch(
      id: fields[0] as String,
      leagueId: fields[1] as String,
      playedAt: fields[2] as DateTime,
      isComplete: fields[3] as bool,
      winnerTeamId: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FirstToMatch obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.leagueId)
      ..writeByte(2)
      ..write(obj.playedAt)
      ..writeByte(3)
      ..write(obj.isComplete)
      ..writeByte(4)
      ..write(obj.winnerTeamId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirstToMatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirstToMatch _$FirstToMatchFromJson(Map<String, dynamic> json) => FirstToMatch(
      id: json['id'] as String,
      leagueId: json['leagueId'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      isComplete: json['isComplete'] as bool? ?? false,
      winnerTeamId: json['winnerTeamId'] as String?,
    );

Map<String, dynamic> _$FirstToMatchToJson(FirstToMatch instance) =>
    <String, dynamic>{
      'id': instance.id,
      'leagueId': instance.leagueId,
      'playedAt': instance.playedAt.toIso8601String(),
      'isComplete': instance.isComplete,
      'winnerTeamId': instance.winnerTeamId,
    };
