import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/league.dart';
import '../../models/league_player.dart';
import '../../models/match/simple_match.dart';
import '../../models/match/first_to_match.dart';
import '../../models/match/timed_match.dart';
import '../../models/match/frames_match.dart';
import '../../models/match/tennis_match.dart';
import '../../providers/league_detail_provider.dart';
import '../../providers/leagues_provider.dart';
import '../../theme/app_theme.dart';
import '../match/log_match_screen.dart';
import '../match/live_scoring_screen.dart';

class LeagueDetailScreen extends ConsumerStatefulWidget {
  final League league;

  const LeagueDetailScreen({
    super.key,
    required this.league,
  });

  @override
  ConsumerState<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends ConsumerState<LeagueDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteLeague() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete League?'),
        content: const Text(
          'This will permanently remove the league and all its match history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Use the leaguesProvider to delete so the HomeScreen updates
      await ref.read(leaguesProvider.notifier).deleteLeague(widget.league.id);
      if (mounted) {
        Navigator.pop(context); // Back to HomeScreen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('League deleted')),
        );
      }
    }
  }

  void _showAddPlayerDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddPlayerDialog(leagueId: widget.league.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leagueDetailAsync = ref.watch(leagueDetailProvider(widget.league.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.league.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Standings'),
            Tab(text: 'Matches'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddPlayerDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _deleteLeague();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppTheme.errorRed),
                    SizedBox(width: 8),
                    Text('Delete League',
                        style: TextStyle(color: AppTheme.errorRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: leagueDetailAsync.when(
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            _StandingsTab(
              players: state.players,
              playerStats: state.playerStats,
              onAddPlayer: _showAddPlayerDialog,
            ),
            _MatchesTab(
              matches: state.matches,
              players: state.players, // Pass players for name lookup
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (widget.league.scoringSystem == ScoringSystem.simple) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    LogMatchScreen(leagueId: widget.league.id),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LiveScoringScreen(
                  leagueId: widget.league.id,
                  scoringSystem: widget.league.scoringSystem,
                ),
              ),
            );
          }
        },
        label: const Text('Log Match'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _StandingsTab extends StatelessWidget {
  final List<LeaguePlayer> players;
  final Map<String, PlayerStats> playerStats;
  final VoidCallback onAddPlayer;

  const _StandingsTab({
    required this.players,
    required this.playerStats,
    required this.onAddPlayer,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard,
                size: 64, color: AppTheme.textTertiary.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text('No players yet'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onAddPlayer,
              child: const Text('Add Player'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            border: Border(
              bottom: BorderSide(color: Colors.black.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 32, child: Text('#', style: _headerStyle)),
              const Expanded(child: Text('PLAYER', style: _headerStyle)),
              _buildHeaderCell('P', 'Matches Played'),
              const SizedBox(width: 16),
              _buildHeaderCell('Pts', 'Total Points',
                  width: 60, align: TextAlign.right),
            ],
          ),
        ),
        // Standings List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: players.length,
            separatorBuilder: (context, index) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 1),
            ),
            itemBuilder: (context, index) {
              final player = players[index];
              final stats = playerStats[player.id] ??
                  const PlayerStats(points: 0, matchesPlayed: 0);
              final isTop3 = index < 3;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    // Rank
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight:
                              isTop3 ? FontWeight.bold : FontWeight.normal,
                          color: isTop3
                              ? AppTheme.accentRed
                              : AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // Player Info
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                AppTheme.accentRed.withOpacity(0.1),
                            child: Text(
                              player.name.isNotEmpty
                                  ? player.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: AppTheme.accentRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              player.name,
                              style: TextStyle(
                                fontWeight:
                                    isTop3 ? FontWeight.bold : FontWeight.w500,
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Matches Played
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${stats.matchesPlayed}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Points
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${stats.points}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppTheme.accentRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    color: AppTheme.textTertiary,
    letterSpacing: 1.2,
  );

  Widget _buildHeaderCell(String label, String tooltip,
      {double width = 40, TextAlign align = TextAlign.center}) {
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: SizedBox(
        width: width,
        child: Text(
          label,
          textAlign: align,
          style: _headerStyle,
        ),
      ),
    );
  }
}

class _MatchesTab extends StatelessWidget {
  final List<dynamic> matches;
  final List<LeaguePlayer> players;

  const _MatchesTab({
    required this.matches,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text('No matches played yet'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        final playedAt = DateFormat('MMM d, h:mm a').format(match.playedAt);

        String title = 'Match';
        String subtitle = playedAt;

        if (match is SimpleMatch) {
          if (match.isDraw) {
            title = 'Draw';
          } else if (match.winnerId != null) {
            final winner = players.firstWhere(
              (p) => p.id == match.winnerId,
              orElse: () => _unknownPlayer(),
            );
            title = 'Winner: ${winner.name}';
          }
        } else if (match is FirstToMatch) {
          title = 'First To Match';
        } else if (match is TimedMatch) {
          title = 'Timed Match';
        } else if (match is FramesMatch) {
          title = 'Frames Match';
        } else if (match is TennisMatch) {
          title = 'Tennis Match';
        }

        return Card(
          child: ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            // onTap: match detail...
          ),
        );
      },
    );
  }

  LeaguePlayer _unknownPlayer() => LeaguePlayer(
        id: '',
        leagueId: '',
        playerId: '',
        name: 'Unknown',
        avatarColorHex: '',
      );
}

class _AddPlayerDialog extends ConsumerStatefulWidget {
  final String leagueId;
  const _AddPlayerDialog({required this.leagueId});

  @override
  ConsumerState<_AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends ConsumerState<_AddPlayerDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(leagueDetailProvider(widget.leagueId).notifier)
          .addPlayer(name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Player'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Player Name'),
        textCapitalization: TextCapitalization.words,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator())
              : const Text('Add'),
        ),
      ],
    );
  }
}
