import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../articles/providers/article_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            title: Text('Settings'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),

              // Digest Settings Section
              _SectionHeader(title: 'Daily Digest'),
              _SettingsTile(
                icon: Icons.schedule_outlined,
                title: 'Digest Time',
                subtitle: '8:00 AM',
                onTap: () {
                  // TODO: Time picker
                },
              ),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                subtitle: 'Get notified when your daily digest is ready',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // TODO: Toggle notifications
                  },
                ),
              ),

              // Content Settings Section
              _SectionHeader(title: 'Content'),
              _SettingsTile(
                icon: Icons.image_outlined,
                title: 'Analyze Images',
                subtitle: 'Use AI to describe and analyze images in articles',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // TODO: Toggle image analysis
                  },
                ),
              ),
              _SettingsTile(
                icon: Icons.comment_outlined,
                title: 'Include Comments',
                subtitle: 'Extract and summarize discussion threads',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // TODO: Toggle comments
                  },
                ),
              ),

              // Account Section
              _SectionHeader(title: 'Account'),
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Sign In',
                subtitle: 'Sync your library across devices',
                onTap: () {
                  // TODO: Auth flow
                },
              ),
              _SettingsTile(
                icon: Icons.cloud_sync_outlined,
                title: 'Sync Status',
                subtitle: 'Last synced: Just now',
              ),

              // Data Section
              _SectionHeader(title: 'Data'),
              _SettingsTile(
                icon: Icons.archive_outlined,
                title: 'Archived Articles',
                subtitle: 'View your archived items',
                onTap: () {
                  // TODO: Archive view
                },
              ),
              _SettingsTile(
                icon: Icons.download_outlined,
                title: 'Export Data',
                subtitle: 'Download all your articles and digests',
                onTap: () {
                  // TODO: Export
                },
              ),
              _SettingsTile(
                icon: Icons.delete_outline,
                iconColor: Colors.red,
                title: 'Clear All Data',
                subtitle: 'Delete all articles and digests',
                onTap: () {
                  _showClearDataDialog(context, ref);
                },
              ),

              // About Section
              _SectionHeader(title: 'About'),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: '1.0.0',
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  // TODO: Open privacy policy
                },
              ),
              _SettingsTile(
                icon: Icons.article_outlined,
                title: 'Terms of Service',
                onTap: () {
                  // TODO: Open terms
                },
              ),

              const SizedBox(height: 32),

              // Credits
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      'Powered by Claude AI',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.mutedTextColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Made with ❤️',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.mutedTextColor,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ]),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This will permanently delete all your saved articles and digests. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Clear all data
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? context.mutedTextColor,
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: context.mutedTextColor),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: context.mutedTextColor)
              : null),
      onTap: onTap,
    );
  }
}
