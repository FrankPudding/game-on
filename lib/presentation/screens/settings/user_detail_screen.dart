import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/user_detail_provider.dart';
import '../../../providers/users_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_edit_dialog.dart';
import '../../widgets/player_edit_dialog.dart';
import '../match/log_match_screen.dart';

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(usersProvider);
    final userDetailAsync = ref.watch(userDetailProvider(userId));

    return Scaffold(
      appBar: AppBar(
title: userAsync.when(
        data: (users) {
          final user = users.where((u) => u.id == userId).firstOrNull;
          if (user == null) {
            return const Text('User Detail');
          }
          final title =
              "${user.name}${user.name.toLowerCase().endsWith('s') ? "'" : "'s"} Leagues";
          return Text(title);
        },
        loading: () => const Text('Loading...'),
        error: (_, __) => const Text('User Detail'),
      ),
        actions: [
          userAsync.when(
            data: (users) {
              final user = users.where((u) => u.id == userId).firstOrNull;
              if (user == null) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => UserEditDialog.show(context, user: user),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: userDetailAsync.when(
        data: (leagues) {
          if (leagues.isEmpty) {
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
                  const Text(
                    'This user has not joined any leagues yet.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: leagues.length,
            itemBuilder: (context, index) {
              final info = leagues[index];
              return _LeagueParticipantTile(info: info);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _LeagueParticipantTile extends StatelessWidget {
  const _LeagueParticipantTile({required this.info});

  final UserLeagueInfo info;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentRed.withValues(alpha: 0.1),
          child: Text(
            info.league.name[0].toUpperCase(),
            style: const TextStyle(
              color: AppTheme.accentRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          info.league.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Nickname: ${info.player.name}',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_note, size: 20),
              onPressed: () => PlayerEditDialog.show(
                context,
                leagueId: info.league.id,
                player: info.player,
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (info.matches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No matches recorded in this league.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: info.matches.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final match = info.matches[index];
                final dateStr =
                    DateFormat('MMM d, yyyy').format(match.playedAt);

                String result = 'Result';
                Color resultColor = AppTheme.textPrimary;

                if (match.isDraw) {
                  result = 'Draw';
                  resultColor = AppTheme.textSecondary;
                } else if (match.winnerSideId != null) {
                  final winnerSide =
                      match.sides.firstWhere((s) => s.id == match.winnerSideId);
                  final isWinner =
                      winnerSide.playerIds.contains(info.player.id);
                  result = isWinner ? 'Won' : 'Lost';
                  resultColor = isWinner ? Colors.green : AppTheme.errorRed;
                }

                return ListTile(
                  dense: true,
                  title: Text(result,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: resultColor)),
                  subtitle: Text(dateStr),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LogMatchScreen(
                          leagueId: info.league.id,
                          match: match,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
