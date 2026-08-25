import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/league.dart';
import '../../../domain/entities/league_player.dart';
import '../../../domain/entities/side.dart';
import '../../../domain/entities/matches/simple_match.dart';
import '../../../providers/league_detail_provider.dart';
import '../../../providers/leagues_provider.dart';
import '../../../providers/users_provider.dart';
import '../../theme/app_theme.dart';
import '../match/log_match_screen.dart';
import '../settings/create_user_screen.dart';

class LeagueDetailScreen extends ConsumerStatefulWidget {
  const LeagueDetailScreen({
    super.key,
    required this.league,
  });
  final League league;

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

  void _showEditPlayerDialog(LeaguePlayer player) {
    showDialog(
      context: context,
      builder: (context) =>
          _EditPlayerDialog(leagueId: widget.league.id, player: player),
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
              isGoalDifference: state.isGoalDifference,
              onAddPlayer: _showAddPlayerDialog,
              onEditPlayer: _showEditPlayerDialog,
            ),
            _MatchesTab(
              leagueId: widget.league.id,
              matches: state.matches,
              players: state.players,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogMatchScreen(leagueId: widget.league.id),
            ),
          );
        },
        label: const Text('Log Match'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _StandingsTab extends StatelessWidget {
  const _StandingsTab({
    required this.players,
    required this.playerStats,
    required this.onAddPlayer,
    required this.onEditPlayer,
    this.isGoalDifference = false,
  });
  final List<LeaguePlayer> players;
  final Map<String, PlayerStats> playerStats;
  final VoidCallback onAddPlayer;
  final Function(LeaguePlayer) onEditPlayer;
  final bool isGoalDifference;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard,
                size: 64, color: AppTheme.textTertiary.withValues(alpha: 0.2)),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 32, child: Text('#', style: _headerStyle)),
              const Expanded(child: Text('PLAYER', style: _headerStyle)),
              _buildHeaderCell('P', 'Matches Played'),
              if (isGoalDifference) ...[
                _buildHeaderCell('GF', 'Goals For'),
                _buildHeaderCell('GA', 'Goals Against'),
                _buildHeaderCell('GD', 'Goal Difference'),
              ],
              const SizedBox(width: 4),
              _buildHeaderCell('Pts', 'Total Points',
                  width: 40, align: TextAlign.center),
            ],
          ),
        ),
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

              return InkWell(
                onTap: () => onEditPlayer(player),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
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
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  AppTheme.accentRed.withValues(alpha: 0.1),
                              child: player.icon != null
                                  ? Text(player.icon!,
                                      style: const TextStyle(fontSize: 14))
                                  : Text(
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
                                  fontWeight: isTop3
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      if (isGoalDifference) ...[
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${stats.goalsFor}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${stats.goalsAgainst}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            _formatGoalDifference(stats.goalDifference),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${stats.points}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.accentRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
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

  String _formatGoalDifference(int gd) => gd > 0 ? '+$gd' : '$gd';
}

class _MatchesTab extends StatelessWidget {
  const _MatchesTab({
    required this.leagueId,
    required this.matches,
    required this.players,
  });
  final String leagueId;
  final List<SimpleMatch> matches;
  final List<LeaguePlayer> players;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history,
                size: 64, color: Colors.white.withValues(alpha: 0.2)),
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
        final playedAt = DateFormat('MMM d, yyyy').format(match.playedAt);

        Widget titleWidget =
            const Text('Match', style: TextStyle(fontWeight: FontWeight.bold));
        String subtitle = playedAt;

        if (match.isDraw) {
          final p1Id =
              match.sides.isNotEmpty && match.sides[0].playerIds.isNotEmpty
                  ? match.sides[0].playerIds.first
                  : null;
          final p2Id =
              match.sides.length > 1 && match.sides[1].playerIds.isNotEmpty
                  ? match.sides[1].playerIds.first
                  : null;

          final p1 = players.firstWhere((p) => p.id == p1Id,
              orElse: () => _unknownPlayer());
          final p2 = players.firstWhere((p) => p.id == p2Id,
              orElse: () => _unknownPlayer());

          titleWidget = Text.rich(
            TextSpan(
              style: const TextStyle(color: AppTheme.textPrimary),
              children: [
                TextSpan(
                  text: p1.icon != null ? '${p1.icon} ${p1.name}' : p1.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' vs '),
                TextSpan(
                  text: p2.icon != null ? '${p2.icon} ${p2.name}' : p2.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        } else if (match.winnerSideId != null) {
          final winnerSide = match.sides.firstWhere(
            (s) => s.id == match.winnerSideId,
            orElse: () => Side(id: '', playerIds: []),
          );
          final loserSide = match.sides.firstWhere(
            (s) => s.id != match.winnerSideId,
            orElse: () => Side(id: '', playerIds: []),
          );

          final winnerId = winnerSide.playerIds.isNotEmpty
              ? winnerSide.playerIds.first
              : null;
          final loserId =
              loserSide.playerIds.isNotEmpty ? loserSide.playerIds.first : null;

          final winner = players.firstWhere((p) => p.id == winnerId,
              orElse: () => _unknownPlayer());
          final loser = players.firstWhere((p) => p.id == loserId,
              orElse: () => _unknownPlayer());

          titleWidget = Text.rich(
            TextSpan(
              style: const TextStyle(color: AppTheme.textPrimary),
              children: [
                TextSpan(
                  text: winner.icon != null
                      ? '${winner.icon} ${winner.name}'
                      : winner.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successGreen,
                  ),
                ),
                const TextSpan(text: ' vs '),
                TextSpan(
                  text: loser.icon != null
                      ? '${loser.icon} ${loser.name}'
                      : loser.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorRed,
                  ),
                ),
              ],
            ),
          );
        }

        return Card(
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LogMatchScreen(
                    leagueId: leagueId,
                    match: match,
                  ),
                ),
              );
            },
            title: titleWidget,
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  LeaguePlayer _unknownPlayer() => LeaguePlayer(
        id: '',
        leagueId: '',
        userId: '',
        name: 'Unknown',
        avatarColorHex: '',
      );
}

class _AddPlayerDialog extends ConsumerStatefulWidget {
  const _AddPlayerDialog({required this.leagueId});
  final String leagueId;

  @override
  ConsumerState<_AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends ConsumerState<_AddPlayerDialog> {
  final _nameController = TextEditingController();
  String? _selectedUserId;
  String? _selectedIcon = '👤';
  bool _isLoading = false;
  bool _isNewUser = true;

  final List<String> _icons = [
    '👤',
    '🎮',
    '⚽',
    '🏀',
    '🎾',
    '🎳',
    '🎯',
    '🏎️',
    '🧙',
    '🥷'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty && _selectedUserId == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(leagueDetailProvider(widget.leagueId).notifier).addPlayer(
            name: name,
            userId: _isNewUser ? null : _selectedUserId,
            icon: _selectedIcon,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding player: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return AlertDialog(
      title: const Text('Add Player'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Selection Type
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('New User'),
                    selected: _isNewUser,
                    onSelected: (val) => setState(() => _isNewUser = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Existing'),
                    selected: !_isNewUser,
                    onSelected: (val) => setState(() => _isNewUser = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isNewUser) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateUserScreen(),
                        ),
                      );
                      if (mounted) {
                        setState(() => _isNewUser = false);
                      }
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Create New User'),
                  ),
                ),
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Player Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const Text('Choose Icon',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _icons.map((icon) {
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedIcon == icon
                            ? AppTheme.accentRed.withValues(alpha: 0.2)
                            : Colors.transparent,
                        border: Border.all(
                          color: _selectedIcon == icon
                              ? AppTheme.accentRed
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (!_isNewUser)
              usersAsync.when(
                data: (users) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedUserId,
                    decoration: const InputDecoration(
                      labelText: 'Select User',
                      border: OutlineInputBorder(),
                    ),
                    items: users.map((user) {
                      return DropdownMenuItem(
                        value: user.id,
                        child: Text('${user.icon ?? "👤"} ${user.name}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedUserId = val;
                        final user = users.firstWhere((u) => u.id == val);
                        if (user.icon != null) _selectedIcon = user.icon;
                      });
                    },
                  ),
                ),
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => Text('Error loading users: $e'),
              ),

            if (!_isNewUser)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nickname (Optional)',
                  hintText: 'Defaults to user name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),

            if (!_isNewUser) ...[
              const SizedBox(height: 16),
              const Text('Choose Icon',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _icons.map((icon) {
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedIcon == icon
                            ? AppTheme.accentRed.withValues(alpha: 0.2)
                            : Colors.transparent,
                        border: Border.all(
                          color: _selectedIcon == icon
                              ? AppTheme.accentRed
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
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
              : const Text('Add to League'),
        ),
      ],
    );
  }
}

class _EditPlayerDialog extends ConsumerStatefulWidget {
  const _EditPlayerDialog({
    required this.leagueId,
    required this.player,
  });
  final String leagueId;
  final LeaguePlayer player;

  @override
  ConsumerState<_EditPlayerDialog> createState() => _EditPlayerDialogState();
}

class _EditPlayerDialogState extends ConsumerState<_EditPlayerDialog> {
  late final TextEditingController _nameController;
  String? _selectedIcon;
  bool _isLoading = false;

  final List<String> _icons = [
    '👤',
    '🎮',
    '⚽',
    '🏀',
    '🎾',
    '🎳',
    '🎯',
    '🏎️',
    '🧙',
    '🥷',
    '🐯',
    '🦊',
    '🦉',
    '🐢',
    '🦖',
    '🤖',
    '👻',
    '🍦',
    '🍕',
    '🎲'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.player.name);
    _selectedIcon = widget.player.icon ?? '👤';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(leagueDetailProvider(widget.leagueId).notifier)
          .updatePlayer(
            playerId: widget.player.id,
            name: name,
            icon: _selectedIcon,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating player: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removePlayer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Player?'),
        content: Text(
            'Are you sure you want to remove ${widget.player.name} from this league? This only works if they have no match history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(leagueDetailProvider(widget.leagueId).notifier)
            .removePlayer(widget.player.id);
        if (mounted) {
          Navigator.pop(context); // Close edit dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Player removed from league')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing player: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Player'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Player Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            const Text('Choose Icon',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((icon) {
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedIcon == icon
                          ? AppTheme.accentRed.withValues(alpha: 0.2)
                          : Colors.transparent,
                      border: Border.all(
                        color: _selectedIcon == icon
                            ? AppTheme.accentRed
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isLoading ? null : _removePlayer,
                icon: const Icon(Icons.person_remove_outlined,
                    color: AppTheme.errorRed),
                label: const Text('Remove from League',
                    style: TextStyle(color: AppTheme.errorRed)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
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
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}
