import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/league_player.dart';
import '../../../providers/league_detail_provider.dart';
import '../theme/app_theme.dart';

import '../../../providers/user_detail_provider.dart';

class PlayerEditDialog extends ConsumerStatefulWidget {
  const PlayerEditDialog({
    super.key,
    required this.leagueId,
    required this.player,
  });

  final String leagueId;
  final LeaguePlayer player;

  static Future<void> show(BuildContext context,
      {required String leagueId, required LeaguePlayer player}) {
    return showDialog(
      context: context,
      builder: (context) =>
          PlayerEditDialog(leagueId: leagueId, player: player),
    );
  }

  @override
  ConsumerState<PlayerEditDialog> createState() => _PlayerEditDialogState();
}

class _PlayerEditDialogState extends ConsumerState<PlayerEditDialog> {
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
      ref.invalidate(userDetailProvider(widget.player.userId));
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit League Participant'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Changes only affect this league.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nickname',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            const Text('Choose Icon',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((icon) {
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = icon),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedIcon == icon
                          ? AppTheme.accentRed.withValues(alpha: 0.1)
                          : AppTheme.surfaceOffWhite,
                      border: Border.all(
                        color: _selectedIcon == icon
                            ? AppTheme.accentRed
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
