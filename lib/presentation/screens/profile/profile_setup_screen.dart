import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/profile/user_provider.dart';

/// Profile setup screen shown after first signup or when editing profile.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

// Default avatar options (emoji-based)
const List<String> _defaultAvatars = [
  '⚽', '🏀', '🏐', '🏓', '🏅', '🥇', '🎯', '🔥',
  '⚡', '🌟', '🦁', '🐯', '🦅', '🐺', '🦊', '🐻',
];

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final List<String> _selectedSports = [];
  // Per-sport skill level: sport label -> 1-100
  final Map<String, double> _sportSkillLevels = {};
  String _frequency = 'casual';
  int _notificationPrefMinutes = 30;
  bool _isSubmitting = false;
  String? _selectedAvatar;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().currentUser;
    if (user != null) {
      _selectedSports.addAll(user.sports);
      _frequency = user.frequency;
      if (user.profilePictureUrl != null && user.profilePictureUrl!.startsWith('emoji:')) {
        _selectedAvatar = user.profilePictureUrl!.replaceFirst('emoji:', '');
      }
      user.sportRatings.forEach((sport, rating) {
        _sportSkillLevels[sport] = rating.toDouble();
      });
      _notificationPrefMinutes = user.notificationPrefMinutes;
      _isEditing = user.hasCompletedProfile;
    }
  }

  double _skillForSport(String sport) => _sportSkillLevels[sport] ?? 50.0;

  Future<void> _handleComplete() async {
    if (_selectedSports.isEmpty) {
      Helpers.showSnackBar(context, 'Please select at least one sport',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    // Build per-sport ratings map
    final sportRatings = <String, int>{
      for (final sport in _selectedSports)
        sport: _skillForSport(sport).round(),
    };

    // Overall skill = average of selected sports
    final avgSkill = (sportRatings.values.reduce((a, b) => a + b) /
            sportRatings.length)
        .round();

    final success = await userProvider.updateProfile(
      uid: auth.userId,
      sports: _selectedSports,
      skillLevel: avgSkill,
      sportRatings: sportRatings,
      frequency: _frequency,
      profilePictureUrl: _selectedAvatar != null ? 'emoji:$_selectedAvatar' : null,
      notificationPrefMinutes: _notificationPrefMinutes,
    );

    if (success && mounted) {
      if (_isEditing) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else if (mounted) {
      Helpers.showSnackBar(context, 'Failed to save profile', isError: true);
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Header
                  Text(
                    'Set Up Your Profile',
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your sports preferences',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 36),

                  // ── Avatar Selection ──
                  Text(
                    'Choose Your Avatar',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _defaultAvatars.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final avatar = _defaultAvatars[index];
                        final isSelected = _selectedAvatar == avatar;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedAvatar = isSelected ? null : avatar),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withAlpha(30)
                                  : theme.colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withAlpha(40),
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                avatar,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Sport Selection ──
                  Text(
                    'Select Your Sports',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose one or more sports you play',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: SportType.values.map((sport) {
                      final isSelected = _selectedSports.contains(sport.label);
                      final color = Helpers.sportColor(sport.label);
                      return FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Helpers.sportIcon(sport.label),
                              size: 18,
                              color: isSelected
                                  ? color
                                  : theme.colorScheme.onSurface.withAlpha(180),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sport.label,
                              style: TextStyle(
                                color: isSelected
                                    ? color
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        selectedColor: color.withAlpha(40),
                        checkmarkColor: color,
                        backgroundColor: theme.colorScheme.surface,
                        side: BorderSide(
                          color: isSelected
                              ? color.withAlpha(120)
                              : theme.colorScheme.outline.withAlpha(60),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSports.add(sport.label);
                              if (!_sportSkillLevels.containsKey(sport.label)) {
                                _sportSkillLevels[sport.label] = 50.0;
                              }
                            } else {
                              _selectedSports.remove(sport.label);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  // ── Per-Sport Skill Levels ──
                  if (_selectedSports.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Skill Level per Sport',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rate your skill for each sport you play',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._selectedSports.map((sport) {
                      final color = Helpers.sportColor(sport);
                      final skillVal = _skillForSport(sport);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Helpers.sportIcon(sport), size: 20, color: color),
                                const SizedBox(width: 8),
                                Text(
                                  sport,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Helpers.skillColor(skillVal.round())
                                        .withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${skillVal.round()} — ${Helpers.skillLabel(skillVal.round())}',
                                    style: TextStyle(
                                      color: Helpers.skillColor(skillVal.round()),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSkillLabel('Beginner', const Color(0xFF2ECC71)),
                                _buildSkillLabel('Intermediate', const Color(0xFFF39C12)),
                                _buildSkillLabel('Advanced', const Color(0xFFE74C3C)),
                              ],
                            ),
                            Slider(
                              value: skillVal,
                              min: 1,
                              max: 100,
                              divisions: 99,
                              activeColor: Helpers.skillColor(skillVal.round()),
                              label:
                                  '${skillVal.round()} — ${Helpers.skillLabel(skillVal.round())}',
                              onChanged: (val) {
                                setState(() => _sportSkillLevels[sport] = val);
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 12),

                  // ── Play Frequency ──
                  Text(
                    'How Often Do You Play?',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ...PlayFrequency.values.map((freq) {
                    final isSelected = _frequency == freq.name;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() => _frequency = freq.name);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withAlpha(15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withAlpha(40),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface
                                          .withAlpha(100),
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  freq.label,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 32),

                  // ── Match Reminder ──
                  Text(
                    'Match Reminder',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notify me before an upcoming match starts:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('$_notificationPrefMinutes min', style: theme.textTheme.titleMedium),
                      Expanded(
                        child: Slider(
                          value: _notificationPrefMinutes.toDouble(),
                          min: 5,
                          max: 120,
                          divisions: 23,
                          label: '$_notificationPrefMinutes min',
                          onChanged: (val) {
                            setState(() {
                              _notificationPrefMinutes = val.toInt();
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Complete button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleComplete,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Complete Setup'),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          if (_isEditing)
            Positioned(
              top: 10,
              right: 10,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, size: 28),
                  onPressed: () => context.pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface.withAlpha(200),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
