// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frames_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FramesStateAdapter extends TypeAdapter<FramesState> {
  @override
  final int typeId = 16;

  @override
  FramesState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FramesState(
      matchId: fields[0] as String,
      teamId: fields[1] as String,
      framesWon: fields[2] as int,
      individualFrameScores: (fields[3] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, FramesState obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.matchId)
      ..writeByte(1)
      ..write(obj.teamId)
      ..writeByte(2)
      ..write(obj.framesWon)
      ..writeByte(3)
      ..write(obj.individualFrameScores);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FramesStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FramesState _$FramesStateFromJson(Map<String, dynamic> json) => FramesState(
      matchId: json['matchId'] as String,
      teamId: json['teamId'] as String,
      framesWon: (json['framesWon'] as num?)?.toInt() ?? 0,
      individualFrameScores: (json['individualFrameScores'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$FramesStateToJson(FramesState instance) =>
    <String, dynamic>{
      'matchId': instance.matchId,
      'teamId': instance.teamId,
      'framesWon': instance.framesWon,
      'individualFrameScores': instance.individualFrameScores,
    };
