import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/league_player.dart';
import '../../../../domain/entities/user.dart';
import '../../../../providers/league_detail_provider.dart';
import '../../../../providers/users_provider.dart';
import '../../../theme/app_theme.dart';

const List<String> kPlayerIcons = [
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
  '🎲',
];

class PlayerEditDialog extends ConsumerStatefulWidget {
  const PlayerEditDialog({
    super.key,
    required this.leagueId,
    required this.player,
    required this.showRemoveAction,
  });

  final String leagueId;
  final LeaguePlayer player;
  final bool showRemoveAction;

  static Future<void> show(
    BuildContext context, {
    required String leagueId,
    required LeaguePlayer player,
    required bool showRemoveAction,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PlayerEditDialog(
        leagueId: leagueId,
        player: player,
        showRemoveAction: showRemoveAction,
      ),
    );
  }

  @override
  ConsumerState<PlayerEditDialog> createState() => _PlayerEditDialogState();
}

class _PlayerEditDialogState extends ConsumerState<PlayerEditDialog> {
  late final TextEditingController _nameController;
  String? _selectedIcon;
  bool _isLoading = false;

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

  String _truncateName(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Unknown user';
    if (t.length > 22) return '${t.substring(0, 22)}…';
    return t;
  }

  String _semanticLabel(AsyncValue<User?> async) => async.when(
        data: (u) => u == null
            ? 'Edit Player, Unknown user — linked account missing'
            : 'Edit Player, linked to ${_truncateName(u.name)}',
        loading: () => 'Edit Player, loading linked user',
        error: (_, __) =>
            'Edit Player, Unknown user — failed to load linked user',
      );

  Widget _buildTitle(AsyncValue<User?> async) => async.when(
        data: (user) {
          final name = user == null ? 'Unknown user' : _truncateName(user.name);
          final isUnknown = name == 'Unknown user';
          final suffix = ' ($name)';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Edit Player'),
              Flexible(
                child: Text(
                  suffix,
                  overflow: TextOverflow.ellipsis,
                  style: isUnknown
                      ? const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textTertiary,
                        )
                      : null,
                ),
              ),
            ],
          );
        },
        loading: () => const Text('Edit Player'),
        error: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Player'),
            const Flexible(
              child: Text(
                ' (Unknown user)',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
      );

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
      // Invalidation is handled by LeagueDetailNotifier.updatePlayer — do not
      // duplicate invalidate here (see docs/architecture/provider-invalidation.md).
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
          'Are you sure you want to remove ${widget.player.name} from this league? This only works if they have no match history.',
        ),
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
        // Invalidation handled by LeagueDetailNotifier.removePlayer.
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
    final userAsync = ref.watch(usersProvider.select((a) => a.whenData(
        (users) =>
            users.where((u) => u.id == widget.player.userId).firstOrNull)));

    return AlertDialog(
      title: Semantics(
        header: true,
        label: _semanticLabel(userAsync),
        child: ExcludeSemantics(child: _buildTitle(userAsync)),
      ),
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
            const Text(
              'Choose Icon',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kPlayerIcons.map((icon) {
                final isSelected = _selectedIcon == icon;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = icon),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentRed.withValues(alpha: 0.1)
                          : AppTheme.surfaceOffWhite,
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentRed
                            : Colors.grey.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
            if (widget.showRemoveAction) ...[
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
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
