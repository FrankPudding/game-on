// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_participant.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MatchParticipantAdapter extends TypeAdapter<MatchParticipant> {
  @override
  final int typeId = 5;

  @override
  MatchParticipant read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MatchParticipant(
      id: fields[0] as String,
      playerId: fields[1] as String,
      matchId: fields[2] as String,
      score: fields[3] as int?,
      isWinner: fields[4] as bool?,
      pointsEarned: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, MatchParticipant obj) {
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
      other is MatchParticipantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchParticipant _$MatchParticipantFromJson(Map<String, dynamic> json) =>
    MatchParticipant(
      id: json['id'] as String,
      playerId: json['playerId'] as String,
      matchId: json['matchId'] as String,
      score: (json['score'] as num?)?.toInt(),
      isWinner: json['isWinner'] as bool?,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MatchParticipantToJson(MatchParticipant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'playerId': instance.playerId,
      'matchId': instance.matchId,
      'score': instance.score,
      'isWinner': instance.isWinner,
      'pointsEarned': instance.pointsEarned,
    };
