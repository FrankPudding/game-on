import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/users_provider.dart';
import '../../theme/app_theme.dart';
import 'create_user_screen.dart';

class ManageUsersScreen extends ConsumerWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No users created yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 72,
            ),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accentRed.withValues(alpha: 0.1),
                  child: Text(
                    user.icon ?? user.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.accentRed,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Global User'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.errorRed),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete User?'),
                        content: Text(
                            'Are you sure you want to delete ${user.name}? This will remove them from all leagues and delete all their associated match records.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.errorRed),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await ref
                          .read(usersProvider.notifier)
                          .deleteUser(user.id);
                    }
                  },
                ),
                onTap: () {
                  // TODO: Implement user editing
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateUserScreen()),
          );
        },
        label: const Text('Add User'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
