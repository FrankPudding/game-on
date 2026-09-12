import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../theme/app_theme.dart';
import 'manage_users_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? 'Unknown';
          final buildNumber = snapshot.data?.buildNumber ?? '';
          final versionString =
              buildNumber.isNotEmpty ? '$version ($buildNumber)' : version;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _buildSectionHeader('Profile & Accounts'),
              _buildListTile(
                context,
                icon: Icons.people_outline,
                title: 'Manage Users',
                subtitle: 'Create and edit global app users',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ManageUsersScreen()),
                  );
                },
              ),
              const Divider(height: 32, indent: 16, endIndent: 16),
              _buildSectionHeader('General'),
              _buildListTile(
                context,
                icon: Icons.color_lens_outlined,
                title: 'Appearance',
                subtitle: 'Theme customization (Coming soon)',
                enabled: false,
              ),
              _buildListTile(
                context,
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                subtitle: 'Alerts and sounds (Coming soon)',
                enabled: false,
              ),
              const Divider(height: 32, indent: 16, endIndent: 16),
              _buildSectionHeader('About'),
              _buildListTile(
                context,
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: versionString,
                enabled: false,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.accentRed.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled ? AppTheme.accentRed : Colors.grey,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: enabled ? AppTheme.textPrimary : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled
              ? AppTheme.textSecondary
              : Colors.grey.withValues(alpha: 0.6),
        ),
      ),
      trailing: enabled
          ? const Icon(Icons.chevron_right, color: AppTheme.textTertiary)
          : null,
      onTap: enabled ? onTap : null,
    );
  }
}
