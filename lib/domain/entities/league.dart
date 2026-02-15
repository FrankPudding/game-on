import 'package:game_on/domain/entities/match.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';

class League<M extends Match> {
  League({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.rankingPolicy,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isArchived;
  final RankingPolicy<M> rankingPolicy;

  League<M> copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? isArchived,
    RankingPolicy<M>? rankingPolicy,
  }) {
    return League<M>(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
      rankingPolicy: rankingPolicy ?? this.rankingPolicy,
    );
  }
}
