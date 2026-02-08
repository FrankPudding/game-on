// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frames_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FramesConfigAdapter extends TypeAdapter<FramesConfig> {
  @override
  final int typeId = 14;

  @override
  FramesConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FramesConfig(
      leagueId: fields[0] as String,
      framesToWin: fields[1] as int,
      frameType: fields[2] as String,
      frameTargetScore: fields[3] as int?,
      placementPoints: (fields[4] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, FramesConfig obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.leagueId)
      ..writeByte(1)
      ..write(obj.framesToWin)
      ..writeByte(2)
      ..write(obj.frameType)
      ..writeByte(3)
      ..write(obj.frameTargetScore)
      ..writeByte(4)
      ..write(obj.placementPoints);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FramesConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FramesConfig _$FramesConfigFromJson(Map<String, dynamic> json) => FramesConfig(
      leagueId: json['leagueId'] as String,
      framesToWin: (json['framesToWin'] as num).toInt(),
      frameType: json['frameType'] as String,
      frameTargetScore: (json['frameTargetScore'] as num?)?.toInt(),
      placementPoints: (json['placementPoints'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$FramesConfigToJson(FramesConfig instance) =>
    <String, dynamic>{
      'leagueId': instance.leagueId,
      'framesToWin': instance.framesToWin,
      'frameType': instance.frameType,
      'frameTargetScore': instance.frameTargetScore,
      'placementPoints': instance.placementPoints,
    };
