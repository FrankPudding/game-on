// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'league_player.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LeaguePlayerAdapter extends TypeAdapter<LeaguePlayer> {
  @override
  final int typeId = 1;

  @override
  LeaguePlayer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LeaguePlayer(
      id: fields[0] as String,
      playerId: fields[1] as String,
      leagueId: fields[2] as String,
      name: fields[3] as String,
      avatarColorHex: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LeaguePlayer obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.playerId)
      ..writeByte(2)
      ..write(obj.leagueId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.avatarColorHex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaguePlayerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LeaguePlayer _$LeaguePlayerFromJson(Map<String, dynamic> json) => LeaguePlayer(
      id: json['id'] as String,
      playerId: json['playerId'] as String,
      leagueId: json['leagueId'] as String,
      name: json['name'] as String,
      avatarColorHex: json['avatarColorHex'] as String,
    );

Map<String, dynamic> _$LeaguePlayerToJson(LeaguePlayer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'playerId': instance.playerId,
      'leagueId': instance.leagueId,
      'name': instance.name,
      'avatarColorHex': instance.avatarColorHex,
    };
