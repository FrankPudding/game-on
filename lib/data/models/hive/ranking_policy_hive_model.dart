import 'package:hive_ce/hive_ce.dart';
import '../../../domain/entities/ranking_policy.dart';

abstract class RankingPolicyHiveModel extends HiveObject {
  RankingPolicyHiveModel({
    required this.id,
    required this.name,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  RankingPolicy toDomain();
}
