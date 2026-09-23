import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/league.dart';
import '../../../domain/entities/league_player.dart';
import '../../../domain/entities/side.dart';
import '../../../domain/entities/matches/simple_match.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/value_objects/fargo_player_stats.dart';
import '../../../providers/league_detail_provider.dart';
import '../../../providers/leagues_provider.dart';
import '../../../providers/users_provider.dart';
import '../../theme/app_theme.dart';
import '../match/log_match_screen.dart';
import '../settings/create_user_screen.dart';
import 'widgets/player_edit_dialog.dart';

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

  Future<void> _showAddPlayerDialog() async {
    await showDialog(
      context: context,
      builder: (_) => _AddPlayerDialog(leagueId: widget.league.id),
    );
    // Dialog closed - if user created a user via CreateUserScreen,
    // they need to tap "Add Player" again
  }

  void _showEditPlayerDialog(LeaguePlayer player) {
    PlayerEditDialog.show(
      context,
      leagueId: widget.league.id,
      player: player,
      showRemoveAction: true,
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
              fargoStats: state.fargoStats,
              isGoalDifference: state.isGoalDifference,
              isFargo: state.isFargo,
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
    this.isFargo = false,
    this.fargoStats = const {},
  });
  final List<LeaguePlayer> players;
  final Map<String, PlayerStats> playerStats;
  final Map<String, FargoPlayerStats> fargoStats;
  final VoidCallback onAddPlayer;
  final Function(LeaguePlayer) onEditPlayer;
  final bool isGoalDifference;
  final bool isFargo;

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
              if (isFargo) ...[
                _buildHeaderCell('P', 'Matches Played'),
                _buildHeaderCell('W', 'Wins'),
                _buildHeaderCell('L', 'Losses'),
                _buildHeaderCell('Win%', 'Win Percentage'),
                _buildHeaderCell('Fargo', 'Fargo Rating'),
              ] else ...[
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
              final fargo = fargoStats[player.id] ??
                  const FargoPlayerStats(
                      matchesPlayed: 0, wins: 0, losses: 0, rating: 500);
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
                      if (isFargo) ...[
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${fargo.matchesPlayed}',
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
                            '${fargo.wins}',
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
                            '${fargo.losses}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${(fargo.winRate * 100).toStringAsFixed(1)}%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${fargo.rating}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.accentRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ] else ...[
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
  String? _selectedUserId;
  late final TextEditingController _nicknameController;
  String? _selectedIcon = '👤';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  static const List<String> _icons = [
    '👤',
    '⚽',
    '🏀',
    '🎾',
    '🏈',
    '⚾',
    '🏐',
    '🏓',
    '🏸',
    '🥊',
    '🥋',
    '🎮',
  ];

  Future<void> _onAddNewUser() async {
    // CRITICAL: Close dialog FIRST (no stacking)
    if (mounted) Navigator.of(context).pop();

    // Push CreateUserScreen (existing pattern)
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateUserScreen()),
    );
    // Dialog is closed; user returns to LeagueDetailScreen
    // They must tap "Add Player" again to add the new user
  }

  Future<void> _submit() async {
    if (_selectedUserId == null || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final leagueDetailNotifier =
          ref.read(leagueDetailProvider(widget.leagueId).notifier);
      final nickname = _nicknameController.text.trim();
      await leagueDetailNotifier.addPlayer(
        name: nickname.isNotEmpty ? nickname : '',
        userId: _selectedUserId,
        icon: _selectedIcon,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player added to league')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add player: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final leagueDetailAsync = ref.watch(leagueDetailProvider(widget.leagueId));

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Add Player',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content - shrink-wraps, only scrolls when exceeding dialog maxHeight
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: _buildContent(usersAsync, leagueDetailAsync),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        _selectedUserId != null && !_isLoading ? _submit : null,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add to League'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AsyncValue<List<User>> usersAsync,
      AsyncValue<LeagueDetailState> leagueDetailAsync) {
    return usersAsync.when(
      data: (users) {
        // If there are no users in the system at all, show the original empty state
        if (users.isEmpty) {
          return _buildEmptyState();
        }

        return leagueDetailAsync.when(
          data: (leagueDetail) {
            // Extract userIds of players already in the league
            final existingUserIds = leagueDetail.players
                .map((p) => p.userId)
                .where((id) => id.isNotEmpty)
                .toSet();

            // Filter out users already in the league
            final availableUsers = users
                .where((user) => !existingUserIds.contains(user.id))
                .toList();

            if (availableUsers.isEmpty) {
              return _buildNoAvailableUsersState();
            }
            return _buildUserListView(availableUsers);
          },
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error loading league details: $e'),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading users: $e'),
      ),
    );
  }

  Widget _buildNoAvailableUsersState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.people_outline, size: 48, color: AppTheme.textTertiary),
        const SizedBox(height: 8),
        Text('All users already in league',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Create a new user to add them to this league.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textTertiary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _onAddNewUser,
            icon: const Icon(Icons.person_add),
            label: const Text('Add New User'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.people_outline, size: 48, color: AppTheme.textTertiary),
        const SizedBox(height: 8),
        Text('No users yet', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Create a user first, then add them to the league.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textTertiary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _onAddNewUser,
            icon: const Icon(Icons.person_add),
            label: const Text('Add New User'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserListView(List<User> users) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // EXISTING USERS LIST (Primary View) - shrink-wraps content, scrolls only when needed
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isSelected = _selectedUserId == user.id;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.accentRed.withValues(alpha: 0.1),
                  child: Text(
                    user.icon ?? user.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.accentRed, fontSize: 14),
                  ),
                ),
                title: Text(
                  user.name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected ? AppTheme.accentRed : AppTheme.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.accentRed)
                    : null,
                selected: isSelected,
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedUserId = null;
                    _nicknameController.clear();
                    _selectedIcon = '👤';
                  } else {
                    _selectedUserId = user.id;
                    _nicknameController.text = user.name; // Pre-fill nickname
                    _selectedIcon = user.icon ?? '👤'; // Pre-fill icon
                  }
                }),
              );
            },
          ),
        ),

        // CTA: ADD NEW USER BUTTON - hidden when a user is selected
        if (_selectedUserId == null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _onAddNewUser,
              icon: const Icon(Icons.person_add),
              label: const Text('Add New User'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],

        // SELECTED USER DETAILS (Progressive Disclosure) - preview removed, selection indicated via list highlight
        if (_selectedUserId != null) ...[
          const SizedBox(height: 16),
          _buildNicknameField(),
          const SizedBox(height: 16),
          _buildIconPicker(),
        ],
      ],
    );
  }

  Widget _buildNicknameField() {
    return TextField(
      controller: _nicknameController,
      decoration: const InputDecoration(
        labelText: 'Nickname (Optional)',
        hintText: 'Defaults to user name',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Icon', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _icons.map((icon) {
            final isSelected = _selectedIcon == icon;
            return FilterChip(
              label: Text(icon, style: const TextStyle(fontSize: 20)),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedIcon = icon),
              backgroundColor: AppTheme.surfaceWhite,
              selectedColor: AppTheme.accentRed.withValues(alpha: 0.1),
              checkmarkColor: AppTheme.accentRed,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.accentRed
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
