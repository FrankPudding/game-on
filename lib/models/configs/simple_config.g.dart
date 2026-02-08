// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SimpleConfigAdapter extends TypeAdapter<SimpleConfig> {
  @override
  final int typeId = 4;

  @override
  SimpleConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SimpleConfig(
      leagueId: fields[0] as String,
      pointsForWin: fields[1] as int,
      pointsForDraw: fields[2] as int,
      pointsForLoss: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SimpleConfig obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.leagueId)
      ..writeByte(1)
      ..write(obj.pointsForWin)
      ..writeByte(2)
      ..write(obj.pointsForDraw)
      ..writeByte(3)
      ..write(obj.pointsForLoss);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimpleConfig _$SimpleConfigFromJson(Map<String, dynamic> json) => SimpleConfig(
      leagueId: json['leagueId'] as String,
      pointsForWin: (json['pointsForWin'] as num).toInt(),
      pointsForDraw: (json['pointsForDraw'] as num).toInt(),
      pointsForLoss: (json['pointsForLoss'] as num).toInt(),
    );

Map<String, dynamic> _$SimpleConfigToJson(SimpleConfig instance) =>
    <String, dynamic>{
      'leagueId': instance.leagueId,
      'pointsForWin': instance.pointsForWin,
      'pointsForDraw': instance.pointsForDraw,
      'pointsForLoss': instance.pointsForLoss,
    };
