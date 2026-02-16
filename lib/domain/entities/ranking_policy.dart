import 'package:game_on/domain/entities/match.dart';

abstract class RankingPolicy<M extends Match> {
  RankingPolicy({
    required this.id,
    required this.name,
    required this.leagueId,
  });

  final String id;
  final String name;
  final String leagueId;
}
