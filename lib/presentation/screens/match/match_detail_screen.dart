import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/helpers.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/matches/match_provider.dart';
import '../../../features/profile/user_provider.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/user_model.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/skill_indicator.dart';

/// Match detail screen showing full match info, players, and team balancing.
class MatchDetailScreen extends StatelessWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchProvider = context.read<MatchProvider>();
    final auth = context.read<AuthProvider>();

    return StreamBuilder<MatchModel?>(
      stream: matchProvider.matchStream(matchId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final match = snapshot.data;
        if (match == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Match not found')),
          );
        }

        final isCreator = match.isCreator(auth.userId);
        final hasJoined = match.hasPlayer(auth.userId);
        final sportColor = Helpers.sportColor(match.sport);

        return Scaffold(
          appBar: AppBar(
            title: Text(match.sport),
            actions: [
              if (isCreator && match.isUpcoming)
                PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'delete') {
                      final confirmed = await _showDeleteConfirmation(context);

                      if (!context.mounted || !confirmed) return;

                      final success = await matchProvider.deleteMatch(
                        matchId,
                      );

                      if (!context.mounted) return;

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Match deleted successfully')),
                        );
                        context.pop(); // go back ONLY if delete worked
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              matchProvider.errorMessage ?? 'Failed to delete match',
                            ),
                          ),
                        );
                      }
                    }


                  },

                  itemBuilder: (context) => [

                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Delete Match',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Card ──
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        sportColor.withAlpha(40),
                        sportColor.withAlpha(10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sportColor.withAlpha(40),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Helpers.sportIcon(match.sport),
                        size: 56,
                        color: sportColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        match.sport,
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: sportColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${match.creatorName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Helpers.matchStatusColor(match.status)
                              .withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          match.status.toUpperCase(),
                          style: TextStyle(
                            color: Helpers.matchStatusColor(match.status),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Match Details ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        context,
                        Icons.location_on_outlined,
                        'Location',
                        match.location,
                      ),
                      _buildDetailRow(
                        context,
                        Icons.schedule,
                        'Date & Time',
                        '${Helpers.formatDate(match.dateTime)} at ${Helpers.formatTime(match.dateTime)}',
                      ),
                      _buildDetailRow(
                        context,
                        Icons.people_outline,
                        'Format',
                        '${match.playerCount} joined • ${Helpers.formatPlayersVs(match.maxPlayers)}',
                      ),
                      if (match.description != null &&
                          match.description!.isNotEmpty)
                        _buildDetailRow(
                          context,
                          Icons.description_outlined,
                          'Description',
                          match.description!,
                        ),
                      if (match.minSkill != null || match.maxSkill != null)
                        _buildDetailRow(
                          context,
                          Icons.trending_up,
                          'Skill Range',
                          '${match.minSkill ?? 1} — ${match.maxSkill ?? 100}',
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Teams Display ──
                FutureBuilder<List<UserModel>>(
                  future: context
                      .read<UserProvider>()
                      .getUsersByIds(match.playerIds),
                  builder: (context, playerSnapshot) {
                    if (playerSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final players = playerSnapshot.data ?? [];
                    final teamAPlayers = players.where((p) => match.teamA.contains(p.uid)).toList();
                    final teamBPlayers = players.where((p) => match.teamB.contains(p.uid)).toList();
                    final maxPerTeam = match.maxPlayers ~/ 2;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTeamSection(
                          context,
                          theme,
                          teamName: match.teamAName,
                          players: teamAPlayers,
                          maxLimit: maxPerTeam,
                          color: const Color(0xFF10B981), // Emerald
                          sport: match.sport,
                        ),
                        const SizedBox(height: 24),
                        _buildTeamSection(
                          context,
                          theme,
                          teamName: match.teamBName,
                          players: teamBPlayers,
                          maxLimit: maxPerTeam,
                          color: const Color(0xFF38BDF8), // Sky
                          sport: match.sport,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // ── Bottom Action Button ──
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                height: !match.isUpcoming ? 72 : (hasJoined ? 56 : 72),
                child: !match.isUpcoming 
                    ? (isCreator 
                        ? (match.hasScore 
                            ? Center(child: Text('Final Score: ${match.scoreA} - ${match.scoreB}', style: theme.textTheme.titleLarge)) 
                            : ElevatedButton(
                                onPressed: () => _showAddScoreDialog(context, match),
                                child: const Text('Add Score'),
                              ))
                        : (match.hasScore 
                            ? Center(child: Text('Final Score: ${match.scoreA} - ${match.scoreB}', style: theme.textTheme.titleLarge))
                            : const Center(child: Text('Match finished'))))
                    : (hasJoined
                        ? (isCreator
                            ? ElevatedButton(
                                onPressed: null,
                                child: const Text('You created this match'),
                              )
                            : OutlinedButton(
                                onPressed: () async {
                                  await context
                                      .read<MatchProvider>()
                                      .leaveMatch(matchId, auth.userId);
                                  if (context.mounted) {
                                    Helpers.showSnackBar(context, 'Left the match');
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: const Text('Leave Match'),
                              ))
                        : Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: match.teamA.length >= match.maxPlayers ~/ 2
                                      ? null
                                      : () => _joinTeam(context, matchId, auth.userId, 'A', match.teamAName),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981), // Emerald
                                  ),
                                  child: Text(
                                    match.teamA.length >= match.maxPlayers ~/ 2
                                        ? 'Full'
                                        : 'Join ${match.teamAName}',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: match.teamB.length >= match.maxPlayers ~/ 2
                                      ? null
                                      : () => _joinTeam(context, matchId, auth.userId, 'B', match.teamBName),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF38BDF8), // Sky
                                  ),
                                  child: Text(
                                    match.teamB.length >= match.maxPlayers ~/ 2
                                        ? 'Full'
                                        : 'Join ${match.teamBName}',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          )),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddScoreDialog(BuildContext context, MatchModel match) async {
    final scoreAController = TextEditingController();
    final scoreBController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Final Score'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreAController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '${match.teamAName} Score'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: scoreBController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '${match.teamBName} Score'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scoreA = int.tryParse(scoreAController.text);
              final scoreB = int.tryParse(scoreBController.text);
              if (scoreA != null && scoreB != null) {
                await context.read<MatchProvider>().updateScore(match.id, scoreA, scoreB);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinTeam(BuildContext context, String matchId, String userId, String teamId, String teamName) async {
    final success = await context.read<MatchProvider>().joinMatch(matchId, userId, teamId);
    if (context.mounted) {
      if (success) {
        if (teamName.startsWith("team ") || teamName.startsWith("Team ")){
          teamName = "t" + teamName.substring(1); // show message "joined team A"
          Helpers.showSnackBar(context, 'Joined $teamName! 🎉');
        }
        else{
          Helpers.showSnackBar(context, 'Joined team $teamName! 🎉');
        }
      } else {
        Helpers.showSnackBar(
            context,
            context.read<MatchProvider>().errorMessage ?? 'Cannot join',
            isError: true);
      }
    }
  }

  Widget _buildTeamSection(
    BuildContext context,
    ThemeData theme, {
    required String teamName,
    required List<UserModel> players,
    required int maxLimit,
    required Color color,
    required String sport,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                teamName,
                style: theme.textTheme.titleLarge?.copyWith(color: color),
              ),
              Text(
                '${players.length}/$maxLimit',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: players.length >= maxLimit ? Colors.red : color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No players joined yet.',
                style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120)),
              ),
            )
          else
            ...players.map((player) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PlayerAvatar(
                    name: player.name,
                    imageUrl: player.profilePictureUrl,
                    skillLevel: player.skillLevel,
                  ),
                  title: Text(
                    player.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    player.sports.join(', '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                  trailing: SkillIndicator(
                    skillLevel: player.ratingForSport(sport),
                    size: 36,
                    showLabel: false,
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(120),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Match'),
            content: const Text(
                'Are you sure you want to delete this match? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
