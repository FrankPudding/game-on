import '../entities/ranking_policy.dart';
import '../repository.dart';

abstract class RankingPolicyRepository
    extends Repository<RankingPolicy, String> {
  Future<RankingPolicy?> getByLeagueId(String leagueId);

  /// Returns policies for a given [categoryId].
  /// Scans truth box; index is cache only.
  Future<List<RankingPolicy>> getByCategory(String categoryId);
}
