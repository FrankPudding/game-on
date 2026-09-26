// ignore_for_file: public_member_api_docs

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/services/sorted_leagues_service.dart';
import '../domain/entities/league.dart';
import 'leagues_provider.dart';
import 'league_detail_provider.dart';
import 'sort_preference_provider.dart';

/// View-model for sorted leagues list.
///
/// Combines [League] with derived `lastPlayed` (max `playedAt` of completed
/// matches, or `null` → "Never"). DTOs must not appear here (R6).
class SortedLeague {
  const SortedLeague({
    required this.league,
    required this.lastPlayed,
  });

  final League league;
  final DateTime? lastPlayed;
}

/// Async notifier delivering sorted leagues.
///
/// Performance (R5): bulk `getAll()` for leagues + matches, groupBy O(M+L log L).
/// KeepAlive: provider is not autoDispose so preference switches do not refetch
/// unnecessarily; explicit invalidation only after writes.
/// No mutation methods — derived, invalidated explicitly by
/// leagues/match mutations (R7).
final sortedLeaguesProvider =
    AsyncNotifierProvider<SortedLeaguesNotifier, List<SortedLeague>>(
  SortedLeaguesNotifier.new,
);

class SortedLeaguesNotifier extends AsyncNotifier<List<SortedLeague>> {
  @override
  Future<List<SortedLeague>> build() async {
    // Explicit read without watch (R7)
    final leagueRepo = ref.read(leagueRepositoryProvider);
    final matchRepo = ref.read(simpleMatchRepositoryProvider);
    final preference = ref.read(sortPreferenceProvider);

    // Systematic failure visible: let exceptions propagate
    final leagues = await leagueRepo.getAll();
    final matches = await matchRepo.getAll();

    // GroupBy single scan O(M) - bulk max per league
    final Map<String, DateTime> maxMap = {};
    for (final m in matches) {
      if (!m.isComplete) continue;
      final existing = maxMap[m.leagueId];
      if (existing == null || m.playedAt.isAfter(existing)) {
        maxMap[m.leagueId] = m.playedAt;
      }
    }
    final sortedLeagues = leagues.map((league) {
      final lastPlayed = maxMap[league.id];
      return SortedLeague(league: league, lastPlayed: lastPlayed);
    }).toList();

    // Use pure service to sort (deterministic, copy not mutate)
    return sortLeagues(sortedLeagues, preference);
  }
}
