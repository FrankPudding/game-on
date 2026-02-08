// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_match.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SimpleMatchAdapter extends TypeAdapter<SimpleMatch> {
  @override
  final int typeId = 6;

  @override
  SimpleMatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SimpleMatch(
      id: fields[0] as String,
      leagueId: fields[1] as String,
      playedAt: fields[2] as DateTime,
      isComplete: fields[3] as bool,
      isDraw: fields[4] as bool,
      winnerId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SimpleMatch obj) {
    writer
      ..writeByte(6)
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
      ..write(obj.winnerId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleMatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimpleMatch _$SimpleMatchFromJson(Map<String, dynamic> json) => SimpleMatch(
      id: json['id'] as String,
      leagueId: json['leagueId'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      isComplete: json['isComplete'] as bool,
      isDraw: json['isDraw'] as bool? ?? false,
      winnerId: json['winnerId'] as String?,
    );

Map<String, dynamic> _$SimpleMatchToJson(SimpleMatch instance) =>
    <String, dynamic>{
      'id': instance.id,
      'leagueId': instance.leagueId,
      'playedAt': instance.playedAt.toIso8601String(),
      'isComplete': instance.isComplete,
      'isDraw': instance.isDraw,
      'winnerId': instance.winnerId,
    };
