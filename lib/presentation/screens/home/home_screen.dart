import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../application/preferences/sort_preference.dart';
import '../../../providers/sorted_leagues_provider.dart';
import '../../../providers/sort_preference_provider.dart';

import '../../theme/app_theme.dart';
import '../league/select_ranking_policy_screen.dart';
import '../league/league_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortedAsync = ref.watch(sortedLeaguesProvider);
    final sortPref = ref.watch(sortPreferenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leagues'),
        centerTitle: false,
        actions: [
          PopupMenuButton<LeagueSortPreference>(
            tooltip: 'Sort',
            onSelected: (preference) => ref
                .read(sortPreferenceProvider.notifier)
                .setPreference(preference),
            itemBuilder: (context) => [
              PopupMenuItem<LeagueSortPreference>(
                value: LeagueSortPreference.latest,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Latest',
                        style: TextStyle(
                          fontWeight: sortPref == LeagueSortPreference.latest
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (sortPref == LeagueSortPreference.latest)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
              PopupMenuItem<LeagueSortPreference>(
                value: LeagueSortPreference.oldest,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Oldest',
                        style: TextStyle(
                          fontWeight: sortPref == LeagueSortPreference.oldest
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (sortPref == LeagueSortPreference.oldest)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
              PopupMenuItem<LeagueSortPreference>(
                value: LeagueSortPreference.aToZ,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'A-Z',
                        style: TextStyle(
                          fontWeight: sortPref == LeagueSortPreference.aToZ
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (sortPref == LeagueSortPreference.aToZ)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
              PopupMenuItem<LeagueSortPreference>(
                value: LeagueSortPreference.zToA,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Z-A',
                        style: TextStyle(
                          fontWeight: sortPref == LeagueSortPreference.zToA
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (sortPref == LeagueSortPreference.zToA)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert),
                  SizedBox(width: 4),
                  Text('Sort'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: sortedAsync.when(
        data: (sortedLeagues) {
          if (sortedLeagues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 80,
                    color: AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No leagues yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SelectRankingPolicyScreen(),
                        ),
                      );
                    },
                    child: const Text('Create First League'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedLeagues.length,
            itemBuilder: (context, index) {
              final sortedLeague = sortedLeagues[index];
              return _SortedLeagueCard(sortedLeague: sortedLeague);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: $err',
              style: const TextStyle(color: AppTheme.errorRed)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SelectRankingPolicyScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.accentRed,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _SortedLeagueCard extends StatelessWidget {
  const _SortedLeagueCard({required this.sortedLeague});
  final SortedLeague sortedLeague;

  @override
  Widget build(BuildContext context) {
    final league = sortedLeague.league;
    final lastPlayed = sortedLeague.lastPlayed;
    final lastPlayedText = lastPlayed == null
        ? 'Last played: Never'
        : 'Last played: ${DateFormat('MMM d, yyyy').format(lastPlayed)}';
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeagueDetailScreen(league: league),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sports_esports,
                        color: AppTheme.accentRed),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          league.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                        ),
                        Text(
                          lastPlayedText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
