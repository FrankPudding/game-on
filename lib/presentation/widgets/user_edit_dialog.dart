import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/user.dart';
import '../../../providers/users_provider.dart';
import '../theme/app_theme.dart';

class UserEditDialog extends ConsumerStatefulWidget {
  const UserEditDialog({super.key, this.user});

  final User? user;

  static Future<void> show(BuildContext context, {User? user}) {
    return showDialog(
      context: context,
      builder: (context) => UserEditDialog(user: user),
    );
  }

  @override
  ConsumerState<UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends ConsumerState<UserEditDialog> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
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
    _nameController = TextEditingController(text: widget.user?.name);
    _selectedIcon = widget.user?.icon ?? '👤';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.user != null) {
        final updatedUser = widget.user!.copyWith(
          name: name,
          icon: _selectedIcon,
        );
        await ref.read(usersProvider.notifier).updateUser(updatedUser);
      } else {
        final newUser = User(
          id: const Uuid().v4(),
          name: name,
          avatarColorHex: 'AE0C00',
          icon: _selectedIcon,
        );
        await ref.read(usersProvider.notifier).addUser(newUser);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.user != null
                  ? 'User updated successfully'
                  : 'User created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error ${widget.user != null ? 'updating' : 'creating'} user: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit User' : 'Create User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Global users can be added to any league.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'User Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: !isEditing,
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose Avatar Icon',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((icon) {
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
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 20),
                    ),
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
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
