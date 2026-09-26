// GENERATED CODE - DO NOT MODIFY BY HAND
// Skeleton stub - run build_runner to regenerate

part of 'elo_ranking_policy_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EloRankingPolicyHiveModelAdapter
    extends TypeAdapter<EloRankingPolicyHiveModel> {
  @override
  final typeId = 12;

  @override
  EloRankingPolicyHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EloRankingPolicyHiveModel(
      id: fields[0] as String,
      name: fields[1] as String,
      leagueId: fields[5] == null ? '' : fields[5] as String?,
      categoryIds:
          fields[6] == null ? [] : (fields[6] as List?)?.cast<String>(),
      initialRating: fields[7] == null ? 500 : fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, EloRankingPolicyHiveModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.leagueId)
      ..writeByte(6)
      ..write(obj.categoryIds)
      ..writeByte(7)
      ..write(obj.initialRating);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EloRankingPolicyHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
