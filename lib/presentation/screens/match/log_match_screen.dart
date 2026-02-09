import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/league_player.dart';
import '../../../providers/league_detail_provider.dart';
import '../../theme/app_theme.dart';

class LogMatchScreen extends ConsumerStatefulWidget {
  final String leagueId;

  const LogMatchScreen({super.key, required this.leagueId});

  @override
  ConsumerState<LogMatchScreen> createState() => _LogMatchScreenState();
}

class _LogMatchScreenState extends ConsumerState<LogMatchScreen> {
  String? _winnerId;
  String? _loserId;
  bool _isDraw = false;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_winnerId == null || _loserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both players')),
      );
      return;
    }

    if (_winnerId == _loserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Winner and Loser cannot be the same')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(leagueDetailProvider(widget.leagueId).notifier)
          .logSimpleMatch(
            winnerId: _winnerId!,
            loserId: _loserId!,
            isDraw: _isDraw,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match logged successfully!'),
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

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(leagueDetailProvider(widget.leagueId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Match'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _submit,
              child: const Text('SAVE',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeToggle(),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PlayerSelector(
                        title: _isDraw ? 'Player 1' : 'Winner',
                        selectedId: _winnerId,
                        players: state.players,
                        excludeId: _loserId,
                        onSelected: (id) => setState(() => _winnerId = id),
                        color: _isDraw
                            ? AppTheme.accentRed
                            : AppTheme.successGreen,
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
                        title: _isDraw ? 'Player 2' : 'Loser',
                        selectedId: _loserId,
                        players: state.players,
                        excludeId: _winnerId,
                        onSelected: (id) => setState(() => _loserId = id),
                        color: _isDraw ? AppTheme.accentRed : AppTheme.errorRed,
                      ),
                    ),
                  ],
                ),
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
                    child: const Text('Confirm Match Result',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleItem(
              label: 'Standard',
              isSelected: !_isDraw,
              onTap: () => setState(() => _isDraw = false),
            ),
          ),
          Expanded(
            child: _ToggleItem(
              label: 'Draw',
              isSelected: _isDraw,
              onTap: () => setState(() => _isDraw = true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleItem(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentRed : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerSelector extends StatelessWidget {
  final String title;
  final String? selectedId;
  final List<LeaguePlayer> players;
  final String? excludeId;
  final ValueChanged<String> onSelected;
  final Color color;

  const _PlayerSelector({
    required this.title,
    required this.selectedId,
    required this.players,
    this.excludeId,
    required this.onSelected,
    required this.color,
  });

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
                color:
                    selectedId != null ? color : Colors.black.withOpacity(0.05),
                width: 2,
              ),
              boxShadow: selectedId != null
                  ? [
                      BoxShadow(
                          color: color.withOpacity(0.1),
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
                          .withOpacity(1.0)
                      : Colors.black.withOpacity(0.05),
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
                                .withOpacity(1.0),
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
