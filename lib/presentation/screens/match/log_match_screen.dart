import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/league_player.dart';
import '../../../domain/entities/matches/simple_match.dart';
import '../../../providers/league_detail_provider.dart';
import '../../theme/app_theme.dart';

class LogMatchScreen extends ConsumerStatefulWidget {
  const LogMatchScreen({super.key, required this.leagueId, this.match});
  final String leagueId;
  final SimpleMatch? match;

  @override
  ConsumerState<LogMatchScreen> createState() => _LogMatchScreenState();
}

class _LogMatchScreenState extends ConsumerState<LogMatchScreen> {
  String? _player1Id;
  String? _player2Id;
  String? _winnerSelection; // Stores player1Id, player2Id, or 'draw'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.match != null) {
      final match = widget.match!;
      if (match.sides.length >= 2) {
        _player1Id = match.sides[0].playerIds.first;
        _player2Id = match.sides[1].playerIds.first;

        if (match.isDraw) {
          _winnerSelection = 'draw';
        } else if (match.winnerSideId != null) {
          final winnerSide = match.sides.firstWhere(
              (s) => s.id == match.winnerSideId,
              orElse: () => match.sides[0]);
          _winnerSelection = winnerSide.playerIds.first;
        }
      }
    }
  }

  void _onPlayersChanged() {
    // Reset winner selection if it's no longer valid
    if (_winnerSelection != 'draw' &&
        _winnerSelection != _player1Id &&
        _winnerSelection != _player2Id) {
      setState(() => _winnerSelection = null);
    }
  }

  Future<void> _submit() async {
    if (_player1Id == null || _player2Id == null || _winnerSelection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select players and a winner')),
      );
      return;
    }

    if (_player1Id == _player2Id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select two different players')),
      );
      return;
    }

    final isDraw = _winnerSelection == 'draw';
    final winnerId = isDraw ? _player1Id! : _winnerSelection!;
    final loserId = isDraw
        ? _player2Id!
        : (_winnerSelection == _player1Id ? _player2Id! : _player1Id!);

    setState(() => _isLoading = true);

    try {
      if (widget.match != null) {
        await ref
            .read(leagueDetailProvider(widget.leagueId).notifier)
            .updateSimpleMatch(
              matchId: widget.match!.id,
              winnerId: winnerId,
              loserId: loserId,
              isDraw: isDraw,
            );
      } else {
        await ref
            .read(leagueDetailProvider(widget.leagueId).notifier)
            .logSimpleMatch(
              winnerId: winnerId,
              loserId: loserId,
              isDraw: isDraw,
            );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.match != null
                ? 'Match updated successfully!'
                : 'Match logged successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Match?'),
        content: const Text(
            'This will permanently remove this match record. Standings will be recalculated.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(leagueDetailProvider(widget.leagueId).notifier)
            .deleteMatch(widget.match!.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Match deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(leagueDetailProvider(widget.leagueId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.match != null ? 'Edit Match' : 'Log Match'),
        actions: [
          if (widget.match != null && !_isLoading)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleteMatch,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (state) {
          if (state.players.length < 2) {
            return const Center(
              child: Text('Need at least 2 players to log a match'),
            );
          }

          // Auto-select players if there are only 2
          if (state.players.length == 2 &&
              (_player1Id == null || _player2Id == null)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _player1Id = state.players[0].id;
                  _player2Id = state.players[1].id;
                });
              }
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PlayerSelector(
                        title: 'Player 1',
                        selectedId: _player1Id,
                        players: state.players,
                        excludeId: _player2Id,
                        onSelected: (id) => setState(() {
                          _player1Id = id;
                          _onPlayersChanged();
                        }),
                        color: AppTheme.accentRed,
                      ),
                    ),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                      child: Text('VS',
                          style: TextStyle(
                            color: Colors.black12,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          )),
                    ),
                    Expanded(
                      child: _PlayerSelector(
                        title: 'Player 2',
                        selectedId: _player2Id,
                        players: state.players,
                        excludeId: _player1Id,
                        onSelected: (id) => setState(() {
                          _player2Id = id;
                          _onPlayersChanged();
                        }),
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                if (_player1Id != null && _player2Id != null) ...[
                  const Text('WINNER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textTertiary,
                          letterSpacing: 1.2,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _winnerSelection,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceOffWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    hint: const Text('Select Result'),
                    items: [
                      DropdownMenuItem(
                        value: _player1Id,
                        child: Text(
                            state.players
                                .firstWhere((p) => p.id == _player1Id)
                                .name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DropdownMenuItem(
                        value: _player2Id,
                        child: Text(
                            state.players
                                .firstWhere((p) => p.id == _player2Id)
                                .name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const DropdownMenuItem(
                        value: 'draw',
                        child: Text('Draw',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: (val) => setState(() => _winnerSelection = val),
                  ),
                ],
                const SizedBox(height: 48),
                if (_isLoading)
                  const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.accentRed))
                else
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                        widget.match != null
                            ? 'Update Match'
                            : 'Confirm Match Result',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlayerSelector extends StatelessWidget {
  const _PlayerSelector({
    required this.title,
    required this.selectedId,
    required this.players,
    this.excludeId,
    required this.onSelected,
    required this.color,
  });
  final String title;
  final String? selectedId;
  final List<LeaguePlayer> players;
  final String? excludeId;
  final ValueChanged<String> onSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final selectedPlayer = selectedId != null
        ? players.firstWhere((p) => p.id == selectedId)
        : null;

    return Column(
      children: [
        Text(title.toUpperCase(),
            style: TextStyle(
                color: color,
                letterSpacing: 1.2,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _showPicker(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOffWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selectedId != null
                    ? color
                    : Colors.black.withValues(alpha: 0.05),
                width: 2,
              ),
              boxShadow: selectedId != null
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 1)
                    ]
                  : [],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: selectedPlayer != null
                      ? Color(int.parse(selectedPlayer.avatarColorHex,
                              radix: 16))
                          .withValues(alpha: 1.0)
                      : Colors.black.withValues(alpha: 0.05),
                  child: selectedPlayer != null
                      ? Text(selectedPlayer.name[0],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 24))
                      : const Icon(Icons.person_add,
                          color: AppTheme.textTertiary),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedPlayer?.name ?? 'Select',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selectedPlayer != null
                        ? AppTheme.textPrimary
                        : AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick a Player',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final p = players[index];
                    final isExcluded = p.id == excludeId;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Color(int.parse(p.avatarColorHex, radix: 16))
                                .withValues(alpha: 1.0),
                        child: Text(p.name[0]),
                      ),
                      title: Text(p.name,
                          style: TextStyle(
                              color: isExcluded
                                  ? AppTheme.textTertiary
                                  : AppTheme.textPrimary)),
                      onTap: isExcluded
                          ? null
                          : () {
                              onSelected(p.id);
                              Navigator.pop(context);
                            },
                      trailing: p.id == selectedId
                          ? const Icon(Icons.check, color: AppTheme.accentRed)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
