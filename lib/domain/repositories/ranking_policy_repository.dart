import '../entities/ranking_policy.dart';
import '../repository.dart';

abstract class RankingPolicyRepository
    extends Repository<RankingPolicy, String> {
  Future<RankingPolicy?> getByLeagueId(String leagueId);
}
