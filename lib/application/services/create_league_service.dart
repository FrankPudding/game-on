import '../../domain/entities/league.dart';
import '../../domain/entities/ranking_policy.dart';
import '../../domain/repositories/league_repository.dart';
import '../../domain/repositories/ranking_policy_repository.dart';

class CreateLeagueService {
  CreateLeagueService(this._leagueRepository, this._rankingPolicyRepository);

  final LeagueRepository _leagueRepository;
  final RankingPolicyRepository _rankingPolicyRepository;

  Future<void> execute({
    required String id,
    required String name,
    required RankingPolicy rankingPolicy,
  }) async {
    final league = League(
      id: id,
      name: name,
      createdAt: DateTime.now(),
    );

    // Ensure the ranking policy belongs to this league
    if (rankingPolicy.leagueId != id) {
      throw ArgumentError(
          'Ranking policy leagueId does not match the league id');
    }

    await _leagueRepository.put(league);
    await _rankingPolicyRepository.put(rankingPolicy);
  }
}
