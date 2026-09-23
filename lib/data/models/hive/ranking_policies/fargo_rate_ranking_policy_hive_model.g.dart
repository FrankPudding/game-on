// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fargo_rate_ranking_policy_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FargoRateRankingPolicyHiveModelAdapter
    extends TypeAdapter<FargoRateRankingPolicyHiveModel> {
  @override
  final typeId = 12;

  @override
  FargoRateRankingPolicyHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FargoRateRankingPolicyHiveModel(
      id: fields[0] as String,
      name: fields[1] as String,
      leagueId: fields[5] == null ? '' : fields[5] as String?,
      categoryIds:
          fields[6] == null ? [] : (fields[6] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, FargoRateRankingPolicyHiveModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.leagueId)
      ..writeByte(6)
      ..write(obj.categoryIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FargoRateRankingPolicyHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
