import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/notifications/notification_provider.dart';

import '../../widgets/player_avatar.dart';
import '../../widgets/skill_indicator.dart';

/// User profile screen with stats, settings, and logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile;
    final notifications = context.watch<NotificationProvider>();

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // Notifications
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
              if (notifications.unreadCount > 0)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      '${notifications.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Dark mode toggle
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              // Toggle is handled by ThemeProvider in main.dart
              final themeNotifier =
                  context.read<ValueNotifier<ThemeMode>>();
              themeNotifier.value = themeNotifier.value == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
          ),
          // Edit Profile Button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/profile-setup');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // ── Avatar + Name ──
            PlayerAvatar(
              name: profile.name,
              imageUrl: profile.profilePictureUrl,
              radius: 50,
              skillLevel: profile.skillLevel,
            ),
            const SizedBox(height: 16),
            Text(
              profile.name,
              style: theme.textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              profile.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),

            const SizedBox(height: 24),

            // ── Per-Sport Ratings ──
            if (profile.sports.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Skill Ratings',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              ...profile.sports.map((sport) {
                final rating = profile.ratingForSport(sport);
                final color = Helpers.sportColor(sport);
                final skillColor = rating != null ? Helpers.skillColor(rating) : Colors.grey;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withAlpha(25),
                          color.withAlpha(8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        Icon(Helpers.sportIcon(sport),
                            size: 24, color: color),
                        const SizedBox(width: 12),
                        Text(
                          sport,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        SkillIndicator(
                          skillLevel: rating,
                          size: 36,
                          showLabel: false,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              rating != null ? '$rating/100' : 'Unrated',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: skillColor,
                              ),
                            ),
                            if (rating != null)
                              Text(
                                Helpers.skillLabel(rating),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: skillColor.withAlpha(200),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ] else ...[
              // ── Fallback: Overall Skill Level Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Helpers.skillColor(profile.skillLevel).withAlpha(30),
                      Helpers.skillColor(profile.skillLevel).withAlpha(10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Helpers.skillColor(profile.skillLevel).withAlpha(40),
                  ),
                ),
                child: Row(
                  children: [
                    SkillIndicator(
                      skillLevel: profile.skillLevel,
                      size: 56,
                      showLabel: true,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skill Rating',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${profile.skillLevel}/100',
                            style:
                                theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Helpers.skillColor(profile.skillLevel),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Stats Row ──
            Row(
              children: [
                _buildStatCard(
                  context,
                  Icons.add_circle_outline,
                  '${profile.createdMatches.length}',
                  'Created',
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  context,
                  Icons.login,
                  '${profile.joinedMatches.length}',
                  'Joined',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Friends Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/friends'),
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('My Friends'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withAlpha(20),
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 24),



            // ── Frequency Badge ──
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withAlpha(40),
                  ),
                ),
                child: Text(
                  '🔄 ${profile.frequency[0].toUpperCase()}${profile.frequency.substring(1)} player',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // ── Logout Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // App version
            Text(
              '${AppInfo.appName} v1.0.0',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(80),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(30),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
