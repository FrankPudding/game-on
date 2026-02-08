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
          indicatorColor: AppTheme.mikadoYellow,
          labelColor: AppTheme.mikadoYellow,
          unselectedLabelColor: Colors.white60,
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
        ],
      ),
      body: leagueDetailAsync.when(
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            _StandingsTab(
                players: state.players, onAddPlayer: _showAddPlayerDialog),
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
  final VoidCallback onAddPlayer;

  const _StandingsTab({required this.players, required this.onAddPlayer});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard,
                size: 64, color: Colors.white.withOpacity(0.2)),
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.mikadoYellow,
              foregroundColor: Colors.black,
              child: Text(
                  player.name.isNotEmpty ? player.name[0].toUpperCase() : '?'),
            ),
            title: Text(player.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text(
              '${player.totalPoints} pts',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.mikadoYellow,
              ),
            ),
          ),
        );
      },
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
      totalPoints: 0);
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
